import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:house_of_zakham/services/api_headers.dart';
import 'package:house_of_zakham/services/research_pdfs_api.dart';

/// اختبارات عميل رفع ملفات PDF لذاكرة البحث (research_pdfs_api).
///
/// لا استدعاء شبكة حقيقي إطلاقاً: كل الردود من `MockClient`.
/// ما يثبته الاختبار هو عقد العميل: مسار POST الإداري بترويسات
/// الجلسة + CSRF بلا أي مفتاح خدمة، والرفع المتعدد الأجزاء مع
/// تقدم، وحد 10MB وصيغة PDF فقط، وقائمة الملفات مع حالاتها.

const _credentials = ApiCredentials(
  cookie: 'PHPSESSID=test-session',
  csrfToken: 'test-csrf-token',
);

ResearchPdfsApi _apiWith(MockClient client) =>
    ResearchPdfsApi(credentials: _credentials, client: client);

/// رد JSON بترميز UTF-8 صريح — `http.Response` النصي يرمّز الجسم
/// Latin-1 فيرمي على الأحرف العربية، بينما الخادم الحقيقي يرد
/// `application/json; charset=utf-8`.
http.Response _jsonResponse(Object body, int status) =>
    http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

List<int> _fakePdf(int bytes) =>
    List<int>.generate(bytes, (i) => i % 256);

void main() {
  group('ResearchPdfsApi — رفع ملفات PDF', () {
    test('upload يرسل multipart إلى المسار الإداري ويعيد بيانات الملف',
        () async {
      http.Request? captured;
      final progress = <double>[];
      final api = _apiWith(MockClient((request) async {
        captured = request;
        return _jsonResponse({
          'ok': true,
          'file': {
            'id': 'pdf_001',
            'filename': 'catalog-notes.pdf',
            'sizeBytes': 1234,
            'status': 'under_review',
            'uploadedAt': '2026-11-19T20:00:00.000Z',
          },
        }, 200);
      }));
      final file = await api.uploadPdf(
        filename: 'catalog-notes.pdf',
        bytes: _fakePdf(1234),
        onProgress: progress.add,
      );
      expect(file.id, 'pdf_001');
      expect(file.filename, 'catalog-notes.pdf');
      expect(file.sizeBytes, 1234);
      expect(file.status, ResearchPdfStatus.underReview);
      expect(file.status.label, 'قيد المراجعة');
      expect(file.sizeLabel, '1 KB');
      expect(file.uploadedAt, isNotNull);
      expect(captured, isNotNull);
      expect(captured!.url.host, 'zakhamhouse.shop');
      expect(captured!.url.path, '/api/admin/research/pdfs');
      expect(captured!.method, 'POST');
      // ترويسات الجلسة + CSRF، وبلا أي مفتاح خدمة.
      expect(captured!.headers['Cookie'], 'PHPSESSID=test-session');
      expect(captured!.headers['X-CSRF-Token'], 'test-csrf-token');
      expect(captured!.headers.containsKey('Authorization'), isFalse);
      // جسم multipart يحمل اسم الملف — يُقرأ Latin-1 لأن الجسم يحوي
      // بايتات PDF خاماً لا تصلح UTF-8.
      final bodyText = latin1.decode(captured!.bodyBytes);
      expect(bodyText, contains('filename="catalog-notes.pdf"'));
      // التقدم يصل إلى 1.
      expect(progress.isNotEmpty, isTrue);
      expect(progress.last, 1);
    });

    test('upload يرفض غير PDF قبل أي شبكة', () async {
      var calls = 0;
      final api = _apiWith(MockClient((_) async {
        calls++;
        return _jsonResponse({'ok': true, 'file': {}}, 200);
      }));
      await expectLater(
        api.uploadPdf(filename: 'notes.txt', bytes: _fakePdf(100)),
        throwsA(isA<FormatException>()),
      );
      expect(calls, 0);
    });

    test('upload يرفض ملفاً أكبر من 10MB قبل أي شبكة', () async {
      var calls = 0;
      final api = _apiWith(MockClient((_) async {
        calls++;
        return _jsonResponse({'ok': true, 'file': {}}, 200);
      }));
      await expectLater(
        api.uploadPdf(
          filename: 'big.pdf',
          bytes: _fakePdf(ResearchPdfsApi.maxFileBytes + 1),
        ),
        throwsA(isA<FormatException>()),
      );
      expect(calls, 0);
    });

    test('upload يرمي رسالة جلسة منتهية عند 401', () async {
      final api = _apiWith(MockClient(
        (_) async => _jsonResponse({'error': 'admin_auth_required'}, 401),
      ));
      await expectLater(
        api.uploadPdf(filename: 'a.pdf', bytes: _fakePdf(10)),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('انتهت جلسة الإدارة'),
        )),
      );
    });

    test('upload يرمي رسالة «غير منشورة» عند 404', () async {
      final api = _apiWith(MockClient(
        (_) async => _jsonResponse({'ok': false}, 404),
      ));
      await expectLater(
        api.uploadPdf(filename: 'a.pdf', bytes: _fakePdf(10)),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('غير منشورة'),
        )),
      );
    });

    test('listPdfs يعيد الملفات مع حالاتها وتسمياتها', () async {
      http.Request? captured;
      final api = _apiWith(MockClient((request) async {
        captured = request;
        return _jsonResponse({
          'ok': true,
          'files': [
            {
              'id': 'pdf_001',
              'filename': 'a.pdf',
              'sizeBytes': 2048,
              'status': 'under_review',
              'uploadedAt': '2026-11-19T20:00:00.000Z',
            },
            {
              'id': 'pdf_002',
              'filename': 'b.pdf',
              'sizeBytes': 3 * 1024 * 1024,
              'status': 'entered',
              'uploadedAt': '2026-11-18T10:00:00.000Z',
            },
            {
              'id': 'pdf_003',
              'filename': 'c.pdf',
              'sizeBytes': 512,
              'status': 'rejected',
            },
            {
              'id': 'pdf_004',
              'filename': 'd.pdf',
              'sizeBytes': 100,
              'status': 'something_new',
            },
          ],
        }, 200);
      }));
      final files = await api.listPdfs();
      expect(files, hasLength(4));
      expect(files[0].status, ResearchPdfStatus.underReview);
      expect(files[0].status.label, 'قيد المراجعة');
      expect(files[1].status, ResearchPdfStatus.entered);
      expect(files[1].status.label, 'أُدخل');
      expect(files[1].sizeLabel, '3.0 MB');
      expect(files[2].status, ResearchPdfStatus.rejected);
      expect(files[2].status.label, 'مرفوض');
      // حالة غير معروفة تُعامل كقيد المراجعة افتراضياً.
      expect(files[3].status, ResearchPdfStatus.underReview);
      expect(captured, isNotNull);
      expect(captured!.url.path, '/api/admin/research/pdfs');
      expect(captured!.method, 'GET');
      expect(captured!.headers['X-CSRF-Token'], 'test-csrf-token');
    });

    test('listPdfs يرمي رسالة «غير منشورة» عند 404', () async {
      final api = _apiWith(MockClient(
        (_) async => _jsonResponse({'ok': false}, 404),
      ));
      await expectLater(
        api.listPdfs(),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('غير منشورة'),
        )),
      );
    });
  });
}
