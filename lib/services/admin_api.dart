import 'dart:convert';

import 'package:http/http.dart' as http;

class AdminApi {
  AdminApi({required this.token, this.baseUrl = 'https://zakhamhouse.shop'});
  final String token;
  final String baseUrl;
  Map<String, String> get headers => {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    'X-Admin-Token': token,
    'User-Agent': 'HouseOfZakham/1.0 (Flutter; Android/iOS)',
  };
  Future<Map<String, dynamic>> _get(String path) async {
    final r = await http
        .get(Uri.parse('$baseUrl$path'), headers: headers)
        .timeout(const Duration(seconds: 20));
    final body = _decode(r.body);
    if (r.statusCode < 200 || r.statusCode >= 300)
      throw Exception(body['message'] ?? 'فشل طلب الإدارة (${r.statusCode})');
    return body;
  }

  Future<List<dynamic>> products() async =>
      (await _get('/api/admin/products'))['products'] as List<dynamic>? ?? [];
  Future<List<dynamic>> customers([String query = '']) async =>
      (await _get(
            '/api/admin/customers?q=${Uri.encodeQueryComponent(query)}',
          ))['customers']
          as List<dynamic>? ??
      [];
  Future<Map<String, dynamic>> analytics() => _get('/api/analytics');

  Future<void> updateProduct({
    required String id,
    required Map<String, dynamic> product,
  }) async {
    final response = await http
        .patch(
          Uri.parse('$baseUrl/api/admin/products/${Uri.encodeComponent(id)}'),
          headers: headers,
          body: jsonEncode(product),
        )
        .timeout(const Duration(seconds: 20));
    final body = _decode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        body['message'] ?? 'تعذر حفظ المنتج (${response.statusCode})',
      );
    }
  }

  Future<void> deleteProduct(String id) async {
    final response = await http
        .delete(
          Uri.parse('$baseUrl/api/admin/products/${Uri.encodeComponent(id)}'),
          headers: headers,
        )
        .timeout(const Duration(seconds: 20));
    final body = _decode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        body['message'] ?? 'تعذر إخفاء المنتج (${response.statusCode})',
      );
    }
  }

  Map<String, dynamic> _decode(String raw) {
    final value = jsonDecode(raw);
    return value is Map<String, dynamic> ? value : {};
  }
}
