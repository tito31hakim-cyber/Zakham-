import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/cart_item.dart';

class OrderResult {
  const OrderResult({
    required this.orderRef,
    required this.total,
    required this.status,
  });

  final String orderRef;
  final double total;
  final String status;
}

class OrderApi {
  OrderApi({this.baseUrl = 'https://zakhamhouse.shop'});

  final String baseUrl;

  Future<OrderResult> createOrder({
    required String customerName,
    required String phone,
    required String address,
    required String paymentMethod,
    required List<CartItem> items,
    String governorate = 'غير محدد',
    String notes = '',
    double shippingFee = 0,
    String shippingLabel = 'يحدد لاحقًا',
  }) async {
    if (items.isEmpty) {
      throw Exception('السلة فارغة.');
    }

    final subtotal = items.fold<double>(0, (sum, item) => sum + item.total);
    final response = await http
        .post(
          Uri.parse('$baseUrl/api/orders'),
          headers: const {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'User-Agent': 'HouseOfZakham/1.0 (Flutter; Android/iOS)',
            'X-API-Client': 'house-of-zakham-mobile',
          },
          body: jsonEncode({
            'customerName': customerName.trim(),
            'phone': phone.trim(),
            'governorate': governorate,
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
            'items': items
                .map(
                  (item) => {
                    'productId': item.product.id,
                    'nameAr': item.product.name,
                    'nameEn': '',
                    'perfumeCode': '',
                    'sizeMl':
                        int.tryParse(
                          item.product.size.replaceAll(RegExp(r'[^0-9]'), ''),
                        ) ??
                        0,
                    'quantity': item.quantity,
                    'unitPrice': item.product.price,
                    'lineTotal': item.total,
                    'concentration': 'presence',
                  },
                )
                .toList(),
          }),
        )
        .timeout(const Duration(seconds: 20));

    final body = _decode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        body['message'] ?? 'تعذر إنشاء الطلب (${response.statusCode}).',
      );
    }

    final orderRef = '${body['orderRef'] ?? ''}';
    if (body['ok'] != true || orderRef.isEmpty) {
      throw Exception(body['message'] ?? 'استجابة إنشاء الطلب غير صالحة.');
    }

    return OrderResult(
      orderRef: orderRef,
      total: (body['total'] as num?)?.toDouble() ?? subtotal + shippingFee,
      status: '${body['status'] ?? 'pending_transfer'}',
    );
  }

  Map<String, dynamic> _decode(String raw) {
    if (raw.trim().isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } catch (_) {
      throw Exception('الخادم أعاد استجابة غير صالحة بدل JSON.');
    }
  }
}
