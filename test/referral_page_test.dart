import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_of_zakham/pages/referral_page.dart';
import 'package:house_of_zakham/theme/app_theme.dart';

/// اختبارات صفحة «ادعُ صديق».
///
/// ما يثبته الاختبار: ظهور البرنامج كما حدده صاحب الدار (25 نقطة
/// للمدعو عند التسجيل و25 للداعي عند تسليم أول طلب له)، وظهور
/// ملاحظة الكود الشخصي (في حساب المتجر على الموقع)، ونص المشاركة
/// يحمل رابط المتجر وقواعد البرنامج. لا استدعاء شبكة إطلاقاً — زر
/// المشاركة نفسه لا يُضغط في الاختبار (يفتح ورقة مشاركة النظام).

void main() {
  test('نص المشاركة يحمل رابط المتجر وقواعد البرنامج', () {
    final text = ReferralPage.shareText();
    expect(text, contains('https://zakhamhouse.shop'));
    expect(text, contains('25 نقطة'));
  });

  testWidgets('صفحة الدعوة تعرض البرنامج وملاحظة الكود وزر المشاركة',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.dark(), home: const ReferralPage()),
    );
    await tester.pumpAndSettle();

    expect(find.text('ادعُ صديق'), findsOneWidget);
    expect(find.text('ادعُ صديق واكسبا معاً'), findsOneWidget);
    expect(find.text('صديقك يكسب 25 نقطة عند التسجيل.'), findsOneWidget);
    expect(
      find.text('أنت تكسب 25 نقطة عند تسليم أول طلب له.'),
      findsOneWidget,
    );
    expect(
      find.textContaining('كود الدعوة الخاص بك يظهر في حسابك على متجر زخم'),
      findsOneWidget,
    );
    expect(find.text('شارك رابط المتجر'), findsOneWidget);
  });
}
