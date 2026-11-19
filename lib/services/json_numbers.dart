/// تحويل متسامح لقيم JSON الرقمية.
///
/// الخادم يعيد حقول المبالغ كنصوص أحياناً ("370" بدل 370)؛ والصبّ
/// المباشر `as num?` ينفجر حينها:
/// `type 'String' is not a subtype of type 'num?' in type cast`
/// (ظهر في صفحة «حسابي» — قسم «طلباتي» فاختفت القائمة).
///
/// هذه الدوال تقبل num أو نصاً رقمياً، وتعيد القيمة الاحتياطية
/// عند غياب الحقل أو فساده — بلا استثناء. والقيم الرقمية العادية
/// تمر كما هي دون أي تغيير في السلوك.
double asDouble(dynamic value, [double fallback = 0]) {
  if (value is num) return value.toDouble();
  if (value is String) {
    final parsed = double.tryParse(value.trim());
    if (parsed != null) return parsed;
  }
  return fallback;
}

/// مثل [asDouble] للحقول الصحيحة (كميات ومقاسات) — يقبل أيضاً
/// نصاً عشرياً ("30.0") فيقتطع كسوره كما يفعل `num.toInt()`.
int asInt(dynamic value, [int fallback = 0]) {
  if (value is num) return value.toInt();
  if (value is String) {
    final parsed = int.tryParse(value.trim()) ??
        double.tryParse(value.trim())?.toInt();
    if (parsed != null) return parsed;
  }
  return fallback;
}
