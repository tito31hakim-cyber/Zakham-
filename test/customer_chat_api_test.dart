import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:house_of_zakham/services/customer_chat_api.dart';

/// اختبارات عميل محادثة العملاء المصغرة (customer_chat_api).
///
/// لا استدعاء شبكة حقيقي إطلاقاً: كل الردود من `MockClient`.
/// ما يثبته الاختبار هو عقد العميل: مسار POST العام بلا أي مصادقة،
/// وحدود العميل (10 رسائل في السجل، 1000 حرف للرسالة، 30 رسالة
/// في الجلسة)، ورسائل الخطأ العربية — وأن المحادثة كتالوج فقط.

CustomerChatApi _apiWith(MockClient client) =>
    CustomerChatApi(client: client);

/// رد JSON بترميز UTF-8 صريح — `http.Response` النصي يرمّز الجسم
/// Latin-1 فيرمي على الأحرف العربية، بينما الخادم الحقيقي يرد
/// `application/json; charset=utf-8`.
http.Response _jsonResponse(Object body, int status) =>
    http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

const _history = [
  CustomerChatMessage(role: 'user', content: 'رشّح لي عطراً للسهرة'),
];

void main() {
  group('CustomerChatApi — محادثة العملاء', () {
    test('send يرسل إلى المسار العام بلا أي مصادقة ويعيد الرد', () async {
      http.Request? captured;
      final api = _apiWith(MockClient((request) async {
        captured = request;
        return _jsonResponse({
          'ok': true,
          'reply': 'جرّب زخم رويال — ورد وعنبر وعود.',
          'model': 'openai',
        }, 200);
      }));
      final reply = await api.send(_history);
      expect(reply, 'جرّب زخم رويال — ورد وعنبر وعود.');
      expect(captured, isNotNull);
      expect(captured!.url.host, 'zakhamhouse.shop');
      expect(captured!.url.path, '/api/advisor/chat');
      expect(captured!.method, 'POST');
      expect(captured!.headers['Content-Type'], 'application/json');
      final body = jsonDecode(captured!.body) as Map<String, dynamic>;
      expect(body['messages'], hasLength(1));
      expect(body['messages'][0]['content'], 'رشّح لي عطراً للسهرة');
      // بلا أي مصادقة: لا تفويض ولا كوكي ولا CSRF.
      expect(captured!.headers.containsKey('Authorization'), isFalse);
      expect(captured!.headers.containsKey('Cookie'), isFalse);
      expect(captured!.headers.containsKey('X-CSRF-Token'), isFalse);
    });

    test('send يقصّ السجل إلى آخر 10 رسائل', () async {
      http.Request? captured;
      final api = _apiWith(MockClient((request) async {
        captured = request;
        return _jsonResponse({'ok': true, 'reply': 'رد.'}, 200);
      }));
      final long = List<CustomerChatMessage>.generate(
        12,
        (i) => CustomerChatMessage(
          role: i.isEven ? 'user' : 'assistant',
          content: 'رسالة $i',
        ),
      );
      // آخر رسالة يجب أن تكون من المستخدم.
      long[11] = const CustomerChatMessage(role: 'user', content: 'رسالة 11');
      await api.send(long);
      final body = jsonDecode(captured!.body) as Map<String, dynamic>;
      expect((body['messages'] as List), hasLength(10));
      expect(body['messages'][0]['content'], 'رسالة 2');
      expect(body['messages'][9]['content'], 'رسالة 11');
    });

    test('send يرفض رسالة أطول من 1000 حرف قبل أي شبكة', () async {
      var calls = 0;
      final api = _apiWith(MockClient((_) async {
        calls++;
        return _jsonResponse({'ok': true, 'reply': 'رد.'}, 200);
      }));
      final long = 'أ' * 1001;
      await expectLater(
        api.send([CustomerChatMessage(role: 'user', content: long)]),
        throwsA(isA<FormatException>()),
      );
      expect(calls, 0);
    });

    test('send يقبل رد مساعد حتى 2000 حرف — سيناريو العطل الحي', () async {
      var calls = 0;
      final api = _apiWith(MockClient((_) async {
        calls++;
        return _jsonResponse({'ok': true, 'reply': 'رد.'}, 200);
      }));
      // سؤال مقارنة + رد مساعد طويل (1500 حرف) + متابعة قصيرة:
      // كان يُرفض بالحد القديم (1000 للكل)، ويُقبل بالحد حسب الدور.
      final reply = await api.send([
        const CustomerChatMessage(
          role: 'user',
          content: 'قارن بين رويال وإعصار',
        ),
        CustomerChatMessage(role: 'assistant', content: 'أ' * 1500),
        const CustomerChatMessage(role: 'user', content: 'زخم'),
      ]);
      expect(reply, 'رد.');
      expect(calls, 1);
    });

    test('send يرفض رد مساعد أطول من 2000 حرف برسالة الحد', () async {
      var calls = 0;
      final api = _apiWith(MockClient((_) async {
        calls++;
        return _jsonResponse({'ok': true, 'reply': 'رد.'}, 200);
      }));
      await expectLater(
        api.send([
          const CustomerChatMessage(role: 'user', content: 'سؤال'),
          CustomerChatMessage(role: 'assistant', content: 'أ' * 2001),
          const CustomerChatMessage(role: 'user', content: 'زخم'),
        ]),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('2000'),
        )),
      );
      expect(calls, 0);
    });

    test('send يرفض سجلاً فارغاً أو آخره ليس من المستخدم', () async {
      final api = _apiWith(MockClient(
        (_) async => _jsonResponse({'ok': true, 'reply': 'رد.'}, 200),
      ));
      await expectLater(api.send([]), throwsA(isA<FormatException>()));
      await expectLater(
        api.send(const [
          CustomerChatMessage(role: 'user', content: 'سؤال'),
          CustomerChatMessage(role: 'assistant', content: 'رد'),
        ]),
        throwsA(isA<FormatException>()),
      );
    });

    test('send يرمي رسالة حد الرسائل عند 429', () async {
      final api = _apiWith(MockClient(
        (_) async => _jsonResponse(
          {'ok': false, 'error': 'rate_limited'},
          429,
        ),
      ));
      await expectLater(
        api.send(_history),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('حد الرسائل'),
        )),
      );
    });

    test('send يرمي رسالة «غير منشورة» عند 404', () async {
      final api = _apiWith(MockClient(
        (_) async => _jsonResponse({'ok': false}, 404),
      ));
      await expectLater(
        api.send(_history),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('غير منشورة'),
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

    test('الجلسة تتوقف بعد 30 رسالة بلا استدعاء شبكة إضافي', () async {
      var calls = 0;
      final api = _apiWith(MockClient((_) async {
        calls++;
        return _jsonResponse({'ok': true, 'reply': 'رد.'}, 200);
      }));
      for (var i = 0; i < CustomerChatApi.maxSessionMessages; i++) {
        await api.send(_history);
      }
      expect(calls, CustomerChatApi.maxSessionMessages);
      expect(api.sessionLimitReached, isTrue);
      await expectLater(
        api.send(_history),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('حد رسائل هذه الجلسة'),
        )),
      );
      expect(calls, CustomerChatApi.maxSessionMessages);
      api.resetSession();
      expect(api.sessionLimitReached, isFalse);
      await api.send(_history);
      expect(calls, CustomerChatApi.maxSessionMessages + 1);
    });
  });
}
