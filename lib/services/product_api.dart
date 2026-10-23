import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/product.dart';

class ProductApi {
  ProductApi({this.baseUrl = AppConfig.apiBaseUrl, this.token});

  final String baseUrl;
  final String? token;

  Future<List<Product>> fetchProducts() async {
    final uri = baseUrl == AppConfig.apiBaseUrl
        ? AppConfig.productsUri
        : Uri.parse(baseUrl);
    late final http.Response response;
    try {
      response = await http.get(uri, headers: {
        'Accept': 'application/json',
        'User-Agent': 'HouseOfZakham/1.0 (Flutter; Android/iOS)',
        'X-API-Client': 'house-of-zakham-mobile',
        if (token != null && token!.isNotEmpty) 'Authorization': 'Bearer $token',
      }).timeout(const Duration(seconds: 20));
    } catch (error) {
      final message = error.toString();
      if (message.contains('CERTIFICATE_VERIFY_FAILED') ||
          message.contains('HandshakeException')) {
        throw Exception(
          'تعذر التحقق من شهادة TLS. يجب تثبيت شهادة HTTPS صالحة على الخادم.',
        );
      }
      throw Exception('تعذر الاتصال بخدمة المنتجات.');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Products API failed: ${response.statusCode}');
    }

    final body = response.body.trim();
    final contentType = response.headers['content-type'] ?? '';
    if (!contentType.contains('application/json') || body.startsWith('<')) {
      throw Exception('لم تُرجع خدمة المنتجات JSON صالحًا.');
    }

    final decoded = jsonDecode(body);
    final List<dynamic> items = decoded is List
        ? decoded
        : decoded is Map && decoded['products'] is List
            ? decoded['products'] as List<dynamic>
            : decoded is Map && decoded['data'] is List
                ? decoded['data'] as List<dynamic>
                : const <dynamic>[];

    return items
        .whereType<Map>()
        .map((item) => Product.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }
}
