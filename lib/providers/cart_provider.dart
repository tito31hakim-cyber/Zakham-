import 'package:flutter/foundation.dart';

import '../models/cart_item.dart';
import '../models/product.dart';

class CartProvider extends ChangeNotifier {
  final Map<String, CartItem> _items = {};
  List<CartItem> get items => _items.values.toList(growable: false);
  int get itemCount =>
      _items.values.fold(0, (sum, item) => sum + item.quantity);
  double get subtotal => _items.values.fold(0, (sum, item) => sum + item.total);

  void add(Product product) {
    if (!product.inStock) return;
    final item = _items[product.id];
    if (item == null) {
      _items[product.id] = CartItem(product: product);
    } else {
      item.quantity++;
    }
    notifyListeners();
  }

  void decrease(Product product) {
    final item = _items[product.id];
    if (item == null) return;
    item.quantity > 1 ? item.quantity-- : _items.remove(product.id);
    notifyListeners();
  }

  void remove(Product product) {
    _items.remove(product.id);
    notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }
}
