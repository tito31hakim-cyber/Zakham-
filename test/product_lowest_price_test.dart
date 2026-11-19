import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_of_zakham/models/product.dart';
import 'package:house_of_zakham/theme/app_theme.dart';
import 'package:house_of_zakham/widgets/common_widgets.dart';

/// عطر قياسي بأسعار 2027 الكاملة: 100مل 500/700/950، 50مل 350/500/650،
/// 30مل 250/350 (النووي بلا 30مل).
Product _standardProduct() => Product.fromJson(<String, dynamic>{
      'product_id': 'royal',
      'name': 'زخم رويال',
      'prices': <String, dynamic>{'100': 500, '50': 350, '30': 250},
      'variants': <String, dynamic>{
        'presence': {
          'prices': {'100': 500, '50': 350, '30': 250}
        },
        'extra': {
          'prices': {'100': 700, '50': 500, '30': 350}
        },
        'nuclear': {
          'prices': {'100': 950, '50': 650}
        },
      },
      'visible': true,
      'stockStatus': 'available',
      'notes': <String, dynamic>{
        'top': ['ورد'],
        'middle': ['عود'],
        'base': ['مسك']
      },
    });

void main() {
  group('Product.lowestPrice', () {
    test('العطر القياسي: الأدنى 250 (30مل حُضور)', () {
      expect(_standardProduct().lowestPrice, 250);
    });

    test('الأسعار النصية كما يردها الخادم أحياناً تُحسب أيضاً', () {
      final product = Product.fromJson(<String, dynamic>{
        'product_id': 'royal',
        'name': 'زخم رويال',
        'prices': <String, dynamic>{'100': '500', '50': '350', '30': '250'},
        'variants': <String, dynamic>{
          'presence': {
            'prices': {'100': '500', '50': '350', '30': '250'}
          },
          'extra': {
            'prices': {'100': '700', '50': '500', '30': '350'}
          },
        },
        'visible': true,
        'stockStatus': 'available',
        'notes': <String, dynamic>{},
      });
      expect(product.lowestPrice, 250);
    });

    test('بلا متغيرات: الأدنى من الأسعار المسطّحة', () {
      final product = Product.fromJson(<String, dynamic>{
        'product_id': 'layl',
        'name': 'ليل زخم',
        'prices': <String, dynamic>{'100': 500, '50': 350, '30': 250},
        'variants': <String, dynamic>{},
        'visible': true,
        'stockStatus': 'available',
        'notes': <String, dynamic>{},
      });
      expect(product.lowestPrice, 250);
    });

    test('بلا أي أسعار: الرجوع إلى price', () {
      final product = Product.fromJson(<String, dynamic>{
        'product_id': 'custom',
        'name': 'عطر خاص',
        'price': 420,
        'prices': <String, dynamic>{},
        'variants': <String, dynamic>{},
        'visible': true,
        'stockStatus': 'available',
        'notes': <String, dynamic>{},
      });
      expect(product.lowestPrice, 420);
    });
  });

  group('ApiProductCard — عرض احترافي', () {
    testWidgets('تعرض «يبدأ من» بأقل سعر وأسماء التركيزات',
        (tester) async {
      final product = _standardProduct();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: ApiProductCard(product: product, onTap: () {}),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('يبدأ من 250 ج.م'), findsOneWidget);
      expect(find.textContaining('حُضور'), findsOneWidget);
      expect(find.textContaining('فَوْحان'), findsOneWidget);
      expect(find.textContaining('نووي'), findsOneWidget);
      // لا يظهر السعر الواحد القديم بصيغته (حجم • سعر عشري).
      expect(find.textContaining('500.00'), findsNothing);
    });
  });
}
