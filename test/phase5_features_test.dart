import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:house_of_zakham/models/cart_item.dart';
import 'package:house_of_zakham/models/product.dart';
import 'package:house_of_zakham/models/saved_address.dart';
import 'package:house_of_zakham/providers/discount_provider.dart';
import 'package:house_of_zakham/services/address_book.dart';
import 'package:house_of_zakham/services/customer_auth.dart';
import 'package:house_of_zakham/services/discounts.dart';
import 'package:house_of_zakham/services/egypt_locations.dart';
import 'package:house_of_zakham/services/invoice_pdf.dart';
import 'package:house_of_zakham/widgets/invoice_document.dart';

Product _product(String id, {double price = 250}) => Product(
      id: id,
      name: id,
      price: price,
      currency: 'EGP',
      size: '30 مل',
      category: 'perfume',
      topNotes: const <String>[],
      heartNotes: const <String>[],
      baseNotes: const <String>[],
      image: '',
      inStock: true,
    );

CartItem _item(String id, {int quantity = 1, double price = 250}) =>
    CartItem(
      product: _product(id, price: price),
      quantity: quantity,
      unitPrice: price,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SavedAddress — checkout fill', () {
    test('address pick fills governorate/city/street/phone', () {
      const address = SavedAddress(
        id: '7',
        label: 'بيت',
        governorate: 'كفر الشيخ',
        city: 'كفر الشيخ',
        street: 'شارع الجمهورية 12',
        phone: '01012345678',
        isDefault: true,
      );
      final fields = address.checkoutFields;
      expect(fields['governorate'], 'كفر الشيخ');
      expect(fields['city'], 'كفر الشيخ');
      expect(fields['street'], 'شارع الجمهورية 12');
      expect(fields['phone'], '01012345678');
    });

    test('JSON round-trip keeps label and default flag', () {
      const address = SavedAddress(
        id: 'local_1',
        label: 'شغل',
        governorate: 'القاهرة',
        city: 'مدينة نصر',
        street: 'شارع عباس العقاد 5',
        phone: '01111111111',
        isDefault: true,
      );
      final restored = SavedAddress.fromJson(address.toJson());
      expect(restored.label, 'شغل');
      expect(restored.governorate, 'القاهرة');
      expect(restored.isDefault, isTrue);
    });

    test('the 27 governorates list is complete', () {
      expect(egyptGovernorates.length, 27);
      expect(egyptGovernorates, contains('كفر الشيخ'));
      expect(egyptGovernorates, contains('القاهرة'));
    });
  });

  group('EgyptLocationsData', () {
    test('parses governorates and their cities', () {
      final data = EgyptLocationsData.fromJson(
        jsonDecode(
          '{"ok":true,"shippingFlat":120,"governorates":['
          '{"governorate":"كفر الشيخ","cities":["كفر الشيخ","دسوق"]},'
          '{"governorate":"القاهرة","cities":["مدينة نصر","المعادي"]}]}',
        ) as Map<String, dynamic>,
      );
      expect(data.governorates, hasLength(2));
      expect(data.citiesFor('كفر الشيخ'), ['كفر الشيخ', 'دسوق']);
      expect(data.citiesFor('غير موجود'), isEmpty);
    });
  });

  group('Discount math — buy 2', () {
    const rule = DiscountRule(
      id: '1',
      name: 'خصم الثنائية الملكية',
      productIds: ['royal', 'layl'],
      percent: 10,
    );

    test('applies at exactly 2 units of one covered type', () {
      final result = discountForCart(
        [_item('royal', quantity: 2)],
        [rule],
      );
      expect(result.amount, 50); // 2 × 250 × 10%
      expect(result.ruleNames, ['خصم الثنائية الملكية']);
    });

    test('does not apply at 1 covered item', () {
      final result = discountForCart([_item('royal')], [rule]);
      expect(result.amount, 0);
      expect(result.hasDiscount, isFalse);
    });

    test('does not apply to uncovered types', () {
      final result = discountForCart(
        [_item('musk', quantity: 2), _item('fahd', quantity: 2)],
        [rule],
      );
      expect(result.amount, 0);
    });

    test('applies across two different covered types (1 + 1)', () {
      final result = discountForCart(
        [_item('royal'), _item('layl')],
        [rule],
      );
      expect(result.amount, 50);
    });

    test('inactive rule never applies', () {
      final result = discountForCart(
        [_item('royal', quantity: 2)],
        [rule.copyWith(active: false)],
      );
      expect(result.amount, 0);
    });

    test('two rules on the same item take the highest percent only', () {
      const bigger = DiscountRule(
        id: '2',
        name: 'خصم أكبر',
        productIds: ['royal'],
        percent: 20,
      );
      final result = discountForCart(
        [_item('royal', quantity: 2)],
        [rule, bigger],
      );
      expect(result.amount, 100); // 20% not 30%
    });

    test('rule with 0% or empty product list never applies', () {
      expect(
        discountForCart(
          [_item('royal', quantity: 2)],
          [rule.copyWith(percent: 0)],
        ).amount,
        0,
      );
      expect(
        discountForCart(
          [_item('royal', quantity: 2)],
          [rule.copyWith(productIds: const <String>[])],
        ).amount,
        0,
      );
    });
  });

  group('DiscountRule JSON', () {
    test('parses product_ids from the server shape and round-trips', () {
      final rule = DiscountRule.fromJson({
        'id': 3,
        'name': 'عرض',
        'product_ids': '["royal","layl"]',
        'percent': 15,
        'active': 1,
      });
      expect(rule.id, '3');
      expect(rule.productIds, ['royal', 'layl']);
      expect(rule.percent, 15);
      expect(rule.active, isTrue);
      final request = rule.toRequestJson();
      expect(request['productIds'], ['royal', 'layl']);
      expect(request['percent'], 15);
    });

    test('admin rule toggle flips only the active flag', () {
      const rule = DiscountRule(
        id: '1',
        name: 'عرض',
        productIds: ['royal'],
        percent: 10,
        active: true,
      );
      final toggled = rule.copyWith(active: false);
      expect(toggled.active, isFalse);
      expect(toggled.name, rule.name);
      expect(toggled.productIds, rule.productIds);
      expect(toggled.percent, rule.percent);
    });
  });

  group('DiscountService + DiscountProvider', () {
    test('fetches active rules from the server payload', () async {
      final service = DiscountService(
        fetcher: () async => jsonEncode({
          'ok': true,
          'rules': [
            {
              'id': 1,
              'name': 'عرض',
              'productIds': ['royal'],
              'percent': 10,
              'active': true,
            },
          ],
        }),
      );
      final rules = await service.refresh();
      expect(rules, hasLength(1));
      expect(rules.first.name, 'عرض');
    });

    test('provider calculates the cart discount from fetched rules',
        () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final provider = DiscountProvider(
        service: DiscountService(
          fetcher: () async => jsonEncode({
            'ok': true,
            'rules': [
              {
                'id': 1,
                'name': 'عرض',
                'productIds': ['royal'],
                'percent': 10,
                'active': true,
              },
            ],
          }),
        ),
      );
      await provider.refresh();
      expect(provider.loaded, isTrue);
      final result = provider.calculationFor([_item('royal', quantity: 2)]);
      expect(result.amount, 50);
    });

    test('a missing endpoint yields no rules and no crash', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final service = DiscountService(fetcher: () async => null);
      expect(await service.refresh(), isEmpty);
    });
  });

  group('AddressBookService — local fallback', () {
    test('saves locally and reloads when the server is unreachable',
        () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      // خادم غير موجود أصلاً: أي محاولة شبكة ترفض فوراً فيسقط للمحلي.
      final book = AddressBookService(
        CustomerAuth(baseUrl: 'http://127.0.0.1:1'),
      );
      const owner = 'owner-1';
      expect(await book.load(ownerKey: owner), isEmpty);
      expect(book.serverAvailable, isFalse);
      const address = SavedAddress(
        id: '',
        label: 'بيت',
        governorate: 'كفر الشيخ',
        city: 'دسوق',
        street: 'شارع النيل 3',
        phone: '01012345678',
        isDefault: true,
      );
      final saved = await book.save(ownerKey: owner, address: address);
      expect(saved.id, startsWith('local_'));
      final loaded = await book.load(ownerKey: owner);
      expect(loaded, hasLength(1));
      expect(loaded.first.city, 'دسوق');
      expect(loaded.first.isDefault, isTrue);
    });

    test('setting a new default clears the old one', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final book = AddressBookService(
        CustomerAuth(baseUrl: 'http://127.0.0.1:1'),
      );
      const owner = 'owner-2';
      final first = await book.save(
        ownerKey: owner,
        address: const SavedAddress(
          id: '',
          label: 'بيت',
          governorate: 'القاهرة',
          city: 'المعادي',
          street: 'ش 1',
          phone: '01000000001',
          isDefault: true,
        ),
      );
      final second = await book.save(
        ownerKey: owner,
        address: const SavedAddress(
          id: '',
          label: 'شغل',
          governorate: 'الجيزة',
          city: 'الدقي',
          street: 'ش 2',
          phone: '01000000002',
        ),
      );
      await book.setDefault(ownerKey: owner, id: second.id);
      final loaded = await book.load(ownerKey: owner);
      final byId = {for (final a in loaded) a.id: a};
      expect(byId[first.id]!.isDefault, isFalse);
      expect(byId[second.id]!.isDefault, isTrue);
    });

    test('delete removes the address and other accounts stay separate',
        () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final book = AddressBookService(
        CustomerAuth(baseUrl: 'http://127.0.0.1:1'),
      );
      final saved = await book.save(
        ownerKey: 'owner-a',
        address: const SavedAddress(
          id: '',
          label: 'بيت',
          governorate: 'القاهرة',
          city: 'المعادي',
          street: 'ش 1',
          phone: '01000000001',
        ),
      );
      await book.save(
        ownerKey: 'owner-b',
        address: const SavedAddress(
          id: '',
          label: 'بيت',
          governorate: 'الجيزة',
          city: 'الدقي',
          street: 'ش 2',
          phone: '01000000002',
        ),
      );
      await book.delete(ownerKey: 'owner-a', id: saved.id);
      expect(await book.load(ownerKey: 'owner-a'), isEmpty);
      expect(await book.load(ownerKey: 'owner-b'), hasLength(1));
    });
  });

  group('PDF invoice — paid only', () {
    test('button rule: verified/paid only, never unpaid', () {
      expect(
        InvoicePdfService.canDownloadForPaymentStatus('verified'),
        isTrue,
      );
      expect(InvoicePdfService.canDownloadForPaymentStatus('paid'), isTrue);
      expect(
        InvoicePdfService.canDownloadForPaymentStatus('unpaid'),
        isFalse,
      );
      expect(InvoicePdfService.canDownloadForPaymentStatus(''), isFalse);
      expect(
        InvoicePdfService.canDownloadForPaymentStatus('proof_submitted'),
        isFalse,
      );
    });

    test('OrderInvoice parses orderDto and derives the extra discount',
        () {
      final invoice = OrderInvoice.fromJson({
        'orderRef': 'ZH-NOV-000002',
        'createdAt': '2026-11-16 10:00:00',
        'customerName': 'OSSAMA ABDELHAMID',
        'phone': '01012345678',
        'governorate': 'كفر الشيخ',
        'city': 'كفر الشيخ',
        'address': 'شارع الجمهورية 12',
        'paymentMethod': 'InstaPay | إنستاباي',
        'subtotal': 250,
        'shippingFee': 120,
        'discountAmount': 0,
        'discountCode': '',
        'bundleDiscount': 0,
        'total': 345,
        'status': 'delivered',
        'paymentStatus': 'verified',
        'items': [
          {
            'productId': 'elixir',
            'nameAr': 'إلكسير القوة',
            'sizeMl': 30,
            'concentration': 'presence',
            'quantity': 1,
            'unitPrice': 250,
            'lineTotal': 250,
          },
        ],
      });
      expect(invoice.isPaid, isTrue);
      // 250 + 120 − 345 = 25 جنيه خصم نقاط مستنتج من أرقام الخادم.
      expect(invoice.extraDiscount, 25);
      expect(invoice.items, hasLength(1));
      expect(invoice.items.first.concentrationLabel, 'حُضور');
    });

    test('unpaid invoice is not payable for download', () {
      final invoice = OrderInvoice.fromJson({
        'orderRef': 'ZH-NOV-000003',
        'createdAt': '2026-11-17 10:00:00',
        'customerName': 'OSSAMA ABDELHAMID',
        'phone': '01012345678',
        'governorate': 'كفر الشيخ',
        'city': '',
        'address': 'شارع الجمهورية 12',
        'paymentMethod': 'InstaPay | إنستاباي',
        'subtotal': 250,
        'shippingFee': 120,
        'discountAmount': 0,
        'discountCode': '',
        'total': 370,
        'status': 'pending_transfer',
        'paymentStatus': 'unpaid',
        'items': <Map<String, dynamic>>[],
      });
      expect(invoice.isPaid, isFalse);
      expect(
        InvoicePdfService.canDownloadForPaymentStatus(invoice.paymentStatus),
        isFalse,
      );
    });

    test('buildPdfFromImage produces a valid PDF with an image XObject',
        () async {
      final image = await _makeImage(200, 200);
      final bytes = await InvoicePdfService.buildPdfFromImage(image);
      expect(bytes.length, greaterThan(100));
      expect(
        String.fromCharCodes(bytes.sublist(0, 5)),
        '%PDF-',
      );
      // صورة الفاتورة مضمّنة كـ XObject داخل الملف.
      final text = latin1.decode(bytes);
      expect(text, contains('/Subtype/Image'));
      expect(text, contains('/Type/Page'));
    });

    testWidgets('invoice document renders Arabic content and totals',
        (tester) async {
      final invoice = OrderInvoice.fromJson({
        'orderRef': 'ZH-NOV-000002',
        'createdAt': '2026-11-16 10:00:00',
        'customerName': 'OSSAMA ABDELHAMID',
        'phone': '01012345678',
        'governorate': 'كفر الشيخ',
        'city': 'كفر الشيخ',
        'address': 'شارع الجمهورية 12',
        'paymentMethod': 'InstaPay | إنستاباي',
        'subtotal': 250,
        'shippingFee': 120,
        'discountAmount': 0,
        'discountCode': '',
        'bundleDiscount': 0,
        'total': 370,
        'status': 'delivered',
        'paymentStatus': 'verified',
        'items': [
          {
            'productId': 'elixir',
            'nameAr': 'إلكسير القوة',
            'sizeMl': 30,
            'concentration': 'presence',
            'quantity': 1,
            'unitPrice': 250,
            'lineTotal': 250,
          },
        ],
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: SingleChildScrollView(
              child: InvoiceDocument(invoice: invoice),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('فاتورة مبدئية'), findsOneWidget);
      expect(find.text('ZH-NOV-000002'), findsOneWidget);
      expect(find.text('إلكسير القوة'), findsOneWidget);
      expect(find.text('370 ج.م'), findsOneWidget);
      expect(find.text('دار زخم للعطور'), findsOneWidget);
    });
  });
}

Future<ui.Image> _makeImage(int width, int height) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    ui.Paint()..color = const ui.Color(0xFF000000),
  );
  final picture = recorder.endRecording();
  return picture.toImage(width, height);
}
