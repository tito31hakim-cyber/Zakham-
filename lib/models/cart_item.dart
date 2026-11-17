import 'product.dart';

/// صنف في السلة مرتبط بتركيز وحجم محددين.
///
/// الخادم يعيد تسعير كل صنف بنفسه من (الحجم، التركيز) عبر
/// `priceFromProduct` ويرفض التركيبة غير المتاحة (422)، لذلك يجب أن يحمل
/// كل صنف التركيز والحجم المختارين فعلاً وسعر الوحدة المطابق لهما — لا
/// التركيز المصلّب 'presence' ولا سعر 100 مل الافتراضي.
class CartItem {
  CartItem({
    required this.product,
    this.quantity = 1,
    String? concentration,
    int? sizeMl,
    double? unitPrice,
  })  : concentration = concentration ?? product.defaultConcentration,
        sizeMl = sizeMl ?? product.defaultSizeMl,
        unitPrice = unitPrice ??
            product.priceFor(
              concentration: concentration ?? product.defaultConcentration,
              sizeMl: sizeMl ?? product.defaultSizeMl,
            ) ??
            product.price;

  final Product product;

  /// مفتاح التركيز المختار: presence / extra / nuclear.
  final String concentration;

  /// الحجم المختار بالمل: 30 أو 50 أو 100.
  final int sizeMl;

  /// سعر الوحدة للتركيز والحجم المختارين.
  final double unitPrice;

  int quantity;

  double get total => unitPrice * quantity;

  /// مفتاح السلة: نفس العطر بتركيز/حجم مختلفين صنفان منفصلان.
  String get key => '${product.id}|$concentration|$sizeMl';
}
