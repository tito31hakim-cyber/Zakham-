import 'package:flutter/foundation.dart';

import '../models/cart_item.dart';
import '../models/product.dart';

class CartProvider extends ChangeNotifier {
  final Map<String, CartItem> _items = {};
  List<CartItem> get items => _items.values.toList(growable: false);
  int get itemCount =>
      _items.values.fold(0, (sum, item) => sum + item.quantity);
  double get subtotal => _items.values.fold(0, (sum, item) => sum + item.total);

  /// رسوم الشحن الموحّدة في المتجر الحي لجميع المحافظات (جنيه).
  static const double shippingFee = 120;

  double get totalWithShipping => subtotal + shippingFee;

  void add(Product product, {String? concentration, int? sizeMl}) {
    if (!product.inStock) return;
    addItem(CartItem(
      product: product,
      concentration: concentration,
      sizeMl: sizeMl,
    ));
  }

  void addItem(CartItem item) {
    if (!item.product.inStock) return;
    final existing = _items[item.key];
    if (existing == null) {
      _items[item.key] = item;
    } else {
      existing.quantity += item.quantity;
    }
    notifyListeners();
  }

  void decrease(CartItem item) {
    final existing = _items[item.key];
    if (existing == null) return;
    existing.quantity > 1
        ? existing.quantity--
        : _items.remove(item.key);
    notifyListeners();
  }

  void remove(CartItem item) {
    _items.remove(item.key);
    notifyListeners();
  }

  /// توافقية: عمليات بالمنتج وحده تستخدم تركيزه وحجمه الافتراضيين.
  void decreaseProduct(Product product) =>
      decrease(CartItem(product: product));

  void removeProduct(Product product) =>
      remove(CartItem(product: product));

  void clear() {
    _items.clear();
    notifyListeners();
  }
}
