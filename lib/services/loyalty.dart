/// نقاط الولاء — قواعد ثابتة حددها صاحب الدار (2026-11-18):
/// - الكسب: 5 نقاط مقابل كل 100 جنيه من سعر العطور فقط (بدون الشحن)،
///   تُقرَّب لأقرب نقطة (250 جنيه = 13 نقطة، 950 جنيه = 48 نقطة).
/// - القيمة: كل نقطة = جنيه واحد خصم عند إتمام الطلب.
/// - الاستبدال: من 50 نقطة، والخصم بحد أقصى min(الرصيد، مجموع المنتجات).
/// - النقاط حقيقة الخادم حصراً: تُمنح بعد تأكيد تسليم الطلب
///   (حالة delivered فقط — لا تُمنح عند تأكيد الدفع) وتُخصم عند
///   الاستبدال — التطبيق لا يمنح ولا يخصم محلياً أبداً.
///
/// الدوال هنا حسابات بحتة للعرض والتحقق قبل الإرسال؛ الخادم يعيد
/// الحساب والتحقق بنفسه عند إنشاء الطلب، ورده هو الفيصل.

/// الحد الأدنى للاستبدال (نقطة).
const int minRedeemPoints = 50;

/// النقاط المكتسبة من مجموع منتجات (بدون شحن): 5 نقاط لكل 100 جنيه،
/// تُقرَّب لأقرب نقطة (12.5 تصبح 13).
int loyaltyPointsEarned(double productsSubtotal) {
  if (productsSubtotal <= 0) return 0;
  return (productsSubtotal * 5 / 100).round();
}

/// أقصى نقاط يمكن استبدالها في طلب: min(الرصيد، مجموع المنتجات).
int maxRedeemablePoints({
  required int balance,
  required double productsSubtotal,
}) {
  if (balance <= 0 || productsSubtotal <= 0) return 0;
  final cap = productsSubtotal.floor();
  return balance < cap ? balance : cap;
}

/// هل يمكن الاستبدال أصلاً؟ رصيد 50 نقطة على الأقل.
bool canRedeemPoints(int balance) => balance >= minRedeemPoints;

/// يقصّ العدد المطلوب استبداله إلى المسموح: 0 إن كان الرصيد أقل من
/// الحد الأدنى أو كان المطلوب أقل منه، وإلا min(المطلوب، الأقصى).
int clampPointsUsed({
  required int balance,
  required double productsSubtotal,
  required int requested,
}) {
  if (requested < minRedeemPoints) return 0;
  final max =
      maxRedeemablePoints(balance: balance, productsSubtotal: productsSubtotal);
  if (max < minRedeemPoints) return 0;
  return requested < max ? requested : max;
}
