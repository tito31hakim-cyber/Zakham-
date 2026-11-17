import '../models/product.dart';

/// تقويم المناسبات — جدول ثابت داخل التطبيق، بلا خادم.
///
/// التواريخ الهجرية (رمضان والعيدان) محسوبة فلكياً (تقويم أم القرى)
/// وتُثبَّت هنا لكل سنة — وقد تختلف يوماً حسب رؤية الهلال في مصر،
/// فيُذكر ذلك في واجهة المناسبة. لإضافة سنة جديدة (مثل 2028):
/// أضف سطر `OccasionDate` واحداً لكل مناسبة هجرية في جدولها أدناه
/// (المناسبات الميلادية ثابتة اليوم والشهر فتُمدَّد بسطر مماثل).

/// تاريخ مناسبة في سنة معينة.
class OccasionDate {
  const OccasionDate(this.year, this.month, this.day);
  final int year;
  final int month;
  final int day;

  DateTime get date => DateTime(year, month, day);
}

/// مناسبة في التقويم: عنوانها، واقتراح الإهداء، والعطور المقترحة
/// كهدايا (معرّفات من التشكيلة — تُطابَق مع الكتالوج الحي عند
/// العرض، ويُتخطى أي معرّف غير موجود)، وتواريخها لكل سنة.
class ZakhamOccasion {
  const ZakhamOccasion({
    required this.id,
    required this.title,
    required this.giftNote,
    required this.giftProductIds,
    required this.dates,
    this.hijri = false,
  });

  final String id;
  final String title;
  final String giftNote;
  final List<String> giftProductIds;
  final List<OccasionDate> dates;

  /// هل تواريخها هجرية (قد تختلف يوماً حسب رؤية الهلال)؟
  final bool hijri;
}

/// جدول المناسبات 2026–2027.
///
/// التواريخ المتحقَّق منها:
/// - رمضان 2026: 19 فبراير (أول صيام في مصر)؛ رمضان 2027: 8 فبراير
///   (أم القرى — 9 فبراير برؤية محلية).
/// - عيد الفطر 2026: 20 مارس؛ 2027: 9 مارس (10 مارس إن أكمل رمضان 30 يوماً).
/// - عيد الأضحى 2026: 27 مايو؛ 2027: 16 مايو (17 مايو في بعض البلدان).
/// - عيد الأم: 21 مارس؛ عيد الحب: 14 فبراير؛ رأس السنة: 1 يناير.
const List<ZakhamOccasion> zakhamOccasions = <ZakhamOccasion>[
  ZakhamOccasion(
    id: 'ramadan',
    title: 'رمضان',
    giftNote: 'عطور دافئة للأمسيات الرمضانية والسهرات بعد الإفطار',
    giftProductIds: <String>['tobacco', 'royal', 'aura', 'elixir', 'layl'],
    dates: <OccasionDate>[
      OccasionDate(2026, 2, 19),
      OccasionDate(2027, 2, 8),
    ],
    hijri: true,
  ),
  ZakhamOccasion(
    id: 'eid_fitr',
    title: 'عيد الفطر',
    giftNote: 'عطور رسمية فاخرة لفرحة العيد وزياراته',
    giftProductIds: <String>['sultan', 'royal', 'fares', 'fahd'],
    dates: <OccasionDate>[
      OccasionDate(2026, 3, 20),
      OccasionDate(2027, 3, 9),
    ],
    hijri: true,
  ),
  ZakhamOccasion(
    id: 'eid_adha',
    title: 'عيد الأضحى',
    giftNote: 'هيبة العيد الكبير — عطور تليق بالمناسبات العائلية',
    giftProductIds: <String>['sultan', 'royal', 'fares', 'tobacco'],
    dates: <OccasionDate>[
      OccasionDate(2026, 5, 27),
      OccasionDate(2027, 5, 16),
    ],
    hijri: true,
  ),
  ZakhamOccasion(
    id: 'mothers_day',
    title: 'عيد الأم',
    giftNote: 'هدية راقية لأغلى الناس — عطور ناعمة وأنيقة',
    giftProductIds: <String>['aura', 'aurora', 'musk', 'layl'],
    dates: <OccasionDate>[
      OccasionDate(2026, 3, 21),
      OccasionDate(2027, 3, 21),
    ],
  ),
  ZakhamOccasion(
    id: 'valentines',
    title: 'عيد الحب',
    giftNote: 'عطور رومانسية لليلة لا تُنسى',
    giftProductIds: <String>['aura', 'aurora', 'elixir', 'layl'],
    dates: <OccasionDate>[
      OccasionDate(2026, 2, 14),
      OccasionDate(2027, 2, 14),
    ],
  ),
  ZakhamOccasion(
    id: 'new_year',
    title: 'رأس السنة',
    giftNote: 'ابدأ عامك بعطر يليق بطموحك',
    giftProductIds: <String>['elixir', 'sultan', 'royal', 'storm'],
    dates: <OccasionDate>[
      OccasionDate(2026, 1, 1),
      OccasionDate(2027, 1, 1),
    ],
  ),
];

/// مناسبة قادمة مع تاريخها وعطورها المقترحة من الكتالوج الحي.
class UpcomingOccasion {
  const UpcomingOccasion({
    required this.occasion,
    required this.date,
    required this.gifts,
  });

  final ZakhamOccasion occasion;
  final DateTime date;

  /// العطور المقترحة كهدايا — بترتيب الجدول، بلا معرّفات مفقودة.
  final List<Product> gifts;

  /// عدد الأيام حتى المناسبة (0 في يومها).
  int daysUntil(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    return DateTime(date.year, date.month, date.day)
        .difference(today)
        .inDays;
  }
}

/// المناسبات القادمة مرتبة من الأقرب (اليوم فصاعداً)، بحد أقصى [limit].
List<UpcomingOccasion> upcomingOccasions(
  List<Product> products,
  DateTime now, {
  int limit = 3,
}) {
  final byId = <String, Product>{for (final p in products) p.id: p};
  final today = DateTime(now.year, now.month, now.day);
  final found = <UpcomingOccasion>[];
  for (final occasion in zakhamOccasions) {
    for (final entry in occasion.dates) {
      final date = entry.date;
      if (date.isBefore(today)) continue;
      found.add(
        UpcomingOccasion(
          occasion: occasion,
          date: date,
          gifts: <Product>[
            for (final id in occasion.giftProductIds)
              if (byId.containsKey(id)) byId[id]!,
          ],
        ),
      );
    }
  }
  found.sort((a, b) => a.date.compareTo(b.date));
  return found.take(limit).toList(growable: false);
}

/// أقرب وقوع قادم لمناسبة (أو null إن لم يبقَ لها تاريخ في الجدول).
DateTime? nextOccurrence(ZakhamOccasion occasion, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  for (final entry in occasion.dates) {
    if (!entry.date.isBefore(today)) return entry.date;
  }
  return null;
}

/// موعد إشعار المناسبة: قبلها بأسبوع الساعة 12:00 ظهراً.
DateTime occasionReminderFireAt(DateTime occasionDate) => DateTime(
      occasionDate.year,
      occasionDate.month,
      occasionDate.day,
      12,
    ).subtract(const Duration(days: 7));

const List<String> _arabicMonths = <String>[
  'يناير',
  'فبراير',
  'مارس',
  'أبريل',
  'مايو',
  'يونيو',
  'يوليو',
  'أغسطس',
  'سبتمبر',
  'أكتوبر',
  'نوفمبر',
  'ديسمبر',
];

const List<String> _arabicWeekdays = <String>[
  'الاثنين',
  'الثلاثاء',
  'الأربعاء',
  'الخميس',
  'الجمعة',
  'السبت',
  'الأحد',
];

/// ينسّق التاريخ عربياً: «الجمعة، 20 مارس 2026».
String formatArabicDate(DateTime date) =>
    '${_arabicWeekdays[date.weekday - 1]}، '
    '${date.day} ${_arabicMonths[date.month - 1]} ${date.year}';

/// ينسّق تاريخ ميلاد مخزَّن «YYYY-MM-DD» عربياً للعرض.
String formatBirthdayAr(String yyyyMmDd) {
  final parsed = DateTime.tryParse(yyyyMmDd);
  if (parsed == null) return yyyyMmDd;
  return '${parsed.day} ${_arabicMonths[parsed.month - 1]} ${parsed.year}';
}
