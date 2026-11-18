import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'api_headers.dart';

/// Read-only client for the cloud research catalog.
///
/// The sync worker must use the private internal endpoint. Flutter only
/// reads reviewed metadata through the admin session; it never receives a
/// service key and never uploads formulas directly.
class ResearchSyncApi {
  ResearchSyncApi({
    required this.credentials,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final ApiCredentials credentials;

  Map<String, String> get _headers =>
      ApiHeaders.build(credentials: credentials);

  Future<List<Map<String, dynamic>>> listMixes({
    String? status,
  }) async {
    final query = status == null || status.trim().isEmpty
        ? ''
        : '?status=${Uri.encodeQueryComponent(status.trim())}';
    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}/api/admin/research/mixes$query',
    );
    final response = await _client.get(uri, headers: _headers).timeout(const Duration(seconds: 15));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('تعذر تحميل كتالوج الميكسات (${response.statusCode}).');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map || decoded['mixes'] is! List) {
      throw const FormatException('استجابة كتالوج الميكسات غير صالحة.');
    }
    return List<Map<String, dynamic>>.from(
      (decoded['mixes'] as List).whereType<Map>().map(
            (item) => Map<String, dynamic>.from(item),
          ),
    );
  }

  Future<Map<String, dynamic>> knowledgeSummary() async {
    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}/api/admin/research/knowledge-summary',
    );
    final response = await _client.get(uri, headers: _headers).timeout(const Duration(seconds: 15));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('تعذر تحميل ملخص الذاكرة البحثية (${response.statusCode}).');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const FormatException('استجابة الذاكرة البحثية غير صالحة.');
    }
    return Map<String, dynamic>.from(decoded);
  }
}
