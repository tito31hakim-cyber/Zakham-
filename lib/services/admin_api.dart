import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'api_headers.dart';

class AdminApi {
  AdminApi({
    required String token,
    this.csrfToken,
    this.baseUrl = AppConfig.apiBaseUrl,
  }) : credentials = ApiCredentials(adminToken: token.trim(), csrfToken: csrfToken?.trim());

  final ApiCredentials credentials;
  final String? csrfToken;
  final String baseUrl;

  Map<String, String> _headers({bool mutating = false}) => ApiHeaders.build(
        credentials: credentials,
        json: mutating,
        mutating: mutating,
      );

  Uri _uri(Uri defaultUri, String path) =>
      baseUrl == AppConfig.apiBaseUrl ? defaultUri : Uri.parse('$baseUrl$path');

  Future<Map<String, dynamic>> _get(Uri uri) async {
    final response = await http
        .get(uri, headers: _headers())
        .timeout(const Duration(seconds: 20));
    return _validate(response);
  }

  Future<List<dynamic>> products() async =>
      (await _get(_uri(AppConfig.adminProductsUri, AppConfig.adminProductsPath)))['products']
          as List<dynamic>? ??
      [];

  Future<List<dynamic>> customers([String query = '']) async =>
      (await _get(_uri(
        AppConfig.adminCustomersUri(query),
        '${AppConfig.adminCustomersPath}?q=${Uri.encodeQueryComponent(query)}',
      )))['customers'] as List<dynamic>? ?? [];

  Future<Map<String, dynamic>> analytics() =>
      _get(_uri(AppConfig.analyticsUri, AppConfig.analyticsPath));

  Future<void> updateProduct({
    required String id,
    required Map<String, dynamic> product,
  }) async {
    final response = await http
        .patch(
          _uri(
            AppConfig.adminProductUri(id),
            '${AppConfig.adminProductsPath}/${Uri.encodeComponent(id)}',
          ),
          headers: _headers(mutating: true),
          body: jsonEncode(product),
        )
        .timeout(const Duration(seconds: 20));
    _validate(response);
  }

  Future<void> deleteProduct(String id) async {
    final response = await http
        .delete(
          _uri(
            AppConfig.adminProductUri(id),
            '${AppConfig.adminProductsPath}/${Uri.encodeComponent(id)}',
          ),
          headers: _headers(mutating: true),
        )
        .timeout(const Duration(seconds: 20));
    _validate(response);
  }

  Map<String, dynamic> _validate(http.Response response) {
    final body = _decode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(body['message'] ?? 'تعذر تنفيذ طلب الإدارة.');
    }
    return body;
  }

  Map<String, dynamic> _decode(String raw) {
    if (raw.trim().isEmpty) return <String, dynamic>{};
    try {
      final value = jsonDecode(raw);
      return value is Map<String, dynamic> ? value : <String, dynamic>{};
    } catch (_) {
      throw Exception('الخادم أعاد استجابة غير صالحة.');
    }
  }
}
