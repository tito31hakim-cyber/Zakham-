import 'package:flutter/foundation.dart';

import '../models/cart_item.dart';
import '../models/product.dart';

class CartProvider extends ChangeNotifier {
  final Map<String, CartItem> _items = {};

  List<CartItem> get items => _items.values.toList(growable: false);
  int get itemCount => _items.values.fold(0, (sum, item) => sum + item.quantity);
  double get subtotal => _items.values.fold(0, (sum, item) => sum + item.total);

  String _key(String productId, String concentration, int sizeMl) =>
      '$productId|$concentration|$sizeMl';

  void add(
    Product product, {
    required int sizeMl,
    required String concentration,
  }) {
    if (!product.inStock) return;
    final key = _key(product.id, concentration, sizeMl);
    final item = _items[key];
    if (item == null) {
      _items[key] = CartItem(
        product: product,
        sizeMl: sizeMl,
        concentration: concentration,
      );
    } else {
      item.quantity++;
    }
    notifyListeners();
  }

  void decrease(CartItem item) {
    final key = _key(item.product.id, item.concentration, item.sizeMl);
    final current = _items[key];
    if (current == null) return;
    if (current.quantity > 1) {
      current.quantity--;
    } else {
      _items.remove(key);
    }
    notifyListeners();
  }

  void remove(CartItem item) {
    _items.remove(_key(item.product.id, item.concentration, item.sizeMl));
    notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }
}
