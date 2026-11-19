import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:house_of_zakham/pages/advisor_chat_page.dart';
import 'package:house_of_zakham/services/admin_api.dart';
import 'package:house_of_zakham/theme/app_theme.dart';

/// اختبارات واجهة محادثة المستشار (الإدارة).
///
/// لا استدعاء شبكة حقيقي إطلاقاً: الردود من `MockClient`.
/// ما يثبته الاختبار:
/// - تنبيه الإرشاد يبقى كما هو: الردود مسودات للمراجعة فقط — لا
///   اعتماد تركيبات ولا تغيير في المتجر ولا أسعار من المحادثة.
/// - رد خام فيه رموز Markdown يظهر نظيفاً بفقراته، بلا أي رمز خام.

http.Response _jsonResponse(Object body, int status) =>
    http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

Future<void> _pumpPage(
  WidgetTester tester,
  AdminApi api,
) async {
  await tester.pumpWidget(
    MaterialApp(theme: AppTheme.dark(), home: AdvisorChatPage(api: api)),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('advisor chat shows the drafts-only banner', (tester) async {
    final api = AdminApi(
      client: MockClient(
        (_) async => _jsonResponse({'ok': true, 'reply': 'رد.'}, 200),
      ),
    );
    await _pumpPage(tester, api);
    expect(find.text('ناقش المستشار'), findsOneWidget);
    expect(
      find.textContaining('الردود مسودات للمراجعة فقط'),
      findsOneWidget,
    );
    expect(
      find.textContaining('لا اعتماد تركيبات ولا تغيير في المتجر'),
      findsOneWidget,
    );
  });

  testWidgets(
      'advisor chat strips Markdown artifacts from a raw reply and keeps paragraphs',
      (tester) async {
    const rawReply = '## ميكسات الدار الحالية\n\n'
        '| الميكس | الحالة |\n|---|---|\n| **ZK-TRIAL-001** | research_draft |\n\n'
        'هذه مسودة **تجريبية** للمراجعة فقط.';
    const cleanReply = 'ميكسات الدار الحالية\n\nالميكس الحالة\n'
        'ZK-TRIAL-001 research_draft\n\nهذه مسودة تجريبية للمراجعة فقط.';
    final api = AdminApi(
      client: MockClient(
        (_) async => _jsonResponse({'ok': true, 'reply': rawReply}, 200),
      ),
    );
    await _pumpPage(tester, api);
    await tester.tap(find.text('ما ميكسات الدار الحالية؟'));
    await tester.pumpAndSettle();
    expect(find.text(cleanReply), findsOneWidget);
    expect(find.textContaining('|'), findsNothing);
    expect(find.textContaining('**'), findsNothing);
    expect(find.textContaining('#'), findsNothing);
    // تنبيه الإرشاد يبقى كما هو مع عرض الرد.
    expect(
      find.textContaining('الردود مسودات للمراجعة فقط'),
      findsOneWidget,
    );
  });
}
