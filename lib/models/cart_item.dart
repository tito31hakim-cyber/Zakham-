import 'product.dart';

class CartItem {
  CartItem({required this.product, this.quantity = 1});
  final Product product;
  int quantity;
  double get total => product.price * quantity;
}
