import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:house_of_zakham/models/cart_item.dart';
import 'package:house_of_zakham/models/product.dart';
import 'package:house_of_zakham/services/order_api.dart';

/// اختبار تكاملي (على مستوى العقد) لإنشاء الطلب — الأولوية 2.
///
/// لا ينشئ أي طلب حقيقي: كل الردود من `MockClient`، والخادم الحقيقي
/// لا يُلمس إطلاقاً. ما يثبته الاختبار هو عقد `OrderApi.createOrder`
/// مع الخادم كما هو موثّق في التعليقات داخل `order_api.dart`:
/// مفتاح عدم التكرار في الترويسة والجسم، ورمز التتبع، والسعر الحقيقي
/// من الخادم، والحجم/التركيز المختارين، وطريقة الدفع، ورفض البيانات
/// الناقصة، وعدم تكرار الطلب عند الإرسال المزدوج.

const _instaPay = 'InstaPay | إنستاباي';
const _vodafoneCash = 'Vodafone Cash | فودافون كاش';

final _uuidV4 = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);
final _hex64 = RegExp(r'^[0-9a-f]{64}$');

Product _royal() => Product(
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
      variants: const {
        'presence': {
          'prices': {'30': 250, '50': 350, '100': 500},
        },
        'extra': {
          'prices': {'30': 350, '50': 500, '100': 700},
        },
      },
    );

CartItem _item({
  int quantity = 1,
  int sizeMl = 30,
  String concentration = 'presence',
  double? unitPrice,
}) =>
    CartItem(
      product: _royal(),
      quantity: quantity,
      concentration: concentration,
      sizeMl: sizeMl,
      unitPrice: unitPrice,
    );

OrderApi _api(http.Client client) => OrderApi(
      baseUrl: 'https://test.invalid',
      client: client,
    );

http.Response _ok({
  String orderRef = 'ZH-TEST-000001',
  double total = 620,
  String status = 'pending_transfer',
  double bundleDiscount = 0,
}) =>
    http.Response(
      jsonEncode({
        'ok': true,
        'order': {
          'orderRef': orderRef,
          'total': total,
          'status': status,
          'bundleDiscount': bundleDiscount,
        },
      }),
      200,
      headers: {'content-type': 'application/json'},
    );

Future<OrderResult> _create(
  OrderApi api, {
  List<CartItem>? items,
  String paymentMethod = _instaPay,
  String governorate = 'كفر الشيخ',
  String city = 'سيدي سالم',
  double shippingFee = 120,
}) =>
    api.createOrder(
      customerName: '  أسامة  ',
      phone: ' 01042881176 ',
      address: 'القصابي، وسط البلد',
      paymentMethod: paymentMethod,
      items: items ?? [_item(quantity: 2, unitPrice: 250)],
      governorate: governorate,
      city: city,
      shippingFee: shippingFee,
    );

void main() {
  group('إنشاء الطلب — مفتاح عدم التكرار ورمز التتبع', () {
    test('يرسل Idempotency-Key بصيغة UUID v4 في الترويسة والجسم معاً، ورمز تتبع 64 رقماً', () async {
      http.Request? captured;
      final client = MockClient((request) async {
        captured = request;
        return _ok();
      });

      await _create(_api(client));

      final request = captured!;
      expect(request.method, 'POST');
      expect(request.url.path, '/api/orders');
      expect(request.headers['Content-Type'], contains('application/json'));

      final headerKey = request.headers['Idempotency-Key'] ?? '';
      expect(headerKey, matches(_uuidV4));

      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['idempotencyKey'], headerKey);
      expect('${body['trackingToken']}', matches(_hex64));
    });

    test('كل محاولة إرسال تحمل مفتاحاً ورمز تتبع جديدين (لا يُعاد استخدام مفتاح محاولة سابقة)', () async {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        return _ok();
      });
      final api = _api(client);

      await _create(api);
      await _create(api);

      expect(requests, hasLength(2));
      final firstKey = requests[0].headers['Idempotency-Key'];
      final secondKey = requests[1].headers['Idempotency-Key'];
      expect(firstKey, isNot(secondKey));
      final firstBody = jsonDecode(requests[0].body) as Map<String, dynamic>;
      final secondBody = jsonDecode(requests[1].body) as Map<String, dynamic>;
      expect(firstBody['idempotencyKey'], isNot(secondBody['idempotencyKey']));
      expect(firstBody['trackingToken'], isNot(secondBody['trackingToken']));
    });
  });

  group('إنشاء الطلب — شكل الطلب المرسل', () {
    test('يرسل الحجم والتركيز والكمية والسعر المختارين فعلاً، مع المحافظة والمدينة والدفع', () async {
      Map<String, dynamic>? body;
      final client = MockClient((request) async {
        body = jsonDecode(request.body) as Map<String, dynamic>;
        return _ok();
      });

      await _create(_api(client));

      expect(body!['customerName'], 'أسامة');
      expect(body!['phone'], '01042881176');
      expect(body!['governorate'], 'كفر الشيخ');
      expect(body!['city'], 'سيدي سالم');
      expect(body!['address'], 'القصابي، وسط البلد');
      expect(body!['paymentMethod'], _instaPay);
      expect(body!['subtotal'], 500);
      expect(body!['shippingFee'], 120);
      expect(body!['total'], 620);

      final items = body!['items'] as List;
      expect(items, hasLength(1));
      final item = items.first as Map<String, dynamic>;
      expect(item['productId'], 'royal');
      expect(item['sizeMl'], 30);
      expect(item['concentration'], 'presence');
      expect(item['quantity'], 2);
      expect(item['unitPrice'], 250);
      expect(item['lineTotal'], 500);
    });

    test('سعر الوحدة يأتي من سعر المنتج للتركيز والحجم المختارين عند عدم تمريره صراحة', () async {
      Map<String, dynamic>? body;
      final client = MockClient((request) async {
        body = jsonDecode(request.body) as Map<String, dynamic>;
        return _ok();
      });

      // بلا unitPrice صريح: presence 30 مل = 250 من أسعار المنتج.
      await _create(
        _api(client),
        items: [_item(quantity: 1, sizeMl: 30, concentration: 'presence')],
      );

      final items = body!['items'] as List;
      expect((items.first as Map<String, dynamic>)['unitPrice'], 250);
      expect(body!['subtotal'], 250);
    });
  });

  group('إنشاء الطلب — السعر الحقيقي من الخادم', () {
    test('إجمالي النتيجة وخصم الحزمة يؤخذان من رد الخادم لا من حساب التطبيق', () async {
      final client = MockClient((_) async => _ok(
            total: 600,
            bundleDiscount: 50,
            status: 'pending_transfer',
          ));

      final result = await _create(_api(client));

      // التطبيق حسب 500 + 120 = 620؛ الخادم أعاد تسعيره إلى 600.
      expect(result.total, 600);
      expect(result.bundleDiscount, 50);
      expect(result.orderRef, 'ZH-TEST-000001');
      expect(result.status, 'pending_transfer');
    });
  });

  group('إنشاء الطلب — وسائل الدفع', () {
    test('فودافون كاش مقبولة مثل إنستاباي', () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return _ok();
      });

      final result = await _create(_api(client), paymentMethod: _vodafoneCash);
      expect(result.orderRef, 'ZH-TEST-000001');
      expect(calls, 1);
    });

    test('وسيلة دفع غير مدعومة تُرفض قبل أي طلب HTTP', () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return _ok();
      });
      final api = _api(client);

      for (final method in [
        'cash_on_delivery',
        'instapay',
        'wallet',
        '',
      ]) {
        await expectLater(
          _create(api, paymentMethod: method),
          throwsA(isA<Exception>()),
        );
      }
      expect(calls, 0);
    });
  });

  group('إنشاء الطلب — رفض البيانات الناقصة وأخطاء الخادم', () {
    test('سلة فارغة تُرفض قبل أي طلب HTTP', () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return _ok();
      });

      await expectLater(
        _create(_api(client), items: []),
        throwsA(
          predicate((e) => e is Exception && '$e'.contains('السلة فارغة')),
        ),
      );
      expect(calls, 0);
    });

    test('خطأ 422 من الخادم يظهر رسالته العربية كما هي', () async {
      final client = MockClient(
        (_) async => http.Response(
          jsonEncode({'ok': false, 'message': 'المدينة غير صالحة.'}),
          422,
          headers: {'content-type': 'application/json'},
        ),
      );

      await expectLater(
        _create(_api(client)),
        throwsA(
          predicate(
            (e) => e is Exception && '$e'.contains('المدينة غير صالحة'),
          ),
        ),
      );
    });

    test('خطأ 500 بلا جسم يعيد الرسالة العامة لا رسالة فارغة', () async {
      final client = MockClient((_) async => http.Response('', 500));

      await expectLater(
        _create(_api(client)),
        throwsA(
          predicate(
            (e) => e is Exception && '$e'.contains('تعذر إنشاء الطلب'),
          ),
        ),
      );
    });

    test('رد ناجح بلا رقم طلب يُرفض كاستجابة غير صالحة', () async {
      final client = MockClient(
        (_) async => http.Response(
          jsonEncode({'ok': true, 'order': {'total': 620}}),
          200,
          headers: {'content-type': 'application/json'},
        ),
      );

      await expectLater(
        _create(_api(client)),
        throwsA(isA<Exception>()),
      );
    });

    test('رد غير JSON يُرفض برسالة استجابة غير صالحة', () async {
      final client = MockClient((_) async => http.Response('not json', 200));

      await expectLater(
        _create(_api(client)),
        throwsA(
          predicate(
            (e) => e is Exception && '$e'.contains('غير صالحة'),
          ),
        ),
      );
    });
  });

  group('إنشاء الطلب — الإرسال المزدوج', () {
    test('إرسالان متتاليان لا يحملان نفس المفتاح أبداً، فلا يُحتسب الثاني نسخة صامتة من الأول', () async {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        return _ok();
      });
      final api = _api(client);

      final first = await _create(api);
      final second = await _create(api);

      expect(first.orderRef, 'ZH-TEST-000001');
      expect(second.orderRef, 'ZH-TEST-000001');
      expect(
        requests[0].headers['Idempotency-Key'],
        isNot(requests[1].headers['Idempotency-Key']),
      );
      // منع الضغطة المزدوجة على زر الإرسال نفسه مهمة واجهة إتمام الطلب
      // (الأولوية 3)؛ هنا يُثبَت أن طبقة الطلب لا تعيد إرسال مفتاح قديم.
    });
  });
}
