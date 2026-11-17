import 'package:flutter/foundation.dart';

import '../models/cart_item.dart';
import '../services/discounts.dart';

/// قواعد الخصم المفعّلة في التطبيق — تُجلب عند الإطلاق وتُحسب منها
/// خصومات السلة في كل شاشة تعرضها. best-effort: غياب القواعد يعني
/// ببساطة «لا خصم» ولا يعطّل أي شاشة.
class DiscountProvider extends ChangeNotifier {
  DiscountProvider({DiscountService? service})
      : _service = service ?? DiscountService();

  final DiscountService _service;

  List<DiscountRule> _rules = const <DiscountRule>[];
  List<DiscountRule> get rules =>
      _rules.where((rule) => rule.active).toList(growable: false);

  List<DiscountRule> get allRules => _rules;

  bool _loaded = false;
  bool get loaded => _loaded;

  Future<void> refresh() async {
    try {
      _rules = await _service.refresh();
    } catch (_) {
      _rules = const <DiscountRule>[];
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  DiscountResult calculationFor(List<CartItem> items) =>
      discountForCart(items, rules);
}
