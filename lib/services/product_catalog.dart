import 'package:shared_preferences/shared_preferences.dart';

import '../models/product.dart';
import 'product_api.dart';

/// نتيجة جلب التشكيلة: المنتجات + هل هي من النسخة المحفوظة (بلا نت).
class CatalogResult {
  const CatalogResult({
    required this.products,
    required this.fromCache,
    this.cachedAt,
  });

  final List<Product> products;
  final bool fromCache;
  final DateTime? cachedAt;
}

/// كتالوج بلا نت: يجلب `/api/storefront` ويحفظ الرد الخام (JSON) في
/// SharedPreferences. عند فشل الشبكة يُعرض الرد المحفوظ فوراً بدلاً
/// من شاشة الخطأ، ويُحدَّث في الخلفية عند عودة الاتصال.
///
/// التخزين best-effort: أي فشل في القراءة/الكتابة يُتجاهل بهدوء.
/// النسخة المحفوظة لا تنتهي صلاحيتها أبداً من تلقاء نفسها — عطر قديم
/// خير من لا عطور؛ ويُعرض شريط «نسخة محفوظة» فوقها.
class ProductCatalog {
  ProductCatalog({ProductApi? api}) : _api = api ?? ProductApi();

  static const _cacheKey = 'zakham_storefront_cache_v1';
  static const _cacheTimeKey = 'zakham_storefront_cache_time_v1';

  final ProductApi _api;

  /// يجلب التشكيلة من الشبكة، ويحفظها؛ وإن فشل يعيد المحفوظ إن وُجد.
  Future<CatalogResult> fetchCatalog() async {
    try {
      final raw = await _api.fetchProductsRaw();
      final products = ProductApi.parseProducts(raw);
      await _saveCache(raw);
      return CatalogResult(products: products, fromCache: false);
    } catch (_) {
      final cached = await loadCached();
      if (cached != null) return cached;
      rethrow;
    }
  }

  /// النسخة المحفوظة وحدها (بلا أي اتصال بالشبكة)، أو null إن لم توجد.
  Future<CatalogResult?> loadCached() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null || raw.isEmpty) return null;
      final products = ProductApi.parseProducts(raw);
      final millis = prefs.getInt(_cacheTimeKey);
      return CatalogResult(
        products: products,
        fromCache: true,
        cachedAt: millis == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(millis),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveCache(String raw) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, raw);
      await prefs.setInt(
        _cacheTimeKey,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {
      // الكاش تحسين فقط؛ فشل حفظه لا يمنع عرض المنتجات.
    }
  }
}
