import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/product.dart';

class ProductApi {
  ProductApi({required this.baseUrl, this.token});

  final String baseUrl;
  final String? token;

  Future<List<Product>> fetchProducts() async {
    final response = await http.get(
      Uri.parse('$baseUrl/products'),
      headers: {
        'Accept': 'application/json',
        'User-Agent': 'HouseOfZakham/1.0 (Flutter; Android/iOS)',
        'X-API-Client': 'house-of-zakham-mobile',
        if (token != null && token!.isNotEmpty)
          'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Products API failed: ${response.statusCode}');
    }

    final contentType = response.headers['content-type'] ?? '';
    final body = response.body.trim();
    if (!contentType.contains('application/json') || body.startsWith('<')) {
      throw Exception(
        'The server returned HTML instead of JSON. Exclude /api.php from the hosting JavaScript protection.',
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
