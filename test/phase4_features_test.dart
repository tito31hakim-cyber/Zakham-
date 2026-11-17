import 'package:flutter_test/flutter_test.dart';
import 'package:house_of_zakham/models/product.dart';
import 'package:house_of_zakham/services/customer_auth.dart';
import 'package:house_of_zakham/services/daily_perfume.dart';
import 'package:house_of_zakham/services/loyalty.dart';
import 'package:house_of_zakham/services/reminder_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Product _product(String id, String name) => Product(
      id: id,
      name: name,
      price: 500,
      currency: 'EGP',
      size: '100 ml',
      category: 'official',
      topNotes: const <String>['برغموت'],
      heartNotes: const <String>['ورد'],
      baseNotes: const <String>['عود'],
      image: 'https://zakhamhouse.shop/assets/products/$id.webp',
      inStock: true,
    );

List<Product> _eleven() =>
    List<Product>.generate(11, (i) => _product('p$i', 'عطر $i'));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Loyalty points math', () {
    test('5 points per 100 EGP of products subtotal, rounded nearest', () {
      // قاعدة صاحب الدار: 250 جنيه = 13 نقطة (12.5 تُقرَّب لأعلى).
      expect(loyaltyPointsEarned(250), 13);
      expect(loyaltyPointsEarned(950), 48);
      expect(loyaltyPointsEarned(100), 5);
      expect(loyaltyPointsEarned(370), 19);
      expect(loyaltyPointsEarned(500), 25);
      expect(loyaltyPointsEarned(0), 0);
      expect(loyaltyPointsEarned(-10), 0);
    });

    test('redemption cap is min(balance, products subtotal)', () {
      expect(maxRedeemablePoints(balance: 100, productsSubtotal: 250), 100);
      expect(maxRedeemablePoints(balance: 500, productsSubtotal: 250), 250);
      expect(maxRedeemablePoints(balance: 0, productsSubtotal: 250), 0);
      expect(maxRedeemablePoints(balance: 50, productsSubtotal: 250), 50);
      expect(maxRedeemablePoints(balance: 100, productsSubtotal: 0), 0);
    });

    test('redemption needs at least 50 points', () {
      expect(canRedeemPoints(49), isFalse);
      expect(canRedeemPoints(50), isTrue);
      expect(canRedeemPoints(120), isTrue);
    });

    test('clamp enforces the 50-point minimum and the cap', () {
      // أقل من الحد الأدنى يُرفض كاملاً (0 لا استبدال جزئي).
      expect(
        clampPointsUsed(balance: 100, productsSubtotal: 250, requested: 30),
        0,
      );
      expect(
        clampPointsUsed(balance: 100, productsSubtotal: 250, requested: 200),
        100,
      );
      expect(
        clampPointsUsed(balance: 100, productsSubtotal: 250, requested: 80),
        80,
      );
      expect(
        clampPointsUsed(balance: 40, productsSubtotal: 250, requested: 40),
        0,
      );
      // السقف: مجموع المنتجات لا الرصيد.
      expect(
        clampPointsUsed(balance: 500, productsSubtotal: 250, requested: 500),
        250,
      );
    });
  });

  group('Perfume of the day rotation', () {
    test('same day -> same perfume; next day -> next in order', () {
      final products = _eleven();
      expect(perfumeOfTheDay(products, DateTime(2026, 1, 1))?.id, 'p0');
      expect(perfumeOfTheDay(products, DateTime(2026, 1, 2))?.id, 'p1');
      expect(perfumeOfTheDay(products, DateTime(2026, 1, 11))?.id, 'p10');
      // يلف بعد آخر عطر.
      expect(perfumeOfTheDay(products, DateTime(2026, 1, 12))?.id, 'p0');
      // نفس اليوم بأوقات مختلفة -> العطر نفسه.
      expect(
        perfumeOfTheDay(products, DateTime(2026, 1, 1, 23, 59))?.id,
        'p0',
      );
    });

    test('empty catalog -> null (never shows empty)', () {
      expect(
        perfumeOfTheDay(const <Product>[], DateTime(2026, 1, 1)),
        isNull,
      );
    });

    test('next fire time is 18:00 today or tomorrow', () {
      expect(
        nextDailyPerfumeFireAt(DateTime(2026, 11, 18, 10, 0)),
        DateTime(2026, 11, 18, 18, 0),
      );
      expect(
        nextDailyPerfumeFireAt(DateTime(2026, 11, 18, 19, 0)),
        DateTime(2026, 11, 19, 18, 0),
      );
      expect(
        nextDailyPerfumeFireAt(DateTime(2026, 11, 18, 18, 0)),
        DateTime(2026, 11, 19, 18, 0),
      );
    });
  });

  group('Loyalty server gating', () {
    test('Customer without pointsBalance -> null (server not deployed)', () {
      final customer = Customer.fromJson({
        'openId': 'x',
        'displayName': 'A',
        'email': 'a@b.c',
      });
      expect(customer.pointsBalance, isNull);
    });

    test('Customer with pointsBalance keeps it and copyWith updates it', () {
      final customer = Customer.fromJson({
        'openId': 'x',
        'displayName': 'A',
        'email': 'a@b.c',
        'pointsBalance': 120,
      });
      expect(customer.pointsBalance, 120);
      expect(customer.copyWith(pointsBalance: 80).pointsBalance, 80);
    });

    test('daily payload round-trips through parse', () {
      final tap = ReminderTap.parse(ReminderTap.dailyPayload('layl'));
      expect(tap.kind, ReminderTapKind.daily);
      expect(tap.productId, 'layl');
    });
  });

  group('Daily perfume toggle and scheduling', () {
    test('defaults on; turning off persists', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      expect(await ReminderService.instance.isDailyPerfumeEnabled(), isTrue);
      await ReminderService.instance.setDailyPerfumeEnabled(false);
      expect(await ReminderService.instance.isDailyPerfumeEnabled(), isFalse);
      await ReminderService.instance.setDailyPerfumeEnabled(true);
      expect(await ReminderService.instance.isDailyPerfumeEnabled(), isTrue);
    });

    test('scheduling persists the next 18:00 fire time (best-effort)', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await ReminderService.instance.setDailyPerfumeEnabled(true);
      await ReminderService.instance.ensureDailyPerfumeScheduled(
        productId: 'layl',
        productName: 'ليل زخم',
        price: 250,
        now: DateTime(2026, 11, 18, 10, 0),
      );
      final fireAt =
          await ReminderService.instance.dailyPerfumeFireTime();
      expect(fireAt, DateTime(2026, 11, 18, 18, 0));
    });
  });
}
