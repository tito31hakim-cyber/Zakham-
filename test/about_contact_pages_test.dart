import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_of_zakham/pages/about_page.dart';
import 'package:house_of_zakham/pages/contact_page.dart';
import 'package:house_of_zakham/theme/app_theme.dart';

void main() {
  // الصفحتان قائمتا تمرير كسولتان (ListView) — سطح طويل في الاختبار
  // حتى تُبنى كل العناصر دفعة واحدة بلا تمرير.
  testWidgets('about page shows the house identity copy from the store',
      (tester) async {
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.dark(), home: const AboutPage()),
    );
    await tester.pumpAndSettle();
    expect(find.text('هوية زخم'), findsWidgets);
    expect(find.text('حضورٌ له أثره.'), findsOneWidget);
    expect(find.text('ما معنى زخم؟'), findsOneWidget);
    expect(find.text('لكلّ عطر شخصية'), findsOneWidget);
    expect(find.text('حضورٌ بلا مبالغة'), findsOneWidget);
    expect(find.text('التجربة امتداد للعطر'), findsOneWidget);
    expect(find.text('تواصل مع دار زخم'), findsOneWidget);
  });

  testWidgets('contact page shows the official channels from the store',
      (tester) async {
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.dark(), home: const ContactPage()),
    );
    await tester.pumpAndSettle();
    expect(find.text('تواصل مع زخم'), findsWidgets);
    expect(find.text('واتساب زخم'), findsOneWidget);
    expect(find.text('zakhamperfum@gmail.com'), findsOneWidget);
    expect(find.text('@zakham_house'), findsOneWidget);
    expect(find.text('كفر الشيخ، جمهورية مصر العربية'), findsOneWidget);
  });
}
