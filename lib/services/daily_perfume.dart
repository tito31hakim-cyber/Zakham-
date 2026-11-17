import '../models/product.dart';

/// عطر اليوم — دوران حتمي: يوم السنة % عدد العطور على ترتيب التشكيلة،
/// فيرى كل مستخدم العطر نفسه في اليوم نفسه. بلا أي اتصال بالخادم،
/// ويعمل من النسخة المحفوظة عند غياب النت.
///
/// ترتيب التشكيلة هو ترتيب رد `/api/storefront` كما يصل للتطبيق.

/// رقم اليوم في السنة (1 في أول يناير).
int dayOfYear(DateTime date) =>
    date.difference(DateTime(date.year, 1, 1)).inDays + 1;

/// مؤشر عطر اليوم في قائمة من [count] عطراً: اليوم الأول هو العطر
/// الأول، ثم يتقدم عطراً كل يوم ويلف بعد آخر عطر.
int perfumeOfTheDayIndex({required int count, required DateTime date}) {
  if (count <= 0) return 0;
  return (dayOfYear(date) - 1) % count;
}

/// عطر اليوم من التشكيلة، أو null إن كانت فارغة.
Product? perfumeOfTheDay(List<Product> products, DateTime date) {
  if (products.isEmpty) return null;
  return products[perfumeOfTheDayIndex(count: products.length, date: date)];
}

/// موعد إشعار عطر اليوم التالي: الساعة 18:00 بالتوقيت المحلي — اليوم
/// إن لم تحن بعد، وإلا غداً.
DateTime nextDailyPerfumeFireAt(DateTime now) {
  final today = DateTime(now.year, now.month, now.day, 18);
  return now.isBefore(today) ? today : today.add(const Duration(days: 1));
}
