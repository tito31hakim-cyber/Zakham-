import 'product.dart';

class CartItem {
  CartItem({
    required this.product,
    required this.sizeMl,
    required this.concentration,
    this.quantity = 1,
  });

  final Product product;
  final int sizeMl;
  final String concentration;
  int quantity;

  double get unitPrice => product.priceFor(concentration, sizeMl);
  double get total => unitPrice * quantity;
}
