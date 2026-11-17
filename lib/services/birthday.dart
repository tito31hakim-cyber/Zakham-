/// هدية عيد الميلاد — منطق بحت (بلا تخزين ولا شبكة).
///
/// القاعدة (من صاحب الدار): تاريخ الميلاد ثابت — يُسجَّل مرة واحدة
/// ولا يمكن للعميل تغييره بعدها إطلاقاً. الهدية: خصم 20% على طلب
/// واحد خلال أسبوع عيد الميلاد (يوم الميلاد ± 3 أيام)، يُطبَّق من
/// الخادم عند إنشاء الطلب (الخادم يتحقق من التاريخ المخزَّن — لا
/// كود يزوره العميل).

/// نسبة خصم هدية عيد الميلاد.
const int birthdayDiscountPercent = 20;

/// نصف عرض أسبوع عيد الميلاد بالأيام (يوم الميلاد ± 3 أيام).
const int birthdayWeekRadiusDays = 3;

/// الإشعار قبل عيد الميلاد بهذا العدد من الأيام.
const int birthdayReminderDaysBefore = 3;

/// يحلّل 'YYYY-MM-DD' إلى تاريخ، أو null إن كانت الصيغة أو القيمة
/// غير صالحة (مثل 2026-02-30 أو نص فارغ).
DateTime? parseBirthday(String value) {
  final match =
      RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value.trim());
  if (match == null) return null;
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  if (year < 1900 || year > 2100 || month < 1 || month > 12) return null;
  try {
    final parsed = DateTime(year, month, day);
    if (parsed.year != year || parsed.month != month || parsed.day != day) {
      return null;
    }
    return parsed;
  } catch (_) {
    return null;
  }
}

/// ينسّق التاريخ كـ 'YYYY-MM-DD' للتخزين والإرسال للخادم.
String formatBirthday(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

bool _isLeapYear(int year) =>
    year % 4 == 0 && (year % 100 != 0 || year % 400 == 0);

/// وقوع عيد الميلاد في سنة معينة — مولود 29 فبراير يحتفل 28 فبراير
/// في السنوات غير الكبيسة.
DateTime _occurrenceForYear(DateTime birthday, int year) {
  if (birthday.month == 2 && birthday.day == 29 && !_isLeapYear(year)) {
    return DateTime(year, 2, 28);
  }
  return DateTime(year, birthday.month, birthday.day);
}

/// وقوع عيد الميلاد الأقرب إلى [now] (هذه السنة أو السابقة أو
/// القادمة) — لمعالجة حدود السنة، مثل ميلاد 2 يناير عند 30 ديسمبر.
DateTime nearestBirthdayOccurrence(DateTime birthday, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  DateTime best = _occurrenceForYear(birthday, now.year);
  var bestDiff = (today.difference(best).inDays).abs();
  for (final year in <int>[now.year - 1, now.year + 1]) {
    final candidate = _occurrenceForYear(birthday, year);
    final diff = (today.difference(candidate).inDays).abs();
    if (diff < bestDiff) {
      best = candidate;
      bestDiff = diff;
    }
  }
  return best;
}

/// هل [now] داخل أسبوع عيد الميلاد (يوم الميلاد ± 3 أيام)؟
bool isInBirthdayWeek(DateTime birthday, DateTime now) {
  final occurrence = nearestBirthdayOccurrence(birthday, now);
  final today = DateTime(now.year, now.month, now.day);
  return (today.difference(occurrence).inDays).abs() <=
      birthdayWeekRadiusDays;
}

/// عدد الأيام حتى عيد الميلاد القادم (0 في يوم الميلاد نفسه).
int daysUntilBirthday(DateTime birthday, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  var occurrence = _occurrenceForYear(birthday, now.year);
  if (occurrence.isBefore(today)) {
    occurrence = _occurrenceForYear(birthday, now.year + 1);
  }
  return occurrence.difference(today).inDays;
}

/// موعد إشعار عيد الميلاد التالي: قبل عيد الميلاد القادم بـ 3 أيام
/// الساعة 12:00 ظهراً؛ إن مضى موعد هذه السنة يُحسب للسنة القادمة.
DateTime nextBirthdayReminderAt(DateTime birthday, DateTime now) {
  for (final year in <int>[now.year, now.year + 1, now.year + 2]) {
    final occurrence = _occurrenceForYear(birthday, year);
    final fireAt = DateTime(
      occurrence.year,
      occurrence.month,
      occurrence.day,
      12,
    ).subtract(const Duration(days: birthdayReminderDaysBefore));
    if (fireAt.isAfter(now)) return fireAt;
  }
  // لا يحدث عملياً — الحلقة أعلاه تجد موعداً قادماً دائماً.
  final occurrence = _occurrenceForYear(birthday, now.year + 1);
  return DateTime(
    occurrence.year,
    occurrence.month,
    occurrence.day,
    12,
  ).subtract(const Duration(days: birthdayReminderDaysBefore));
}
