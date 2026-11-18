/// مخزون المنتج الإداري — مساعد مشترك بين صفحة الإدارة وخدمة المستشار.
///
/// تنبيه (2026-11-17): نقطة `/api/admin/products` تشارك نفس مسلسل
/// `productRow` مع واجهة المتجر العامة، فبعد إزالة حقول الأصالة
/// والمخزون الدقيق من الرد العام لم يعد الرد الإداري يحمل `stockQty`
/// ولا `codePrefix`/`codeNumber`/`bottleLabel`. لذلك يُشتق المخزون
/// للعرض من `variantRows` (ترد من استعلام منفصل لم يُمس).
///
/// القاعدة: `stockQty` المباشر إن وُجد رقماً أو نصاً رقمياً، وإلا مجموع
/// مخزون المتغيرات النشطة من `variantRows`، وإلا `null` أي «مجهول».
/// المخزون المجهول لا يُعدّ منخفضاً أبداً — يُعرض «تعذر تحديده».
int? adminStockFor(Map<String, dynamic> product) {
  final direct = product['stockQty'];
  if (direct is num) return direct.toInt();
  if (direct is String) return int.tryParse(direct.trim());
  final rows = product['variantRows'];
  if (rows is List) {
    var total = 0;
    var found = false;
    for (final row in rows) {
      if (row is! Map) continue;
      final active = row['is_active'];
      if (active == 0 || active == false || active == '0') continue;
      final qty = row['stock_qty'];
      if (qty is num) {
        total += qty.toInt();
        found = true;
      } else if (qty is String) {
        final parsed = int.tryParse(qty.trim());
        if (parsed != null) {
          total += parsed;
          found = true;
        }
      }
    }
    if (found) return total;
  }
  return null;
}
