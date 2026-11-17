import 'package:flutter_test/flutter_test.dart';
import 'package:house_of_zakham/data/fragrance_cards.dart';
import 'package:house_of_zakham/models/product.dart';
import 'package:house_of_zakham/services/reviews_api.dart';
import 'package:house_of_zakham/services/verify_service.dart';

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

List<Product> _catalog() => <Product>[
      _product('layl', 'ليل زخم'),
      _product('elixir', 'إلكسير القوة'),
      _product('sultan', 'سلطان'),
      _product('royal', 'عطر زخم رويال'),
      _product('storm', 'عطر إعصار زخم'),
      _product('fares', 'عطر فارس زخم'),
      _product('musk', 'عطر خطوط المسك والتنوع'),
    ];

void main() {
  group('Fragrance cards merge', () {
    test('merges catalog extras with live products in store order', () {
      final cards = mergeFragranceCards(_catalog());
      expect(cards.length, 7);
      expect(cards.first.product.id, 'layl');
      expect(cards[3].extra.code, 'ZH-01');
      expect(cards[3].extra.stats, <int>[96, 92, 95, 20, 98]);
      expect(cards[3].extra.quote, contains('هيبة الملوك'));
    });

    test('new perfumes get defaults from the store wording', () {
      final cards = mergeFragranceCards(_catalog());
      final sultan = cards[2];
      expect(sultan.extra.code, isEmpty);
      expect(sultan.extra.quote, 'جلدي أرستقراطي مهيب.');
      expect(sultan.extra.wizardCategory, 'formal');
      expect(sultan.extra.wizardType, 'wood');
      expect(cards[1].extra.tag, 'السهرات والجاذبية المطلقة');
    });

    test('unknown product id falls back to neutral defaults', () {
      final cards = mergeFragranceCards(<Product>[_product('newone', 'عطر جديد')]);
      expect(cards.length, 1);
      expect(cards.first.extra.stats.length, 5);
      expect(cards.first.extra.top, contains('برغموت'));
    });

    test('wizard questions match the web page', () {
      expect(wizardQuestions.length, 2);
      expect(wizardQuestions[0].options.length, 4);
      expect(wizardQuestions[1].options.length, 4);
      expect(wizardQuestions[0].title, contains('المناسبة'));
      expect(radarAxes, <String>['الثبات', 'الفوحان', 'الدفء', 'الانتعاش', 'الهيبة']);
    });
  });

  group('Explorer recommendation (web-identical logic)', () {
    test('formal + wood recommends Sultan first', () {
      final cards = mergeFragranceCards(_catalog());
      expect(
        recommendFragranceCard(cards, 'formal', 'wood').product.id,
        'sultan',
      );
    });

    test('night + citrus falls back to the first night perfume', () {
      final cards = mergeFragranceCards(_catalog());
      expect(
        recommendFragranceCard(cards, 'night', 'citrus').product.id,
        'elixir',
      );
    });

    test('fresh + floral recommends Layl (first in store order)', () {
      final cards = mergeFragranceCards(_catalog());
      expect(
        recommendFragranceCard(cards, 'fresh', 'floral').product.id,
        'layl',
      );
    });

    test('feminine (no category) falls back to the first card', () {
      final cards = mergeFragranceCards(_catalog());
      expect(
        recommendFragranceCard(cards, 'feminine', 'wood').product.id,
        'layl',
      );
    });
  });

  group('VerifyService.prettyCode', () {
    test('groups ZKH digits in fours', () {
      expect(
        VerifyService.prettyCode('ZKHABCD1234EFGH5678'),
        'ZKH-ABCD-1234-EFGH-5678',
      );
      expect(
        VerifyService.prettyCode('ABCD1234EFGH5678'),
        'ZKH-ABCD-1234-EFGH-5678',
      );
    });

    test('zh_ codes are shown as-is', () {
      expect(
        VerifyService.prettyCode('zh_royal_00001'),
        'zh_royal_00001',
      );
    });
  });

  group('VerifyService.parseResult', () {
    test('checksum_ok is authentic with a record-unavailable note', () {
      final result = VerifyService.parseResult(<String, dynamic>{
        'status': 'checksum_ok',
        'code': 'ZKHABCD1234EFGH5678',
      });
      expect(result.authentic, isTrue);
      expect(result.title, 'بطاقة صادرة عن الدار');
      expect(result.rows.length, 2);
      expect(result.rows.first.value, 'ZKH-ABCD-1234-EFGH-5678');
    });

    test('full ok response renders product rows and scan count', () {
      final result = VerifyService.parseResult(<String, dynamic>{
        'status': 'ok',
        'product': 'زخم رويال',
        'code': 'ZKHABCD1234EFGH5678',
        'scans': 2,
        'row': <String, dynamic>{
          'serial_no': 'ZH-000123',
          'batch': 'B7',
          'issued_at': '2026-11-01 10:00:00',
          'sale_date': '2026-11-05',
        },
      });
      expect(result.authentic, isTrue);
      expect(result.title, contains('قطعة أصلية'));
      expect(result.title, contains('زخم رويال'));
      expect(
        result.rows.map((row) => row.key),
        containsAll(<String>['العطر', 'الرقم', 'المعرّف', 'الدفعة', 'تاريخ الإصدار', 'تاريخ البيع', 'مرات الفحص']),
      );
      expect(
        result.rows.firstWhere((row) => row.key == 'مرات الفحص').value,
        '2',
      );
      expect(result.message, contains('فُحص 2 مرة'));
    });

    test('not_found with checksum mismatch means the code does not match', () {
      final result = VerifyService.parseResult(<String, dynamic>{
        'status': 'not_found',
        'checksum': 'mismatch',
      });
      expect(result.authentic, isFalse);
      expect(result.title, 'الرقم غير مطابق');
    });

    test('revoked and bad_format map to the web messages', () {
      expect(
        VerifyService.parseResult(<String, dynamic>{'status': 'revoked'}).title,
        'رقم ملغى',
      );
      expect(
        VerifyService.parseResult(<String, dynamic>{'status': 'bad_format'}).message,
        contains('ZKH-'),
      );
      expect(
        VerifyService.parseResult(<String, dynamic>{'status': 'blocked'}).message,
        contains('انتظر دقيقة'),
      );
    });
  });

  group('Reviews API shapes', () {
    test('Review parses the GET /api/reviews shape', () {
      final review = Review.fromJson(<String, dynamic>{
        'productId': 'royal',
        'customerName': 'أحمد',
        'rating': 5,
        'comment': 'عطر رائع وثبات ممتاز.',
        'verified': 1,
        'createdAt': '2026-11-10 12:00:00',
      });
      expect(review.productId, 'royal');
      expect(review.verified, isTrue);
      expect(review.rating, 5);
    });

    test('ReviewSummary carries count and average', () {
      const summary = ReviewSummary(count: 3, average: 4.7);
      expect(summary.count, 3);
      expect(summary.average, 4.7);
    });
  });
}
