import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'api_headers.dart';

/// رسالة واحدة في محادثة العملاء المصغرة. الدور `user` أو `assistant`
/// فقط — دور `system` يضعه الخادم، وأي دور system من العميل يرفضه الخادم.
class CustomerChatMessage {
  const CustomerChatMessage({required this.role, required this.content});

  final String role;
  final String content;

  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}

/// عميل محادثة العملاء المصغرة فوق نقطة عامة بلا مصادقة
/// (POST /api/advisor/chat).
///
/// وسيط خادم فقط: التطبيق لا يتصل بأي نموذج خارجي مباشرة، ولا يرسل
/// أي بيانات عملاء إطلاقاً — السياق يبنيه الخادم من كتالوج المتجر
/// فقط (الـ 11 عطراً: الاسم والنوتات والأسعار). المحادثة للبحث عن
/// العطور من داخل المتجر فقط: ترشيح عطر، وإعطاء النوتات، واكتشاف
/// العطور الموجودة — ولا شيء آخر؛ لا ميكسات ولا مواد ولا تركيبات
/// ولا أي بيانات داخلية تصل إلى هذه المحادثة إطلاقاً.
///
/// حدود العميل (والخادم يفرض حدوده هو أيضاً): 10 رسائل كحد أقصى في
/// السجل المُرسل، و1000 حرف كحد أقصى للرسالة الواحدة، و30 رسالة
/// كحد أقصى في الجلسة الواحدة.
class CustomerChatApi {
  CustomerChatApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// حد السجل المُرسل في الطلب الواحد.
  static const maxHistoryMessages = 10;

  /// حد حروف الرسالة الواحدة.
  static const maxMessageChars = 1000;

  /// حد رسائل المستخدم في جلسة المحادثة الواحدة.
  static const maxSessionMessages = 30;

  int _sentCount = 0;

  /// عدد رسائل المستخدم المُرسلة في هذه الجلسة.
  int get sentCount => _sentCount;

  /// هل بلغت الجلسة حد رسائلها؟ عندها تُبدأ محادثة جديدة.
  bool get sessionLimitReached => _sentCount >= maxSessionMessages;

  /// يصفّر عدّاد الجلسة عند بدء محادثة جديدة.
  void resetSession() => _sentCount = 0;

  /// ترويسات النقطة العامة: بلا كوكي جلسة وبلا CSRF وبلا أي تفويض.
  Map<String, String> get _headers =>
      ApiHeaders.build(json: true);

  /// يرسل سجل المحادثة (آخر 10 رسائل كحد أقصى) ويعيد رد المستشار نصاً.
  ///
  /// مهلة 60 ثانية لأن استدعاء النموذج على الخادم بطيء بطبيعته.
  Future<String> send(List<CustomerChatMessage> history) async {
    if (sessionLimitReached) {
      throw Exception(
        'وصلت لحد رسائل هذه الجلسة — ابدأ محادثة جديدة.',
      );
    }
    final trimmed = _validate(history);
    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}${AppConfig.customerChatPath}',
    );
    final response = await _client
        .post(
          uri,
          headers: _headers,
          body: jsonEncode({
            'messages': trimmed.map((m) => m.toJson()).toList(),
          }),
        )
        .timeout(const Duration(seconds: 60));
    final data = _decode(response.body);
    if (response.statusCode == 429) {
      throw Exception(
        'وصلت لحد الرسائل المسموح — حاول بعد قليل.',
      );
    }
    if (response.statusCode == 404) {
      throw Exception(
        'محادثة العملاء غير منشورة على الخادم بعد (404) — ستتوفر قريباً.',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        (data['message'] as String?)?.trim().isNotEmpty == true
            ? data['message']
            : 'تعذّر إرسال الرسالة.',
      );
    }
    final reply = (data['reply'] as String?)?.trim() ?? '';
    if (reply.isEmpty) {
      throw const FormatException('استجابة المستشار غير صالحة.');
    }
    _sentCount++;
    return reply;
  }

  /// يتحقق من السجل محلياً ويعيد آخر 10 رسائل كحد أقصى.
  List<CustomerChatMessage> _validate(List<CustomerChatMessage> history) {
    if (history.isEmpty || history.length > 100) {
      throw const FormatException('سجل المحادثة غير صالح.');
    }
    for (final message in history) {
      if (message.role != 'user' && message.role != 'assistant') {
        throw const FormatException('دور الرسالة غير مسموح.');
      }
      final content = message.content.trim();
      if (content.isEmpty || content.length > maxMessageChars) {
        throw const FormatException(
          'نص الرسالة يجب أن يكون بين 1 و1000 حرف.',
        );
      }
    }
    if (history.last.role != 'user') {
      throw const FormatException('آخر رسالة يجب أن تكون من المستخدم.');
    }
    final start = history.length > maxHistoryMessages
        ? history.length - maxHistoryMessages
        : 0;
    return history.sublist(start);
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
