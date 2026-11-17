import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../models/product.dart';
import 'favorites_service.dart';
import 'push_service.dart';
import 'secure_http.dart';

/// نوع التغيير على عطر مفضّل بين نسختين من التشكيلة.
enum FavoriteChangeKind { priceDrop, backInStock }

/// تغيير على عطر مفضّل اكتُشف عند تحديث التشكيلة — أساس تنبيه
/// العروض داخل التطبيق (بلا خادم).
class FavoriteChange {
  const FavoriteChange({
    required this.product,
    required this.kind,
    this.oldPrice,
    this.newPrice,
  });

  final Product product;
  final FavoriteChangeKind kind;
  final double? oldPrice;
  final double? newPrice;

  String get message {
    switch (kind) {
      case FavoriteChangeKind.priceDrop:
        return 'انخفض سعر «${product.name}» من ${oldPrice?.toStringAsFixed(0) ?? '—'} إلى ${newPrice?.toStringAsFixed(0) ?? '—'} ${product.currency}';
      case FavoriteChangeKind.backInStock:
        return 'عاد «${product.name}» إلى المخزون';
    }
  }
}

/// يقارن التشكيلة الطازجة بالمحفوظة ويعيد تغييرات العطور المفضلة
/// فقط: انخفاض السعر، أو العودة إلى المخزون. دالة بحتة قابلة للاختبار.
List<FavoriteChange> detectFavoriteChanges({
  required List<Product> fresh,
  required List<Product> previous,
  required Set<String> favoriteIds,
}) {
  final previousById = <String, Product>{
    for (final product in previous) product.id: product,
  };
  final changes = <FavoriteChange>[];
  for (final product in fresh) {
    if (!favoriteIds.contains(product.id)) continue;
    final prev = previousById[product.id];
    if (prev == null) continue;
    if (product.price < prev.price) {
      changes.add(FavoriteChange(
        product: product,
        kind: FavoriteChangeKind.priceDrop,
        oldPrice: prev.price,
        newPrice: product.price,
      ));
    } else if (!prev.inStock && product.inStock) {
      changes.add(FavoriteChange(
        product: product,
        kind: FavoriteChangeKind.backInStock,
      ));
    }
  }
  return changes;
}

/// تنبيهات عروض المفضلة — جزآن:
/// (أ) تسجيل الجهاز: يرسل رمز FCM مع معرّفات المفضلة إلى الخادم
/// (POST /api/devices/register — مسودة بانتظار النشر؛ غيابها 404
/// يُعامل كأي فشل آخر: best-effort ويُعاد عند التغيير التالي).
/// (ب) بديل داخل التطبيق: مقارنة التشكيلة الطازجة بالمحفوظة
/// ([detectFavoriteChanges]) وإظهار تنبيه عند انخفاض سعر مفضّل أو
/// عودته للمخزون — بلا أي حاجة للخادم.
///
/// المزامنة مع الخادم لا تحدث إلا عند تغيير المفضلة أو رمز الجهاز،
/// وبحد أقصى مرة واحدة لكل حالة — لا طلبات دورية ولا إزعاج.
class FavoritesOfferService {
  FavoritesOfferService({FavoritesService? favoritesService})
      : _favoritesService = favoritesService ?? FavoritesService();

  static const String _enabledKey = 'zakham_fav_offers_enabled';

  /// بصمة آخر مزامنة ناجحة (الرمز + المفضلة مرتبة) — لمنع التكرار.
  static const String _lastSyncKey = 'zakham_devices_last_sync_v1';

  static const String devicesRegisterPath = '/api/devices/register';

  final FavoritesService _favoritesService;

  /// هل تنبيهات عروض المفضلة مفعّلة؟ الافتراضي نعم — تنبيهات عن
  /// عطور اختارها العميل بنفسه، لا تسويق جماعي.
  Future<bool> isEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_enabledKey) ?? true;
    } catch (_) {
      return true;
    }
  }

  /// يفعّل/يوقف التنبيهات. الإيقاف يحاول إلغاء تسجيل المفضلة من
  /// الخادم (قائمة فارغة) — best-effort ككل شيء هنا.
  Future<void> setEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_enabledKey, enabled);
    } catch (_) {}
    if (enabled) {
      await syncFavorites();
    } else {
      await syncFavorites(forceEmpty: true);
    }
  }

  /// يسجّل رمز FCM مع المفضلة الحالية في الخادم. يعيد true فقط عند
  /// نجاح حقيقي أو عند عدم الحاجة (لا شيء تغيّر). يتخطى بهدوء عند
  /// إيقاف التنبيهات أو غياب الرمز — وتُعاد المحاولة عند تغيير
  /// المفضلة أو التشغيل التالي.
  Future<bool> syncFavorites({bool forceEmpty = false}) async {
    try {
      if (!forceEmpty && !await isEnabled()) return false;
      final token = PushService.instance.token;
      if (token == null || token.isEmpty) return false;
      final favorites =
          forceEmpty ? <String>{} : await _favoritesService.load();
      final sorted = favorites.toList(growable: false)..sort();
      final fingerprint = '$token|${sorted.join(',')}';
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(_lastSyncKey) == fingerprint) return true;
      final response = await SecureHttp.client
          .post(
            Uri.parse('${AppConfig.apiBaseUrl}$devicesRegisterPath'),
            headers: <String, String>{
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'fcmToken': token,
              'favoriteProductIds': sorted,
            }),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return false;
      }
      await prefs.setString(_lastSyncKey, fingerprint);
      return true;
    } catch (_) {
      return false;
    }
  }
}
