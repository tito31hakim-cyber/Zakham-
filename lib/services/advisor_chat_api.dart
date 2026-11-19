import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'api_headers.dart';

/// رسالة واحدة في محادثة المستشار. الدور `user` أو `assistant` فقط —
/// دور `system` يضعه الخادم، وأي دور system من العميل يرفضه الخادم.
class AdvisorChatMessage {
  const AdvisorChatMessage({required this.role, required this.content});

  final String role;
  final String content;

  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}

/// عميل محادثة المستشار فوق جلسة الإدارة الحالية.
///
/// وسيط آمن على الخادم فقط (POST /api/admin/advisor/chat): التطبيق لا
/// يتصل بأي نموذج خارجي مباشرة، ولا يرسل أي بيانات عملاء إطلاقاً —
/// السياق يبنيه الخادم من بيانات الدار فقط (الكتالوج والميكسات والمواد).
/// الردود مسودات للمراجعة فقط: لا اعتماد تركيبات ولا تغيير أسعار ولا
/// أي إجراء من المحادثة. المحادثة تعمل فوراً بلا مفتاح إطلاقاً (الخادم
/// يستدعي افتراضياً المزوّد المجاني)؛ فلا حالة «غير مفعّلة» هنا.
class AdvisorChatApi {
  AdvisorChatApi({
    required this.credentials,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final ApiCredentials credentials;

  /// ترويسات الإدارة: كوكي الجلسة + X-CSRF-Token (mutating: true)،
  /// مثل مسارات البحث الإدارية — بلا أي مفتاح خدمة.
  Map<String, String> get _headers =>
      ApiHeaders.build(credentials: credentials, json: true, mutating: true);

  /// يرسل سجل المحادثة كاملاً ويعيد رد المستشار نصاً.
  ///
  /// مهلة 60 ثانية لأن استدعاء النموذج على الخادم بطيء بطبيعته.
  Future<String> send(List<AdvisorChatMessage> history) async {
    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}${AppConfig.adminAdvisorChatPath}',
    );
    final response = await _client
        .post(
          uri,
          headers: _headers,
          body: jsonEncode({
            'messages': history.map((m) => m.toJson()).toList(),
          }),
        )
        .timeout(const Duration(seconds: 60));
    final data = _decode(response.body);
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw Exception('انتهت جلسة الإدارة — سجّل الدخول مجدداً.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        (data['message'] as String?)?.trim().isNotEmpty == true
            ? data['message']
            : 'تعذّر إرسال الرسالة إلى المستشار.',
      );
    }
    final reply = (data['reply'] as String?)?.trim() ?? '';
    if (reply.isEmpty) {
      throw const FormatException('استجابة المستشار غير صالحة.');
    }
    return reply;
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
