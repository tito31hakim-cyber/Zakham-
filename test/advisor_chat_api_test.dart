import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:house_of_zakham/services/advisor_chat_api.dart';
import 'package:house_of_zakham/services/api_headers.dart';

/// اختبارات عميل محادثة المستشار (advisor_chat_api).
///
/// لا استدعاء شبكة حقيقي إطلاقاً: كل الردود من `MockClient`، والخادم
/// الحقيقي لا يُلمس. ما يثبته الاختبار هو عقد العميل: مسار POST
/// الإداري، وترويسات الجلسة + CSRF بلا أي مفتاح خدمة، ومهلة 60 ثانية،
/// وإرسال سجل الرسائل كما هو، ورسائل الخطأ العربية — وأن المحادثة
/// تعمل بلا أي حالة «غير مفعّلة» (لا 503 ولا استثناء إعداد).

const _credentials = ApiCredentials();

AdvisorChatApi _apiWith(MockClient client) =>
    AdvisorChatApi(credentials: _credentials, client: client);

/// رد JSON بترميز UTF-8 صريح — `http.Response` النصي يرمّز الجسم
/// Latin-1 فيرمي على الأحرف العربية، بينما الخادم الحقيقي يرد
/// `application/json; charset=utf-8`.
http.Response _jsonResponse(Object body, int status) =>
    http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

http.Response _textResponse(String body, int status) =>
    http.Response.bytes(
      utf8.encode(body),
      status,
      headers: {'content-type': 'text/plain; charset=utf-8'},
    );

const _history = [
  AdvisorChatMessage(role: 'user', content: 'ما الفرق بين رويال وإعصار؟'),
];

void main() {
  group('AdvisorChatApi — عميل المحادثة', () {
    test('send يرسل سجل الرسائل إلى المسار الإداري ويعيد الرد', () async {
      http.Request? captured;
      final api = _apiWith(MockClient((request) async {
        captured = request;
        return _jsonResponse({
          'ok': true,
          'reply': 'رويال أهدأ من إعصار.',
          'model': 'openai',
        }, 200);
      }));
      final reply = await api.send(_history);
      expect(reply, 'رويال أهدأ من إعصار.');
      expect(captured, isNotNull);
      expect(captured!.url.host, 'zakhamhouse.shop');
      expect(captured!.url.path, '/api/admin/advisor/chat');
      expect(captured!.method, 'POST');
      expect(captured!.headers['Content-Type'], 'application/json');
      final body = jsonDecode(captured!.body) as Map<String, dynamic>;
      expect(body['messages'], hasLength(1));
      expect(body['messages'][0]['role'], 'user');
      expect(body['messages'][0]['content'], 'ما الفرق بين رويال وإعصار؟');
      // بلا أي مفتاح خدمة وبلا أي ترويسة تفويض.
      expect(captured!.headers.containsKey('Authorization'), isFalse);
      expect(captured!.headers.containsKey('X-Service-Key'), isFalse);
    });

    test('send يرمي رسالة جلسة منتهية عند 401', () async {
      final api = _apiWith(MockClient(
        (_) async => _jsonResponse({'error': 'admin_auth_required'}, 401),
      ));
      await expectLater(
        api.send(_history),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('انتهت جلسة الإدارة'),
        )),
      );
    });

    test('send يرمي خطأ الخادم برسالة واضحة عند 502', () async {
      final api = _apiWith(MockClient(
        (_) async => _jsonResponse({
          'ok': false,
          'error': 'advisor_upstream_error',
          'message': 'تعذّر الوصول إلى خدمة الذكاء حالياً. حاول مجدداً.',
        }, 502),
      ));
      await expectLater(
        api.send(_history),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('تعذّر الوصول إلى خدمة الذكاء'),
        )),
      );
    });

    test('send يرمي رسالة الجسم عند 200 مع ok:false', () async {
      final api = _apiWith(MockClient(
        (_) async => _jsonResponse({
          'ok': false,
          'error': 'advisor_upstream_error',
          'message': 'تعذّر الوصول إلى خدمة الذكاء حالياً. حاول مجدداً.',
        }, 200),
      ));
      await expectLater(
        api.send(_history),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('تعذّر الوصول إلى خدمة الذكاء'),
        )),
      );
    });

    test('send يرمي خطأ عاماً عند 200 مع ok:false بلا رسالة', () async {
      final api = _apiWith(MockClient(
        (_) async => _jsonResponse({'ok': false}, 200),
      ));
      await expectLater(
        api.send(_history),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('تعذّر إرسال الرسالة إلى المستشار'),
        )),
      );
    });

    test('send يرمي FormatException عند رد بلا نص', () async {
      final api = _apiWith(MockClient(
        (_) async => _jsonResponse({'ok': true, 'reply': '   '}, 200),
      ));
      await expectLater(
        api.send(_history),
        throwsA(isA<FormatException>()),
      );
    });

    test('send يرمي خطأ عاماً عند استجابة غير JSON', () async {
      final api = _apiWith(MockClient(
        (_) async => _textResponse('خطأ داخلي', 500),
      ));
      await expectLater(
        api.send(_history),
        throwsA(isA<Exception>()),
      );
    });
  });
}
