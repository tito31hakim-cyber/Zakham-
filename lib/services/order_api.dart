import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/cart_item.dart';
import 'api_headers.dart';
import 'secure_http.dart';

class OrderResult {
  const OrderResult({
    required this.orderRef,
    required this.total,
    required this.status,
    this.bundleDiscount = 0,
  });

  final String orderRef;
  final double total;
  final String status;

  /// خصم عروض الحزم كما أكّده الخادم في رد إنشاء الطلب (0 قبل نشر
  /// نقطة الخصم أو عند عدم انطباق أي قاعدة) — الرقم الوحيد الموثوق،
  /// فالتطبيق لا يزعم خصماً لم يؤكده الخادم.
  final double bundleDiscount;
}

class OrderApi {
  OrderApi({
    this.baseUrl = AppConfig.apiBaseUrl,
    this.credentials,
    http.Client? client,
  }) : _client = client;

  final String baseUrl;
  final ApiCredentials? credentials;

  /// HTTP client override — للاختبارات فقط. في الإنتاج يبقى null فيُستخدم
  /// عميل SecureHttp المثبّت الشهادة. لا يُمرَّر عميل حقيقي غير مثبّت أبداً.
  final http.Client? _client;

  /// The PHP endpoint validates this header as an RFC 4122 UUID.
  /// A fresh key is generated for every checkout attempt so retries are
  /// safely distinguishable from a previously accepted order.
  String _idempotencyKey() {
    final bytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-'
        '${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }

  /// The server also requires a 64-hex tracking token in the body
  /// (`trackingToken`, checked before the order is created). The web
  /// storefront generates one per checkout attempt; the app does the same.
  String _trackingToken() {
    final bytes = List<int>.generate(32, (_) => Random.secure().nextInt(256));
    return bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
  }

  Future<OrderResult> createOrder({
    required String customerName,
    required String phone,
    required String address,
    required String paymentMethod,
    required List<CartItem> items,
    String governorate = 'غير محدد',
    // المدينة — اختياري: تُرسل فقط عند اختيارها من القائمة المعتمدة
    // (GET /api/locations/eg)؛ الخادم يتحقق منها (422 invalid_city)
    // عند إرسالها، وتُهمل فارغة.
    String city = '',
    String notes = '',
    double shippingFee = 0,
    String shippingLabel = 'يحدد لاحقًا',
    // نقاط الولاء المستبدَلة في هذا الطلب (0 = بلا استبدال). الخادم
    // يعيد التحقق والخصم بنفسه من الرصيد الحقيقي؛ أي رفض منه (422)
    // يظهر رسالته وتبقى السلة محفوظة.
    int pointsUsed = 0,
  }) async {
    if (items.isEmpty) throw Exception('السلة فارغة.');

    final subtotal = items.fold<double>(0, (sum, item) => sum + item.total);
    final uri = baseUrl == AppConfig.apiBaseUrl
        ? AppConfig.ordersUri
        : Uri.parse('$baseUrl${AppConfig.ordersPath}');
    // الخادم يقبل حصراً قيمتَي الدفع المسبق هاتين حرفياً، وأي قيمة أخرى
    // (مثل cash_on_delivery أو instapay أو wallet) تُرفض 422
    // invalid_payment_method — لذلك يتحقق التطبيق منهما قبل الإرسال.
    const supportedPayments = <String>[
      'InstaPay | إنستاباي',
      'Vodafone Cash | فودافون كاش',
    ];
    if (!supportedPayments.contains(paymentMethod)) {
      throw Exception('وسيلة الدفع غير مدعومة. الدفع المسبق متاح عبر إنستاباي أو فودافون كاش فقط.');
    }
    final idempotencyKey = _idempotencyKey();
    final headers = ApiHeaders.build(
      credentials: credentials,
      json: true,
      mutating: true,
    )
      ..['Idempotency-Key'] = idempotencyKey;

    final response = await (_client ?? SecureHttp.client)
        .post(
          uri,
          headers: headers,
          body: jsonEncode({
            // الخادم يقرأ المفتاحين من جسم الطلب حصراً (api.php):
            // idempotencyKey بصيغة [a-f0-9-]{16,64} وtrackingToken
            // مكوّن من 64 رقماً ست عشرياً — إرسالهما في الترويسة
            // وحدها لا يكفي ويرفض الطلب 422.
            'idempotencyKey': idempotencyKey,
            'trackingToken': _trackingToken(),
            'customerName': customerName.trim(),
            'phone': phone.trim(),
            'governorate': governorate,
            'city': city.trim(),
            'address': address.trim(),
            'paymentMethod': paymentMethod,
            'receiptReference': '',
            'receiptName': '',
            'notes': notes,
            'subtotal': subtotal,
            'shippingFee': shippingFee,
            'shippingLabel': shippingLabel,
            'total': subtotal + shippingFee,
            'discountCode': '',
            // نقاط الولاء: تُرسل فقط إن اختار العميل الاستبدال؛ الخادم
            // يتحقق من الرصيد والحد الأدنى (50) والسقف قبل الخصم.
            'pointsUsed': pointsUsed,
            'items': items
                .map(
                  (item) => {
                    'productId': item.product.id,
                    'nameAr': item.product.name,
                    'nameEn': item.product.nameEn,
                    // الخادم يشتق perfumeCode من صف المنتج في قاعدته؛
                    // الرد العام لا يحمل perfumeCode أصلاً فلا يُرسل هنا.
                    'perfumeCode': '',
                    // الحجم والتركيز المختاران فعلاً من صفحة المنتج؛
                    // الخادم يعيد تسعير الصنف منهما ويرفض التركيبة
                    // غير المتاحة (422 invalid_variant).
                    'sizeMl': item.sizeMl,
                    'quantity': item.quantity,
                    'unitPrice': item.unitPrice,
                    'lineTotal': item.total,
                    'concentration': item.concentration,
                  },
                )
                .toList(),
          }),
        )
        .timeout(const Duration(seconds: 20));

    final body = _decode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(body['message'] ?? 'تعذر إنشاء الطلب.');
    }
    // الخادم يعيد الطلب داخل حقل order (orderDto: orderRef/total/status)
    // لا في مستوى الرد الأعلى — يُقرأ من هناك مع بديل للمستوى الأعلى.
    final order = body['order'] is Map<String, dynamic>
        ? body['order'] as Map<String, dynamic>
        : body;
    final orderRef = '${order['orderRef'] ?? ''}';
    if (body['ok'] != true || orderRef.isEmpty) {
      throw Exception(body['message'] ?? 'استجابة إنشاء الطلب غير صالحة.');
    }
    return OrderResult(
      orderRef: orderRef,
      total: (order['total'] as num?)?.toDouble() ?? subtotal + shippingFee,
      status: '${order['status'] ?? 'pending_transfer'}',
      bundleDiscount:
          (order['bundleDiscount'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> _decode(String raw) {
    if (raw.trim().isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } catch (_) {
      throw Exception('الخادم أعاد استجابة غير صالحة.');
    }
  }
}
