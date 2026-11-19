import 'package:flutter_test/flutter_test.dart';
import 'package:house_of_zakham/services/zakat_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// اختبارات زكاة التجارة — حساب خالص + حفظ محلي فقط.
///
/// لا استدعاء شبكة إطلاقاً. الحول سنة هجرية (354.367 يوماً تقريباً)
/// من تاريخ البداية، والزكاة 2.5% من صافي أموال التجارة الخاضعة
/// (نقدية + مخزون بسعر السوق + مستحقات − ديون) عند بلوغ النصاب
/// وتمام الحول. الزكاة ليست على الإيرادات فلا تُحسب من المبيعات.
void main() {
  group('ZakatCalculator — الحساب', () {
    final hawlStart = DateTime(2025, 1, 1);
    // بعد الحول بأكثر من سنة هجرية.
    final afterHawl = DateTime(2026, 1, 1);
    // قبل تمام الحول.
    final beforeHawl = DateTime(2025, 6, 1);

    ZakatInputs inputs({
      double cash = 100000,
      double inventory = 50000,
      double receivables = 20000,
      double debts = 10000,
      double nisab = 100000,
      DateTime? start,
    }) =>
        ZakatInputs(
          cash: cash,
          inventoryValue: inventory,
          receivables: receivables,
          debts: debts,
          hawlStart: start ?? hawlStart,
          nisab: nisab,
        );

    test('الصافي = نقدية + مخزون + مستحقات − ديون، والزكاة 2.5% منه',
        () {
      final result = ZakatCalculator.calculate(inputs(), now: afterHawl);
      // 100000 + 50000 + 20000 − 10000 = 160000؛ الزكاة 4000.
      expect(result.base, 160000);
      expect(result.nisabReached, isTrue);
      expect(result.hawlComplete, isTrue);
      expect(result.due, 4000);
      expect(result.isDue, isTrue);
    });

    test('الصافي دون النصاب — لا زكاة مستحقة', () {
      final result = ZakatCalculator.calculate(
        inputs(cash: 10000, inventory: 5000, receivables: 0, debts: 0),
        now: afterHawl,
      );
      expect(result.base, 15000);
      expect(result.nisabReached, isFalse);
      expect(result.hawlComplete, isTrue);
      expect(result.due, 0);
      expect(result.isDue, isFalse);
    });

    test('الحول لم يتم — لا زكاة مستحقة ولو بلغ النصاب', () {
      final result = ZakatCalculator.calculate(inputs(), now: beforeHawl);
      expect(result.nisabReached, isTrue);
      expect(result.hawlComplete, isFalse);
      expect(result.due, 0);
    });

    test('بلوغ النصاب تماماً يستحق الزكاة', () {
      final result = ZakatCalculator.calculate(
        inputs(cash: 100000, inventory: 0, receivables: 0, debts: 0),
        now: afterHawl,
      );
      expect(result.base, 100000);
      expect(result.nisabReached, isTrue);
      expect(result.due, 2500);
    });

    test('الديون أكبر من الأصول — الصافي سالب ولا زكاة', () {
      final result = ZakatCalculator.calculate(
        inputs(cash: 10000, inventory: 0, receivables: 0, debts: 50000),
        now: afterHawl,
      );
      expect(result.base, -40000);
      expect(result.nisabReached, isFalse);
      expect(result.due, 0);
    });

    test('نهاية الحول = البداية + سنة هجرية (354.367 يوماً)', () {
      final result = ZakatCalculator.calculate(inputs(), now: afterHawl);
      final expected = hawlStart.add(ZakatCalculator.hawlDuration);
      expect(result.hawlEnd, expected);
      // 354.367 يوماً ≈ 354 يوماً و8 ساعات و48 دقيقة.
      expect(
        result.hawlEnd.difference(hawlStart).inDays,
        354,
      );
    });

    test('مبلغ سالب يرفض', () {
      expect(
        () => ZakatCalculator.calculate(inputs(debts: -1), now: afterHawl),
        throwsArgumentError,
      );
    });

    test('نصاب صفر أو سالب يرفض', () {
      expect(
        () => ZakatCalculator.calculate(inputs(nisab: 0), now: afterHawl),
        throwsArgumentError,
      );
    });

    test('تاريخ بداية حول في المستقبل يرفض', () {
      expect(
        () => ZakatCalculator.calculate(
          inputs(start: DateTime(2027, 1, 1)),
          now: afterHawl,
        ),
        throwsArgumentError,
      );
    });
  });

  group('ZakatService — الحفظ على الجهاز فقط', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('حفظ ثم تحميل يعيد المدخلات نفسها', () async {
      final service = ZakatService();
      final saved = ZakatInputs(
        cash: 120000,
        inventoryValue: 80000,
        receivables: 5000,
        debts: 15000,
        hawlStart: _hawlStartDate,
        nisab: 90000,
      );
      await service.save(saved);
      final loaded = await service.load();
      expect(loaded, isNotNull);
      expect(loaded!.cash, 120000);
      expect(loaded.inventoryValue, 80000);
      expect(loaded.receivables, 5000);
      expect(loaded.debts, 15000);
      expect(loaded.nisab, 90000);
      expect(loaded.hawlStart, DateTime(2025, 3, 1));
      expect(loaded.zakatableBase, 190000);
    });

    test('لا شيء محفوظ — التحميل يعيد null', () async {
      expect(await ZakatService().load(), isNull);
    });

    test('المسح يزيل المدخلات المحفوظة', () async {
      final service = ZakatService();
      await service.save(
        ZakatInputs(
          cash: 1,
          inventoryValue: 0,
          receivables: 0,
          debts: 0,
          hawlStart: DateTime(2025, 1, 1),
          nisab: 1,
        ),
      );
      expect(await service.load(), isNotNull);
      await service.clear();
      expect(await service.load(), isNull);
    });
  });
}

/// تاريخ ثابت للاختبار — `DateTime` ليس له مصنّع ثابت،
/// فيُبنى خارج الثابت.
final _hawlStartDate = DateTime(2025, 3, 1);
