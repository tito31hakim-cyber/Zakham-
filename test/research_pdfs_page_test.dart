import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:house_of_zakham/pages/research_pdfs_page.dart';
import 'package:house_of_zakham/services/admin_api.dart';
import 'package:house_of_zakham/theme/app_theme.dart';

/// اختبارات واجهة رفع ملفات PDF لذاكرة البحث.
///
/// لا استدعاء شبكة حقيقي إطلاقاً: القائمة من `MockClient`.
/// ما يثبته الاختبار: ظهور الملفات مع حالاتها وتسمياتها العربية،
/// وظهور زر الرفع، وحالة الخطأ الودودة عند فشل التحميل.
/// (اختيار الملف نفسه عبر FilePicker لا يُختبر هنا — قناة منصة.)

http.Response _jsonResponse(Object body, int status) =>
    http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

Future<void> _pumpPage(WidgetTester tester, AdminApi api) async {
  await tester.pumpWidget(
    MaterialApp(theme: AppTheme.dark(), home: ResearchPdfsPage(api: api)),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('research pdfs page lists files with their statuses',
      (tester) async {
    final api = AdminApi(
      client: MockClient((request) async {
        expect(request.url.path, '/api/admin/research/pdfs');
        return _jsonResponse({
          'ok': true,
          'files': [
            {
              'id': 'pdf_001',
              'filename': 'ifra-notes.pdf',
              'sizeBytes': 2048,
              'status': 'under_review',
              'uploadedAt': '2026-11-19T20:00:00.000Z',
            },
            {
              'id': 'pdf_002',
              'filename': 'symrise-green.pdf',
              'sizeBytes': 3 * 1024 * 1024,
              'status': 'entered',
              'uploadedAt': '2026-11-18T10:00:00.000Z',
            },
            {
              'id': 'pdf_003',
              'filename': 'old-draft.pdf',
              'sizeBytes': 512,
              'status': 'rejected',
            },
          ],
        }, 200);
      }),
    );
    await _pumpPage(tester, api);
    expect(find.text('ملفات PDF للبحث'), findsOneWidget);
    expect(find.text('رفع ملف PDF'), findsOneWidget);
    expect(find.text('ifra-notes.pdf'), findsOneWidget);
    expect(find.text('symrise-green.pdf'), findsOneWidget);
    expect(find.text('old-draft.pdf'), findsOneWidget);
    expect(find.text('قيد المراجعة'), findsOneWidget);
    expect(find.text('أُدخل'), findsOneWidget);
    expect(find.text('مرفوض'), findsOneWidget);
    expect(
      find.textContaining('لا تدخل المعرفة إلا بعد مراجعة بشرية'),
      findsOneWidget,
    );
  });

  testWidgets('research pdfs page shows an empty state when no files',
      (tester) async {
    final api = AdminApi(
      client: MockClient(
        (_) async => _jsonResponse({'ok': true, 'files': []}, 200),
      ),
    );
    await _pumpPage(tester, api);
    expect(find.text('لا توجد ملفات مرفوعة بعد'), findsOneWidget);
    expect(find.text('رفع ملف PDF'), findsOneWidget);
  });

  testWidgets('research pdfs page shows a friendly error when loading fails',
      (tester) async {
    final api = AdminApi(
      client: MockClient(
        (_) async => _jsonResponse({'ok': false}, 500),
      ),
    );
    await _pumpPage(tester, api);
    expect(find.text('تعذّر تحميل قائمة الملفات'), findsOneWidget);
    expect(find.text('إعادة المحاولة'), findsOneWidget);
  });
}
