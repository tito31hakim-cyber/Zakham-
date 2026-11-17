import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:house_of_zakham/models/product.dart';
import 'package:house_of_zakham/pages/quiz_page.dart';
import 'package:house_of_zakham/services/birthday.dart';
import 'package:house_of_zakham/services/birthday_service.dart';
import 'package:house_of_zakham/services/consultation.dart';
import 'package:house_of_zakham/services/customer_auth.dart';
import 'package:house_of_zakham/services/occasions.dart';
import 'package:house_of_zakham/services/reminder_service.dart';

Product _product(String id) => Product(
      id: id,
      name: id,
      price: 250,
      currency: 'EGP',
      size: '30 مل',
      category: 'perfume',
      topNotes: const <String>[],
      heartNotes: const <String>[],
      baseNotes: const <String>[],
      image: '',
      inStock: true,
    );

List<Product> _allProducts() => <String>[
      'layl',
      'elixir',
      'sultan',
      'royal',
      'storm',
      'aura',
      'aurora',
      'fares',
      'tobacco',
      'fahd',
      'musk',
    ].map(_product).toList(growable: false);

/// خادم وهمي لنقطة عيد الميلاد — يخزّن التاريخ في الذاكرة.
class _FakeBirthdayAuth extends CustomerAuth {
  DateTime? serverBirthday;
  bool throwOnSave = false;

  @override
  Future<DateTime?> fetchBirthday() async => serverBirthday;

  @override
  Future<DateTime> saveBirthday(String yyyyMmDd) async {
    if (throwOnSave) throw Exception('network down');
    if (serverBirthday != null) throw const BirthdayAlreadySetException();
    final parsed = parseBirthday(yyyyMmDd);
    if (parsed == null) throw Exception('bad date');
    serverBirthday = parsed;
    return parsed;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('هدية عيد الميلاد — التاريخ ثابت بعد الحفظ', () {
    test('parse/format round-trip ورفض التواريخ غير الصالحة', () {
      expect(parseBirthday('1990-05-15'), DateTime(1990, 5, 15));
      expect(formatBirthday(DateTime(1990, 5, 15)), '1990-05-15');
      expect(parseBirthday('2026-02-30'), isNull);
      expect(parseBirthday('15/05/1990'), isNull);
      expect(parseBirthday(''), isNull);
      expect(parseBirthday('1990-13-01'), isNull);
    });

    test('أسبوع عيد الميلاد: يوم الميلاد ± 3 أيام داخل، و± 4 خارج', () {
      final birthday = DateTime(1990, 5, 15);
      expect(isInBirthdayWeek(birthday, DateTime(2026, 5, 15)), isTrue);
      expect(isInBirthdayWeek(birthday, DateTime(2026, 5, 18)), isTrue);
      expect(isInBirthdayWeek(birthday, DateTime(2026, 5, 12)), isTrue);
      expect(isInBirthdayWeek(birthday, DateTime(2026, 5, 19)), isFalse);
      expect(isInBirthdayWeek(birthday, DateTime(2026, 5, 11)), isFalse);
      expect(isInBirthdayWeek(birthday, DateTime(2026, 6, 15)), isFalse);
    });

    test('أسبوع عيد الميلاد يعبر حدود السنة (ميلاد 2 يناير)', () {
      final birthday = DateTime(1990, 1, 2);
      expect(isInBirthdayWeek(birthday, DateTime(2026, 12, 30)), isTrue);
      expect(isInBirthdayWeek(birthday, DateTime(2026, 12, 29)), isFalse);
      expect(isInBirthdayWeek(birthday, DateTime(2027, 1, 5)), isTrue);
      expect(isInBirthdayWeek(birthday, DateTime(2027, 1, 6)), isFalse);
    });

    test('مولود 29 فبراير يحتفل 28 فبراير في السنوات غير الكبيسة', () {
      final birthday = DateTime(2000, 2, 29);
      expect(isInBirthdayWeek(birthday, DateTime(2027, 2, 28)), isTrue);
      expect(isInBirthdayWeek(birthday, DateTime(2027, 3, 3)), isTrue);
      expect(isInBirthdayWeek(birthday, DateTime(2027, 3, 4)), isFalse);
    });

    test('موعد إشعار عيد الميلاد: قبل عيد الميلاد بـ 3 أيام 12:00', () {
      final birthday = DateTime(1990, 5, 15);
      expect(
        nextBirthdayReminderAt(birthday, DateTime(2026, 5, 1, 10)),
        DateTime(2026, 5, 12, 12),
      );
      expect(
        nextBirthdayReminderAt(birthday, DateTime(2026, 5, 13, 10)),
        DateTime(2027, 5, 12, 12),
      );
      final jan = DateTime(1990, 1, 2);
      expect(
        nextBirthdayReminderAt(jan, DateTime(2026, 12, 29, 10)),
        DateTime(2026, 12, 30, 12),
      );
      expect(
        nextBirthdayReminderAt(jan, DateTime(2026, 12, 30, 14)),
        DateTime(2027, 12, 30, 12),
      );
    });

    test('الأيام حتى عيد الميلاد القادم', () {
      final birthday = DateTime(1990, 5, 15);
      expect(daysUntilBirthday(birthday, DateTime(2026, 5, 10)), 5);
      expect(daysUntilBirthday(birthday, DateTime(2026, 5, 15)), 0);
      expect(daysUntilBirthday(birthday, DateTime(2026, 5, 16)), 364);
    });

    test('الحفظ مرة واحدة: الحفظ الثاني يرفض ولا يغيّر التاريخ', () async {
      final auth = _FakeBirthdayAuth();
      final service = BirthdayService(auth);
      final saved = await service.save(
        ownerKey: 'user1',
        birthday: DateTime(1990, 5, 15),
      );
      expect(saved, DateTime(1990, 5, 15));
      expect(await service.load(ownerKey: 'user1'), DateTime(1990, 5, 15));
      await expectLater(
        service.save(ownerKey: 'user1', birthday: DateTime(1995, 1, 1)),
        throwsException,
      );
      expect(await service.load(ownerKey: 'user1'), DateTime(1990, 5, 15));
    });

    test('الخادم يقول إنه مسجَّل: الحفظ يرفض ويُثبَّت تاريخ الخادم', () async {
      final auth = _FakeBirthdayAuth()
        ..serverBirthday = DateTime(1988, 3, 3);
      final service = BirthdayService(auth);
      await expectLater(
        service.save(ownerKey: 'user1', birthday: DateTime(1995, 1, 1)),
        throwsException,
      );
      expect(await service.load(ownerKey: 'user1'), DateTime(1988, 3, 3));
    });

    test('تعطل الخادم: يُحفظ محلياً ويُقرأ لاحقاً', () async {
      final auth = _FakeBirthdayAuth()..throwOnSave = true;
      final service = BirthdayService(auth);
      final saved = await service.save(
        ownerKey: 'user1',
        birthday: DateTime(1990, 5, 15),
      );
      expect(saved, DateTime(1990, 5, 15));
      expect(await service.load(ownerKey: 'user1'), DateTime(1990, 5, 15));
    });
  });

  group('تقويم المناسبات', () {
    test('المناسبات القادمة مرتبة من الأقرب أولاً', () {
      final upcoming = upcomingOccasions(
        _allProducts(),
        DateTime(2026, 11, 18),
      );
      expect(upcoming.length, 3);
      expect(upcoming[0].occasion.id, 'new_year');
      expect(upcoming[0].date, DateTime(2027, 1, 1));
      expect(upcoming[1].occasion.id, 'ramadan');
      expect(upcoming[1].date, DateTime(2027, 2, 8));
      expect(upcoming[2].occasion.id, 'valentines');
      expect(upcoming[2].date, DateTime(2027, 2, 14));
      expect(upcoming[0].daysUntil(DateTime(2026, 11, 18)), 44);
    });

    test('تواريخ 2026 المتحقَّق منها في الجدول', () {
      final ramadan =
          zakhamOccasions.firstWhere((o) => o.id == 'ramadan');
      expect(ramadan.dates[0].date, DateTime(2026, 2, 19));
      expect(ramadan.dates[1].date, DateTime(2027, 2, 8));
      final fitr = zakhamOccasions.firstWhere((o) => o.id == 'eid_fitr');
      expect(fitr.dates[0].date, DateTime(2026, 3, 20));
      expect(fitr.dates[1].date, DateTime(2027, 3, 9));
      final adha = zakhamOccasions.firstWhere((o) => o.id == 'eid_adha');
      expect(adha.dates[0].date, DateTime(2026, 5, 27));
      expect(adha.dates[1].date, DateTime(2027, 5, 16));
    });

    test('عطور الهدايا تُطابَق مع الكتالوج ويُتخطى المفقود', () {
      final products = <Product>[_product('royal'), _product('sultan')];
      final upcoming = upcomingOccasions(products, DateTime(2026, 11, 18));
      final newYear = upcoming.firstWhere((o) => o.occasion.id == 'new_year');
      expect(
        newYear.gifts.map((p) => p.id).toList(),
        <String>['sultan', 'royal'],
      );
      final ramadan = upcoming.firstWhere((o) => o.occasion.id == 'ramadan');
      expect(ramadan.gifts.map((p) => p.id).toList(), <String>['royal']);
    });

    test('موعد إشعار المناسبة: قبلها بأسبوع 12:00', () {
      expect(
        occasionReminderFireAt(DateTime(2027, 3, 9)),
        DateTime(2027, 3, 2, 12),
      );
    });

    test('تنسيق التاريخ عربياً', () {
      expect(formatArabicDate(DateTime(2026, 3, 20)), 'الجمعة، 20 مارس 2026');
      expect(formatBirthdayAr('1990-05-15'), '15 مايو 1990');
    });
  });

  group('حجز استشارة عطرية', () {
    test('رسالة واتساب تحمل اليوم والوقت والنوع والملاحظات', () {
      final request = ConsultationRequest(
        id: '1',
        date: '2027-02-10',
        timeSlot: '18:00',
        type: 'whatsapp',
        notes: 'أفضل العود.',
        createdAt: DateTime(2026, 11, 18),
      );
      final message = buildConsultationMessage(request);
      expect(message, contains('الأربعاء، 10 فبراير 2027'));
      expect(message, contains('6:00 مساءً'));
      expect(message, contains('واتساب'));
      expect(message, contains('أفضل العود.'));
      final url = consultationWhatsAppUrl(request);
      expect(url, startsWith('https://wa.me/201042881176?text='));
      expect(url, contains(Uri.encodeComponent('10 فبراير 2027')));
    });

    test('تنسيق خانات الوقت عربياً', () {
      expect(formatTimeSlotAr('12:00'), '12:00 ظهراً');
      expect(formatTimeSlotAr('18:00'), '6:00 مساءً');
      expect(formatTimeSlotAr('22:00'), '10:00 مساءً');
    });

    test('حفظ الطلب محلياً واسترجاعه في «استشاراتي»', () async {
      final service = ConsultationService();
      await service.save(
        ownerKey: 'user1',
        date: '2027-02-10',
        timeSlot: '18:00',
        type: 'call',
        notes: 'أفضل العود.',
      );
      await service.save(
        ownerKey: 'user1',
        date: '2027-02-12',
        timeSlot: '12:00',
        type: 'whatsapp',
      );
      final saved = await service.load(ownerKey: 'user1');
      expect(saved.length, 2);
      expect(saved[0].date, '2027-02-10');
      expect(saved[0].typeLabel, 'مكالمة هاتفية');
      expect(saved[0].statusLabel, 'بانتظار التأكيد');
      expect(saved[1].timeLabel, '12:00 ظهراً');
      // حساب آخر لا يرى طلبات هذا الحساب.
      expect(await service.load(ownerKey: 'user2'), isEmpty);
    });
  });

  group('إشعارات عيد الميلاد والمناسبات — التوجيه', () {
    test('parse لحمولتي عيد الميلاد والمناسبة', () {
      final birthday = ReminderTap.parse(ReminderTap.birthdayPayload);
      expect(birthday.kind, ReminderTapKind.birthday);
      final occasion = ReminderTap.parse(
        ReminderTap.occasionPayload('royal'),
      );
      expect(occasion.kind, ReminderTapKind.occasion);
      expect(occasion.productId, 'royal');
    });
  });

  group('نافذة نتيجة الاختبار — زر «شاهد العطر»', () {
    testWidgets('الزر موجود والضغط عليه يفتح صفحة العطر المرشَّح',
        (tester) async {
      var opened = false;
      await tester.pumpWidget(
        MaterialApp(
          home: QuizPage(onViewProduct: () => opened = true),
        ),
      );
      await tester.tap(find.text('دافئة وشرقية'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('في المناسبات'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('حضور قوي'));
      await tester.pumpAndSettle();
      expect(find.text('اختيارك من زخم'), findsOneWidget);
      expect(find.text('شاهد العطر'), findsOneWidget);
      expect(find.text('حسنًا'), findsOneWidget);
      await tester.tap(find.text('شاهد العطر'));
      await tester.pumpAndSettle();
      expect(opened, isTrue);
      expect(find.text('اختيارك من زخم'), findsNothing);
    });

    testWidgets('بلا معالج لا يظهر زر «شاهد العطر»',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: QuizPage()),
      );
      await tester.tap(find.text('دافئة وشرقية'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('في المناسبات'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('حضور قوي'));
      await tester.pumpAndSettle();
      expect(find.text('شاهد العطر'), findsNothing);
      expect(find.text('حسنًا'), findsOneWidget);
    });
  });
}
