import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:house_of_zakham/pages/customer_chat_page.dart';
import 'package:house_of_zakham/services/customer_chat_api.dart';
import 'package:house_of_zakham/theme/app_theme.dart';

/// اختبارات واجهة محادثة العملاء المصغرة.
///
/// لا استدعاء شبكة حقيقي إطلاقاً: الردود من `MockClient`.
/// ما يثبته الاختبار: ظهور الاقتراحات وملاحظة النطاق (كتالوج فقط)،
/// وإرسال سؤال وظهور الرد، وظهور رسالة خطأ عربية عند فشل الإرسال.

http.Response _jsonResponse(Object body, int status) =>
    http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

Future<void> _pumpPage(
  WidgetTester tester,
  CustomerChatApi api,
) async {
  await tester.pumpWidget(
    MaterialApp(theme: AppTheme.dark(), home: CustomerChatPage(api: api)),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('customer chat shows suggestions and the catalog-only note',
      (tester) async {
    final api = CustomerChatApi(
      client: MockClient(
        (_) async => _jsonResponse({'ok': true, 'reply': 'رد.'}, 200),
      ),
    );
    await _pumpPage(tester, api);
    expect(find.text('مستشار العطور'), findsOneWidget);
    expect(find.text('أي عطر يشبهك؟'), findsOneWidget);
    expect(find.text('رشّح لي عطراً للسهرة'), findsOneWidget);
    expect(find.text('أي عطر فيه ورد وعنبر؟'), findsOneWidget);
    expect(find.text('ما العطور المتوفرة حالياً؟'), findsOneWidget);
    expect(
      find.textContaining('تشكيلة دار زخم فقط'),
      findsOneWidget,
    );
  });

  testWidgets('customer chat sends a suggestion and shows the reply',
      (tester) async {
    final api = CustomerChatApi(
      client: MockClient(
        (_) async => _jsonResponse({
          'ok': true,
          'reply': 'جرّب زخم رويال — ورد وعنبر وعود.',
        }, 200),
      ),
    );
    await _pumpPage(tester, api);
    await tester.tap(find.text('رشّح لي عطراً للسهرة'));
    await tester.pumpAndSettle();
    expect(find.text('رشّح لي عطراً للسهرة'), findsWidgets);
    expect(find.text('جرّب زخم رويال — ورد وعنبر وعود.'), findsOneWidget);
  });

  testWidgets('customer chat shows an Arabic error when sending fails',
      (tester) async {
    final api = CustomerChatApi(
      client: MockClient(
        (_) async => _jsonResponse(
          {'ok': false, 'message': 'تعذّر الوصول إلى خدمة الذكاء حالياً.'},
          502,
        ),
      ),
    );
    await _pumpPage(tester, api);
    await tester.tap(find.text('أي عطر فيه ورد وعنبر؟'));
    await tester.pumpAndSettle();
    expect(
      find.text('تعذّر الوصول إلى خدمة الذكاء حالياً.'),
      findsOneWidget,
    );
  });

  testWidgets(
      'customer chat strips Markdown artifacts from a raw reply and keeps paragraphs',
      (tester) async {
    // رد خام فيه جدول وعلامتا ** وعنوان # وأسطر متعددة — كما قد
    // يرد من أي مصدر — فيجب أن يظهر نظيفاً بفقراته، بلا أي رمز خام.
    const rawReply = '## ترشيحات الليلة\n\n'
        '| العطر | النوتة |\n|---|---|\n| **زخم رويال** | ورد وعنبر |\n\n'
        'جرّب **إلكسير القوة** — تابلي قوي.\n\nوهذا سطر أخير.';
    const cleanReply = 'ترشيحات الليلة\n\nالعطر النوتة\nزخم رويال ورد وعنبر\n\n'
        'جرّب إلكسير القوة — تابلي قوي.\n\nوهذا سطر أخير.';
    final api = CustomerChatApi(
      client: MockClient(
        (_) async => _jsonResponse({'ok': true, 'reply': rawReply}, 200),
      ),
    );
    await _pumpPage(tester, api);
    await tester.tap(find.text('رشّح لي عطراً للسهرة'));
    await tester.pumpAndSettle();
    expect(find.text(cleanReply), findsOneWidget);
    expect(find.textContaining('|'), findsNothing);
    expect(find.textContaining('**'), findsNothing);
    expect(find.textContaining('#'), findsNothing);
    // ملاحظة النطاق (كتالوج فقط) تبقى كما هي.
    expect(find.textContaining('تشكيلة دار زخم فقط'), findsOneWidget);
  });
}
