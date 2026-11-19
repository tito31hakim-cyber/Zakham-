import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:house_of_zakham/models/cart_item.dart';
import 'package:house_of_zakham/models/product.dart';
import 'package:house_of_zakham/services/customer_auth.dart';
import 'package:house_of_zakham/services/invoice_pdf.dart';
import 'package:house_of_zakham/services/json_numbers.dart';
import 'package:house_of_zakham/services/order_api.dart';

/// انحدار: الخادم يعيد حقول المبالغ كنصوص أحياناً ("370" بدل 370)،
/// والصبّ المباشر `as num?` ينفجر:
/// `type 'String' is not a subtype of type 'num?' in type cast`
/// فتختفي قائمة «طلباتي» في صفحة «حسابي».
///
/// لا استدعاء شبكة حقيقي إطلاقاً: كل الردود من `MockClient`.
/// ما يثبته الاختبار: المبالغ النصية تُقرأ كأرقام، والقيم الرقمية
/// العادية لا يتغير سلوكها، والحقول الغائبة أو الفاسدة تعود
/// إلى القيمة الاحتياطية بلا استثناء.
void main() {
  group('asDouble / asInt — تحويل متسامح', () {
    test('يقبل num ونصاً رقمياً ويعيد الاحتياطي عند الفساد', () {
      expect(asDouble(370), 370.0);
      expect(asDouble(370.5), 370.5);
      expect(asDouble('370'), 370.0);
      expect(asDouble(' 370.50 '), 370.5);
      expect(asDouble(null), 0);
      expect(asDouble('abc'), 0);
      expect(asDouble('abc', 7), 7);
      expect(asDouble(null, 9), 9);
      expect(asInt(30), 30);
      expect(asInt('30'), 30);
      expect(asInt('30.0'), 30);
      expect(asInt(null), 0);
      expect(asInt(null, 1), 1);
    });
  });

  group('CustomerOrder.fromJson — قائمة «طلباتي»', () {
    test('مبالغ نصية من الخادم تُبنى دون خطأ', () {
      final order = CustomerOrder.fromJson({
        'orderRef': 'ZH-NOV-000002',
        'createdAt': '2026-11-10',
        'customerName': 'أسامة',
        'phone': '01042881176',
        'governorate': 'كفر الشيخ',
        'address': 'القصابي',
        'paymentMethod': 'InstaPay',
        'subtotal': '250',
        'shippingFee': '120',
        'total': '370',
        'status': 'delivered',
        'paymentStatus': 'verified',
      });
      expect(order.subtotal, 250.0);
      expect(order.shippingFee, 120.0);
      expect(order.total, 370.0);
      expect(order.orderRef, 'ZH-NOV-000002');
    });

    test('مبالغ رقمية عادية لا يتغير سلوكها', () {
      final order = CustomerOrder.fromJson({
        'orderRef': 'ZH-1',
        'subtotal': 250,
        'shippingFee': 120,
        'total': 370.5,
      });
      expect(order.subtotal, 250.0);
      expect(order.shippingFee, 120.0);
      expect(order.total, 370.5);
    });

    test('حقول غائبة تعود إلى صفر بلا استثناء', () {
      final order = CustomerOrder.fromJson({'orderRef': 'ZH-1'});
      expect(order.subtotal, 0);
      expect(order.shippingFee, 0);
      expect(order.total, 0);
    });
  });

  group('OrderApi.createOrder — إجمالي وخصم حزم نصيان', () {
    Product product() => Product(
          id: 'royal',
          name: 'زخم رويال',
          nameEn: 'Royal',
          price: 500,
          currency: 'EGP',
          size: '100 ml',
          category: 'royal',
          topNotes: const ['زعفران'],
          heartNotes: const ['ورد'],
          baseNotes: const ['عود'],
          image: '',
          inStock: true,
          prices: const {'30': 250, '50': 350, '100': 500},
          variants: const {},
        );

    test('رد الخادم بمبالغ نصية يُقرأ دون خطأ', () async {
      final api = OrderApi(
        baseUrl: 'https://test.invalid',
        client: MockClient((request) async => http.Response(
              jsonEncode({
                'ok': true,
                'order': {
                  'orderRef': 'ZH-TEST-1',
                  'total': '620',
                  'status': 'pending_transfer',
                  'bundleDiscount': '50',
                },
              }),
              200,
              headers: {'content-type': 'application/json'},
            )),
      );
      final result = await api.createOrder(
        customerName: 'أسامة',
        phone: '01042881176',
        address: 'القصابي',
        paymentMethod: 'InstaPay | إنستاباي',
        items: [
          CartItem(
            product: product(),
            quantity: 2,
            concentration: 'presence',
            sizeMl: 30,
            unitPrice: 250,
          ),
        ],
        shippingFee: 120,
      );
      expect(result.total, 620.0);
      expect(result.bundleDiscount, 50.0);
    });
  });

  group('InvoiceItem / OrderInvoice — فاتورة بمبالغ نصية', () {
    test('صنف فاتورة بأرقام نصية يُبنى دون خطأ', () {
      final item = InvoiceItem.fromJson({
        'productId': 'royal',
        'nameAr': 'زخم رويال',
        'sizeMl': '30',
        'concentration': 'presence',
        'quantity': '2',
        'unitPrice': '250',
        'lineTotal': '500',
      });
      expect(item.sizeMl, 30);
      expect(item.quantity, 2);
      expect(item.unitPrice, 250.0);
      expect(item.lineTotal, 500.0);
    });

    test('فاتورة كاملة بمبالغ نصية تُبنى دون خطأ', () {
      final invoice = OrderInvoice.fromJson({
        'orderRef': 'ZH-NOV-000002',
        'createdAt': '2026-11-10',
        'customerName': 'أسامة',
        'phone': '01042881176',
        'governorate': 'كفر الشيخ',
        'city': 'سيدي سالم',
        'address': 'القصابي',
        'paymentMethod': 'InstaPay',
        'subtotal': '250',
        'shippingFee': '120',
        'discountAmount': '0',
        'discountCode': '',
        'bundleDiscount': '0',
        'total': '370',
        'status': 'delivered',
        'paymentStatus': 'verified',
        'items': [
          {
            'productId': 'royal',
            'nameAr': 'زخم رويال',
            'sizeMl': '30',
            'concentration': 'presence',
            'quantity': '1',
            'unitPrice': '250',
            'lineTotal': '250',
          },
        ],
      });
      expect(invoice.subtotal, 250.0);
      expect(invoice.shippingFee, 120.0);
      expect(invoice.total, 370.0);
      expect(invoice.items, hasLength(1));
      expect(invoice.items.first.lineTotal, 250.0);
    });
  });
}
