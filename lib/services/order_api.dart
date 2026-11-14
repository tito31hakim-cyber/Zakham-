import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/cart_item.dart';
import 'api_headers.dart';

class OrderResult {
  const OrderResult({
    required this.orderRef,
    required this.total,
    required this.status,
    this.trackingToken = '',
  });

  final String orderRef;
  final double? total;
  final String status;
  final String trackingToken;
}

class OrderApi {
  OrderApi({
    this.baseUrl = AppConfig.apiBaseUrl,
    this.credentials,
  });

  final String baseUrl;
  final ApiCredentials? credentials;

  Future<OrderResult> createOrder({
    required String customerName,
    required String phone,
    required String governorate,
    required String city,
    required String address,
    required String paymentMethod,
    required String receiptReference,
    required String notes,
    required List<CartItem> items,
  }) async {
    if (items.isEmpty) throw Exception('السلة فارغة.');
    const supportedPayments = {
      'InstaPay | إنستاباي',
      'Vodafone Cash | فودافون كاش',
    };
    if (!supportedPayments.contains(paymentMethod)) {
      throw Exception('طريقة الدفع غير متاحة على الموقع.');
    }

    final uri = baseUrl == AppConfig.apiBaseUrl
        ? AppConfig.ordersUri
        : Uri.parse('$baseUrl${AppConfig.ordersPath}');
    final trackingToken = _secureToken();
    final payload = <String, dynamic>{
      'items': items
          .map(
            (item) => {
              'productId': item.product.id,
              'sizeMl': item.sizeMl,
              'concentration': item.concentration,
              'quantity': item.quantity,
            },
          )
          .toList(),
      'customerName': customerName.trim(),
      'phone': phone.trim(),
      'governorate': governorate,
      'address': '${city.trim()}، ${address.trim()}',
      'paymentMethod': paymentMethod,
      'receiptReference': receiptReference.trim(),
      'notes': notes.trim(),
      'discountCode': '',
      'idempotencyKey': _secureToken(),
      'trackingToken': trackingToken,
    };

    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll(ApiHeaders.build(credentials: credentials, mutating: true))
      ..fields['payload'] = jsonEncode(payload);
    final streamedResponse = await request.send().timeout(
      const Duration(seconds: 25),
    );
    final response = await http.Response.fromStream(streamedResponse);
    final body = _decode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(body['message'] ?? 'تعذر إنشاء الطلب.');
    }

    final rawOrder = body['order'];
    final order = rawOrder is Map
        ? Map<String, dynamic>.from(rawOrder)
        : <String, dynamic>{};
    final orderRef = '${order['orderRef'] ?? body['orderRef'] ?? ''}';
    if (orderRef.isEmpty) {
      throw Exception(body['message'] ?? 'استجابة إنشاء الطلب غير مكتملة.');
    }
    final rawTotal = order['total'] ?? body['total'];
    final double? total = rawTotal is num
        ? rawTotal.toDouble()
        : double.tryParse('$rawTotal');
    return OrderResult(
      orderRef: orderRef,
      total: total,
      status: '${order['status'] ?? body['status'] ?? 'received'}',
      trackingToken: '${body['trackingToken'] ?? ''}',
    );
  }

  String _secureToken() {
    final bytes = List<int>.generate(24, (_) => Random.secure().nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
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
