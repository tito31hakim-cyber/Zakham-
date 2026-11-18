import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:house_of_zakham/services/customer_auth.dart';

/// اختبارات الأولوية 4 — إعادة رفع إثبات الدفع والخروج من كل الأجهزة.
///
/// لا تمس الخادم الحقيقي: عميل التقاط يسجّل الطلب المرسل ويعيد رداً
/// جاهزاً. نقطة إعادة الإرسال موجودة على الخادم الحي
/// (POST /api/orders/{ref}/receipt)؛ ونقطة الخروج من كل الأجهزة
/// جديدة — 404 منها تعني أن الخادم لم يُنشر بعد.

class _CapturingClient extends http.BaseClient {
  http.BaseRequest? lastRequest;
  http.Response Function(http.BaseRequest request)? handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    lastRequest = request;
    final response = handler!(request);
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
    );
  }
}

CustomerAuth _auth(_CapturingClient client) =>
    CustomerAuth(baseUrl: 'https://test.invalid', client: client);

http.Response _json(Map<String, dynamic> body, int status) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

void main() {
  group('إعادة رفع إثبات الدفع', () {
    test('يرسل multipart إلى نقطة الإيصال بالملف والمرجع، ويعيد حالة الدفع الجديدة', () async {
      final client = _CapturingClient();
      client.handler = (_) => _json({
            'ok': true,
            'paymentStatus': 'proof_submitted',
            'version': 2,
          }, 200);

      final status = await _auth(client).resubmitReceipt(
        orderRef: 'ZH-TEST-000001',
        bytes: [1, 2, 3, 4],
        filename: 'receipt.jpg',
        receiptReference: 'REF123',
      );

      expect(status, 'proof_submitted');
      final request = client.lastRequest as http.MultipartRequest;
      expect(request.method, 'POST');
      expect(request.url.path, '/api/orders/ZH-TEST-000001/receipt');
      // ترويسة JSON ممنوعة هنا: MultipartRequest يضع ترويسته الخاصة.
      expect(request.headers['Content-Type'], isNull);
      expect(request.fields['receiptReference'], 'REF123');
      expect(request.files, hasLength(1));
      expect(request.files.first.field, 'receipt');
      expect(request.files.first.filename, 'receipt.jpg');
    });

    test('رفض الخادم 409 يظهر رسالته العربية كما هي', () async {
      final client = _CapturingClient();
      client.handler = (_) => _json({
            'ok': false,
            'message': 'يمكن إعادة إرسال الإيصال فقط بعد طلب ذلك من فريق دار زخم.',
          }, 409);

      await expectLater(
        _auth(client).resubmitReceipt(
          orderRef: 'ZH-TEST-000001',
          bytes: [1, 2, 3],
          filename: 'receipt.png',
        ),
        throwsA(
          predicate(
            (e) =>
                e is Exception &&
                '$e'.contains('بعد طلب ذلك من فريق دار زخم'),
          ),
        ),
      );
    });
  });

  group('الخروج من كل الأجهزة', () {
    test('ينشر إلى نقطة الخروج الجماعي وينسى الجلسة عند النجاح', () async {
      final client = _CapturingClient();
      client.handler = (_) => _json({'ok': true}, 200);
      final auth = _auth(client);
      auth.restoreCookie('PHPSESSID=abc; zk_remember=xyz');

      await auth.logoutFromAllDevices();

      expect(client.lastRequest!.method, 'POST');
      expect(client.lastRequest!.url.path, '/api/auth/logout-all');
      expect(auth.hasCookie, isFalse);
    });

    test('404 تعني أن النقطة لم تُنشر بعد — استثناء مخصص لا خطأ عام', () async {
      final client = _CapturingClient();
      client.handler = (_) => _json({'ok': false, 'message': 'not found'}, 404);

      await expectLater(
        _auth(client).logoutFromAllDevices(),
        throwsA(isA<LogoutAllUnavailableException>()),
      );
    });

    test('401 تعني انتهاء الجلسة — استثناء مصادقة', () async {
      final client = _CapturingClient();
      client.handler = (_) => _json(
            {'ok': false, 'message': 'سجّل الدخول إلى حسابك أولاً.'},
            401,
          );

      await expectLater(
        _auth(client).logoutFromAllDevices(),
        throwsA(isA<AuthRequiredException>()),
      );
    });
  });
}
