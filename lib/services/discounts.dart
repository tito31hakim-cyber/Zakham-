import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../models/cart_item.dart';
import 'secure_http.dart';

/// قاعدة خصم «اشترِ 2 واحصل على خصم» — ينشئها الأدمن من لوحة إدارة
/// التطبيق (الأنواع المشمولة + نسبة الخصم + تفعيل)، ويطبّقها التطبيق
/// تلقائياً في السلة وإتمام الطلب، ويعيد الخادم حسابها والتحقق منها
/// عند إنشاء الطلب — فلا يملك عميلٌ متمرّد اختراع خصم من جهازه.
class DiscountRule {
  const DiscountRule({
    required this.id,
    required this.name,
    required this.productIds,
    required this.percent,
    this.active = true,
  });

  /// معرّف الخادم (رقم) أو '' لقاعدة جديدة لم تُحفظ بعد.
  final String id;

  /// اسم العرض كما يظهر للعميل (مثال: «خصم الثنائية الملكية»).
  final String name;

  /// معرّفات العطور المشمولة (مثل layl, royal).
  final List<String> productIds;

  /// نسبة الخصم % على مجموع الأصناف المشمولة (افتراضياً 10%).
  final double percent;

  final bool active;

  factory DiscountRule.fromJson(Map<String, dynamic> json) {
    final rawIds = json['productIds'] ?? json['product_ids'];
    final ids = <String>[];
    if (rawIds is List) {
      for (final value in rawIds) {
        final id = '$value'.trim();
        if (id.isNotEmpty) ids.add(id);
      }
    } else if (rawIds is String) {
      try {
        final decoded = jsonDecode(rawIds);
        if (decoded is List) {
          for (final value in decoded) {
            final id = '$value'.trim();
            if (id.isNotEmpty) ids.add(id);
          }
        }
      } catch (_) {}
    }
    return DiscountRule(
      id: '${json['id'] ?? ''}',
      name: '${json['name'] ?? ''}'.trim(),
      productIds: ids,
      percent: (json['percent'] as num?)?.toDouble() ?? 10,
      active: json['active'] != false && json['active'] != 0,
    );
  }

  Map<String, dynamic> toRequestJson() => {
        'name': name,
        'productIds': productIds,
        'percent': percent,
        'active': active,
      };

  DiscountRule copyWith({
    String? id,
    String? name,
    List<String>? productIds,
    double? percent,
    bool? active,
  }) =>
      DiscountRule(
        id: id ?? this.id,
        name: name ?? this.name,
        productIds: productIds ?? this.productIds,
        percent: percent ?? this.percent,
        active: active ?? this.active,
      );
}

/// نتيجة حساب الخصم على سلة: المبلغ وأسماء القواعد التي طبّقت فعلاً.
class DiscountResult {
  const DiscountResult({required this.amount, required this.ruleNames});

  final double amount;
  final List<String> ruleNames;

  bool get hasDiscount => amount > 0;
}

/// حساب بحت لخصم «اشترِ 2» على سلة:
/// - القاعدة تنطبق فقط عندما تحوي السلة قطعتين أو أكثر من أنواعها
///   المشمولة (كمية الصنف نفسه أو أنواع مختلفة مشمولة معاً).
/// - الخصم = نسبة القاعدة على مجموع الأصناف المشمولة.
/// - إن غطّت قاعدتان الصنف نفسه يُؤخذ الأعلى فقط (لا تراكم).
/// - المبلغ مقصوص إلى مجموع السلة.
DiscountResult discountForCart(
  List<CartItem> items,
  List<DiscountRule> rules,
) {
  final qualified = <DiscountRule>[];
  for (final rule in rules) {
    if (!rule.active || rule.percent <= 0 || rule.productIds.isEmpty) {
      continue;
    }
    var coveredQty = 0;
    for (final item in items) {
      if (rule.productIds.contains(item.product.id)) {
        coveredQty += item.quantity;
      }
    }
    if (coveredQty >= 2) qualified.add(rule);
  }
  if (qualified.isEmpty || items.isEmpty) {
    return const DiscountResult(amount: 0, ruleNames: <String>[]);
  }
  // أعلى نسبة لكل عطر من القواعد المنطبقة.
  final bestPercent = <String, double>{};
  for (final rule in qualified) {
    for (final productId in rule.productIds) {
      final current = bestPercent[productId] ?? 0;
      if (rule.percent > current) bestPercent[productId] = rule.percent;
    }
  }
  var amount = 0.0;
  final appliedNames = <String>{};
  for (final item in items) {
    final percent = bestPercent[item.product.id] ?? 0;
    if (percent <= 0) continue;
    amount += item.total * percent / 100;
    for (final rule in qualified) {
      if (rule.percent == percent &&
          rule.productIds.contains(item.product.id)) {
        appliedNames.add(rule.name);
      }
    }
  }
  final subtotal = items.fold<double>(0, (sum, item) => sum + item.total);
  amount = double.parse(amount.toStringAsFixed(2));
  if (amount > subtotal) amount = subtotal;
  if (amount <= 0) return const DiscountResult(amount: 0, ruleNames: []);
  return DiscountResult(amount: amount, ruleNames: appliedNames.toList());
}

/// يجلب قواعد الخصم المفعّلة من الخادم ويحفظها محلياً؛ عند غياب
/// النقطة (404 — الخادم لم يُنشر بعد) أو أي فشل يعيد المحفوظة،
/// وعند غيابها يعيد قائمة فارغة (لا خصم — ولا عطل).
class DiscountService {
  DiscountService({Future<String?> Function()? fetcher})
      : _fetcher = fetcher ?? _defaultFetch;

  static const _cacheKey = 'zakham_discount_rules_v1';

  final Future<String?> Function() _fetcher;

  static Future<String?> _defaultFetch() async {
    try {
      final response = await SecureHttp.client
          .get(AppConfig.discountsActiveUri)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200 && response.body.isNotEmpty) {
        return response.body;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<List<DiscountRule>> refresh() async {
    final raw = await _fetcher();
    if (raw != null && raw.isNotEmpty) {
      try {
        final data = jsonDecode(raw);
        final list = (data is Map ? data['rules'] : null) as List?;
        if (list != null) {
          final rules = list
              .whereType<Map<String, dynamic>>()
              .map(DiscountRule.fromJson)
              .toList(growable: false);
          await _saveCache(raw);
          return rules;
        }
      } catch (_) {}
    }
    return _loadCache();
  }

  Future<void> _saveCache(String raw) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, raw);
    } catch (_) {}
  }

  Future<List<DiscountRule>> _loadCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null || raw.isEmpty) return const <DiscountRule>[];
      final data = jsonDecode(raw);
      final list = (data is Map ? data['rules'] : null) as List?;
      if (list == null) return const <DiscountRule>[];
      return list
          .whereType<Map<String, dynamic>>()
          .map(DiscountRule.fromJson)
          .toList(growable: false);
    } catch (_) {
      return const <DiscountRule>[];
    }
  }
}
