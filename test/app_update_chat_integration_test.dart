import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:house_of_zakham/app.dart';
import 'package:house_of_zakham/pages/advisor_chat_page.dart';
import 'package:house_of_zakham/pages/customer_chat_page.dart';
import 'package:house_of_zakham/providers/cart_provider.dart';
import 'package:house_of_zakham/providers/discount_provider.dart';
import 'package:house_of_zakham/providers/theme_provider.dart';
import 'package:house_of_zakham/services/admin_api.dart';
import 'package:house_of_zakham/services/app_update_api.dart';
import 'package:house_of_zakham/services/customer_chat_api.dart';

/// اختبارات تكامل فحص التحديث عند الفتح مع محادثتي الذكاء (البناء 35).
///
/// قاعدة المستخدم: البناء 35 يجب أن يكون بلا أي أخطاء في محادثتي
/// الذكاء معاً (العملاء والمستشار) ومع حوار التحديث. ما يثبته هذا
/// الملف: فحص التحديث عند الإطلاق لا يعطّل أياً من صفحتي المحادثة
/// ولا يكسر تدفق إرسالهما، والحوار يظهر بلا أخطاء، وفشل النقطة
/// (بلا اتصال أو 500) لا يؤثر على المحادثتين إطلاقاً.
///
/// لا استدعاء شبكة حقيقي إطلاقاً: كل الردود من `MockClient` —
/// بما فيها نقطة التحديث نفسها (تُحقن في StoreShell).

http.Response _jsonResponse(Object body, int status) =>
    http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

const _newerVersionBody = {
  'ok': true,
  'versionCode': 99,
  'versionName': '1.1.0',
  'downloadUrl': 'https://zakhamhouse.shop/downloads/zakhamhouse.apk',
};

AppUpdateApi _updateApiWith(MockClient client) =>
    AppUpdateApi(client: client);

CustomerChatApi _customerApi() => CustomerChatApi(
      client: MockClient(
        (_) async => _jsonResponse({
          'ok': true,
          'reply': 'جرّب زخم رويال — ورد وعنبر وعود.',
        }, 200),
      ),
    );

AdminApi _adminApi() => AdminApi(
      client: MockClient(
        (_) async => _jsonResponse({
          'ok': true,
          'reply': 'عطور المتجر المعتمدة: زخم رويال.',
        }, 200),
      ),
    );

Future<void> _pumpShell(
  WidgetTester tester,
  AppUpdateApi updateApi,
) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => DiscountProvider()),
      ],
      child: MaterialApp(home: StoreShell(appUpdateApi: updateApi)),
    ),
  );
  await tester.pumpAndSettle();
}

/// يفتح محادثة العملاء فوق الغلاف ويرسل اقتراحاً ويتحقق من الرد.
Future<void> _sendInCustomerChat(WidgetTester tester) async {
  final context = tester.element(find.byType(StoreShell));
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => CustomerChatPage(api: _customerApi()),
    ),
  );
  await tester.pumpAndSettle();
  expect(find.text('مساعد دار زخم'), findsOneWidget);
  await tester.tap(find.text('رشّح لي عطراً للسهرة'));
  await tester.pumpAndSettle();
  expect(find.text('جرّب زخم رويال — ورد وعنبر وعود.'), findsOneWidget);
  Navigator.of(tester.element(find.byType(CustomerChatPage))).pop();
  await tester.pumpAndSettle();
}

/// يفتح محادثة المستشار فوق الغلاف ويرسل سؤالاً ويتحقق من الرد
/// وبقاء تنبيه المسودات.
Future<void> _sendInAdvisorChat(WidgetTester tester) async {
  final context = tester.element(find.byType(StoreShell));
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => AdvisorChatPage(api: _adminApi()),
    ),
  );
  await tester.pumpAndSettle();
  expect(find.text('مساعد دار زخم'), findsOneWidget);
  await tester.tap(find.text('ما ميكسات الدار الحالية؟'));
  await tester.pumpAndSettle();
  expect(find.text('عطور المتجر المعتمدة: زخم رويال.'), findsOneWidget);
  expect(
    find.textContaining('الردود مسودات للمراجعة فقط'),
    findsOneWidget,
  );
  Navigator.of(tester.element(find.byType(AdvisorChatPage))).pop();
  await tester.pumpAndSettle();
}

void main() {
  // التخزين المحلي مشترك بين اختبارات الملف في العملية نفسها،
  // فيُصفَّر قبل كل اختبار حتى لا يؤثر اختبار سابق في لاحق.
  // (البوابة اليومية أُزيلت في البناء 39: الفحص يعمل عند كل
  // فتح، والرفض لا يُحفظ — فلا مفتاح فحص يومي يُصفَّر أصلاً.)
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('فحص التحديث عند الفتح + محادثتا الذكاء', () {
    testWidgets('فشل النقطة 500 لا يعطّل الإطلاق ولا المحادثتين',
        (tester) async {
      await _pumpShell(
        tester,
        _updateApiWith(
          MockClient((_) async => _jsonResponse({'ok': false}, 500)),
        ),
      );
      // الإطلاق سليم بلا حوار تحديث.
      expect(find.text('تحديث جديد!'), findsNothing);
      expect(find.text('السلة'), findsOneWidget);
      // تدفقا الإرسال في المحادثتين يعملان كما هما.
      await _sendInCustomerChat(tester);
      await _sendInAdvisorChat(tester);
    });

    testWidgets('انقطاع الاتصال لا يعطّل الإطلاق ولا المحادثتين',
        (tester) async {
      await _pumpShell(
        tester,
        _updateApiWith(
          MockClient((_) async => throw Exception('offline')),
        ),
      );
      expect(find.text('تحديث جديد!'), findsNothing);
      expect(find.text('السلة'), findsOneWidget);
      await _sendInCustomerChat(tester);
      await _sendInAdvisorChat(tester);
    });

    testWidgets('الحوار يظهر عند وجود أحدث ثم يعمل الإرسال في المحادثتين',
        (tester) async {
      await _pumpShell(
        tester,
        _updateApiWith(
          MockClient((_) async => _jsonResponse(_newerVersionBody, 200)),
        ),
      );
      // الحوار ظهر بلا أخطاء.
      expect(find.text('تحديث جديد!'), findsOneWidget);
      expect(find.text('تحديث الآن'), findsOneWidget);
      expect(find.text('لاحقاً'), findsOneWidget);
      // «لاحقاً» يغلقه، والتطبيق والمحادثتان يعملان بعده.
      await tester.tap(find.text('لاحقاً'));
      await tester.pumpAndSettle();
      expect(find.text('تحديث جديد!'), findsNothing);
      await _sendInCustomerChat(tester);
      await _sendInAdvisorChat(tester);
    });

    testWidgets(
        '«لاحقاً» لا تُحفظ والبوابة اليومية أُزيلت: الحوار يظهر مجدداً '
        'عند فتح ثانٍ في اليوم نفسه', (tester) async {
      final api = _updateApiWith(
        MockClient((_) async => _jsonResponse(_newerVersionBody, 200)),
      );
      await _pumpShell(tester, api);
      expect(find.text('تحديث جديد!'), findsOneWidget);
      await tester.tap(find.text('لاحقاً'));
      await tester.pumpAndSettle();
      expect(find.text('تحديث جديد!'), findsNothing);
      // فتح ثانٍ (غلاف جديد) في الجلسة نفسها: الفحص يعمل مجدداً
      // والحوار يظهر — بلا بوابة يومية تحجبه وبلا رفض محفوظ.
      // (ضخ شجرة مختلفة أولاً يلغي حالة الغلاف القديم، فالضخ
      // التالي إقلاع جديد حقيقي: initState يعمل من جديد. ضخ
      // الغلاف نفسه مرتين يعيد استخدام الحالة القديمة ولا يعيد
      // الفحص إطلاقاً.)
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pumpAndSettle();
      await _pumpShell(tester, api);
      expect(find.text('تحديث جديد!'), findsOneWidget);
      expect(find.text('تحديث الآن'), findsOneWidget);
      await tester.tap(find.text('لاحقاً'));
      await tester.pumpAndSettle();
      expect(find.text('تحديث جديد!'), findsNothing);
    });

    testWidgets('النقطة ترد الإصدار المثبَّت نفسه: بلا حوار ويعمل كل شيء',
        (tester) async {
      // لا إصدار أحدث إطلاقاً — التطبيق يعمل كاملاً (الكتالوج
      // والطلبات والمحادثتان) بلا أي حاجة لتحديث.
      await _pumpShell(
        tester,
        _updateApiWith(
          MockClient(
            (_) async => _jsonResponse({
              'ok': true,
              'versionCode': 9,
              'versionName': '1.1.0',
              'downloadUrl':
                  'https://zakhamhouse.shop/downloads/zakhamhouse.apk',
            }, 200),
          ),
        ),
      );
      expect(find.text('تحديث جديد!'), findsNothing);
      expect(find.text('السلة'), findsOneWidget);
      await _sendInCustomerChat(tester);
      await _sendInAdvisorChat(tester);
    });
  });
}
