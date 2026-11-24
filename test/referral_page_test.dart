import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:house_of_zakham/pages/referral_page.dart';
import 'package:house_of_zakham/providers/customer_provider.dart';
import 'package:house_of_zakham/services/customer_auth.dart';
import 'package:house_of_zakham/theme/app_theme.dart';

/// اختبارات صفحة «ادعُ صديق» (البناء 40: عرض الكود الشخصي).
///
/// ما يثبته الاختبار: ظهور البرنامج كما حدده صاحب الدار (25 نقطة
/// للمدعو عند التسجيل و25 للداعي عند تسليم أول طلب له)، وجلب الكود
/// الشخصي من `GET /api/account/referral-code` وعرضه مع زر نسخ
/// ومشاركة رابط الدعوة، وحالة الضيف (دعوة لتسجيل الدخول بدل
/// الكود)، وحالة فشل الجلب (رسالة واضحة + إعادة محاولة).
/// لا استدعاء شبكة إطلاقاً — كل الردود من `MockClient`، وأزرار
/// المشاركة/النسخ لا تُضغط (تفتح ورقة مشاركة النظام أو الحافظة).

http.Response _jsonResponse(Object body, int status) =>
    http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

CustomerProvider _providerWith(MockClient client) =>
    CustomerProvider(auth: CustomerAuth(client: client));

Future<void> _pumpPage(WidgetTester tester, CustomerProvider provider) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<CustomerProvider>.value(
      value: provider,
      child: MaterialApp(theme: AppTheme.dark(), home: const ReferralPage()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('نص المشاركة يحمل رابط المتجر وقواعد البرنامج', () {
    final text = ReferralPage.shareText();
    expect(text, contains('https://zakhamhouse.shop'));
    expect(text, contains('25 نقطة'));
  });

  test('نص مشاركة الدعوة يحمل الكود والرابط', () {
    const referral = ReferralCode(
      code: 'ZK988B7A',
      link: 'https://zakhamhouse.shop/?ref=ZK988B7A',
    );
    final text = ReferralPage.referralShareText(referral);
    expect(text, contains('ZK988B7A'));
    expect(text, contains('https://zakhamhouse.shop/?ref=ZK988B7A'));
    expect(text, contains('25 نقطة'));
  });

  testWidgets('صفحة الدعوة تعرض البرنامج وزر مشاركة المتجر',
      (tester) async {
    await _pumpPage(
      tester,
      _providerWith(MockClient(
        (_) async => _jsonResponse({'ok': false}, 401),
      )),
    );

    expect(find.text('ادعُ صديق'), findsOneWidget);
    expect(find.text('ادعُ صديق واكسبا معاً'), findsOneWidget);
    expect(find.text('صديقك يكسب 25 نقطة عند التسجيل.'), findsOneWidget);
    expect(
      find.text('أنت تكسب 25 نقطة عند تسليم أول طلب له.'),
      findsOneWidget,
    );
    expect(find.text('شارك رابط المتجر'), findsOneWidget);
  });

  testWidgets('الضيف يرى دعوة لتسجيل الدخول بدل الكود', (tester) async {
    await _pumpPage(
      tester,
      _providerWith(MockClient(
        (_) async => _jsonResponse({'ok': false}, 401),
      )),
    );

    expect(
      find.text('سجّل الدخول لعرض كود الدعوة الخاص بك.'),
      findsOneWidget,
    );
    expect(find.text('تسجيل الدخول'), findsOneWidget);
    expect(find.text('ZK988B7A'), findsNothing);
  });

  testWidgets('العميل المسجَّل يرى كوده مع نسخ ومشاركة الرابط',
      (tester) async {
    await _pumpPage(
      tester,
      _providerWith(MockClient(
        (_) async => _jsonResponse({
          'ok': true,
          'code': 'ZK988B7A',
          'link': 'https://zakhamhouse.shop/?ref=ZK988B7A',
        }, 200),
      )),
    );

    expect(find.text('كود الدعوة الخاص بك'), findsOneWidget);
    expect(find.text('ZK988B7A'), findsOneWidget);
    expect(
      find.text('https://zakhamhouse.shop/?ref=ZK988B7A'),
      findsOneWidget,
    );
    expect(find.text('نسخ الكود'), findsOneWidget);
    expect(find.text('شارك رابط الدعوة'), findsOneWidget);
    expect(find.text('تسجيل الدخول'), findsNothing);
  });

  testWidgets('فشل الجلب يعرض رسالة واضحة مع إعادة محاولة',
      (tester) async {
    await _pumpPage(
      tester,
      _providerWith(MockClient(
        (_) async => _jsonResponse({'ok': false}, 500),
      )),
    );

    expect(find.textContaining('تعذر تنفيذ الطلب'), findsOneWidget);
    expect(find.text('إعادة المحاولة'), findsOneWidget);
    expect(find.text('ZK988B7A'), findsNothing);
  });
}
