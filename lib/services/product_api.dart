import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/product.dart';

class ProductApi {
  ProductApi({required this.baseUrl, this.token});

  final String baseUrl;
  final String? token;

  Future<List<Product>> fetchProducts() async {
    late final http.Response response;
    try {
      response = await http
          .get(
            Uri.parse(baseUrl),
            headers: {
              'Accept': 'application/json',
              'User-Agent': 'HouseOfZakham/1.0 (Flutter; Android/iOS)',
              'X-API-Client': 'house-of-zakham-mobile',
              if (token != null && token!.isNotEmpty)
                'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 20));
    } catch (error) {
      final message = error.toString();
      if (message.contains('CERTIFICATE_VERIFY_FAILED') ||
          message.contains('HandshakeException')) {
        throw Exception(
          'تعذر التحقق من شهادة TLS للمخزن. يجب تثبيت شهادة HTTPS كاملة وصالحة على الخادم؛ لا يتم تعطيل التحقق داخل التطبيق.',
        );
      }
      throw Exception('تعذر الاتصال بخدمة المنتجات: $error');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Products API failed: ${response.statusCode}');
    }

    final contentType = response.headers['content-type'] ?? '';
    final body = response.body.trim();
    if (!contentType.contains('application/json') || body.startsWith('<')) {
      throw Exception(
        'The products URL did not return JSON. Check the static file and its hosting access rules.',
      );
    }

    final decoded = jsonDecode(body);
    final List<dynamic> items = decoded is List
        ? decoded
        : (decoded['data'] as List<dynamic>? ?? <dynamic>[decoded]);

    return items
        .whereType<Map<String, dynamic>>()
        .map(Product.fromJson)
        .toList();
  }
}
