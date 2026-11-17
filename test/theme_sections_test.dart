import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:house_of_zakham/app.dart';
import 'package:house_of_zakham/data/store_sections.dart';
import 'package:house_of_zakham/pages/sections_page.dart';
import 'package:house_of_zakham/providers/cart_provider.dart';
import 'package:house_of_zakham/providers/discount_provider.dart';
import 'package:house_of_zakham/providers/theme_provider.dart';

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 400);
  await tester.pumpAndSettle();
}

/// يعيد القائمة إلى الأعلى بسحبات تدريجية — لأن `scrollUntilVisible`
/// يتطلب أن يكون الهدف مبنياً أصلاً، والعناصر البعيدة عن العرض تُبنى
/// كسولاً (ListView). بعد إطالة قائمة الأقسام (مجموعة «خدمات الدار»)
/// صار العودة المباشرة لعنوان علوي تفشل بـ «No element».
Future<void> _scrollBackToTop(WidgetTester tester) async {
  final scrollable = find.byType(Scrollable).first;
  for (var i = 0; i < 6; i++) {
    if (find.text('تصفّح الدار').evaluate().isNotEmpty) break;
    await tester.drag(scrollable, const Offset(0, 500));
    await tester.pumpAndSettle();
  }
}

/// يضخ صفحة الأقسام مع تنقّل حقيقي لصفحة التفاصيل (كما يفعل
/// `StoreShell` في التطبيق).
Future<void> _pumpSections(WidgetTester tester) async {
  final navigatorKey = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: navigatorKey,
      home: SectionsPage(
        onSection: (id) {
          navigatorKey.currentState!.push(
            MaterialPageRoute(
              builder: (_) => SectionDetailPage(
                sectionId: id,
                onOpenCollection: () {},
              ),
            ),
          );
        },
        onOpenCollection: () {},
        onFragranceCards: () {},
        onVerify: () {},
        onConsultation: () {},
        onProduct: (_) {},
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('light theme: home shows the sections grid and toggle works',
      (tester) async {
    final theme = ThemeProvider();
    await theme.init();
    expect(theme.isLight, isFalse);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => CartProvider()),
          ChangeNotifierProvider.value(value: theme),
          ChangeNotifierProvider(create: (_) => DiscountProvider()),
        ],
        child: const ZakhamApp(),
      ),
    );
    await tester.pumpAndSettle();
    // زر الواجهة الفاتحة في الترويسة يبدّل الوضع.
    await tester.tap(find.byIcon(Icons.light_mode_outlined));
    await tester.pumpAndSettle();
    expect(theme.isLight, isTrue);
    expect(find.byIcon(Icons.dark_mode_outlined), findsOneWidget);
    // شبكة الأقسام في الرئيسية (تحتاج تمريراً لأنها أسفل الشاشة).
    await _scrollTo(tester, find.text('أقسام زخم'));
    expect(find.text('أقسام زخم'), findsOneWidget);
    expect(find.text('طقس زخم'), findsOneWidget);
    expect(find.text('باقات التوفير'), findsOneWidget);
  });

  testWidgets('sections page lists all five sections with real content',
      (tester) async {
    await _pumpSections(tester);
    expect(storeSections, hasLength(5));
    for (final section in storeSections) {
      await _scrollTo(tester, find.text(section.title));
      expect(find.text(section.title), findsOneWidget);
    }
    // تفاصيل طقس زخم بنصوص الموقع الحقيقية.
    await _scrollBackToTop(tester);
    await _scrollTo(tester, find.text('طقس زخم'));
    await tester.tap(find.text('طقس زخم'));
    await tester.pumpAndSettle();
    expect(find.text('اختر موضع الأثر'), findsOneWidget);
    expect(find.text('15 سم'), findsOneWidget);
    await _scrollTo(tester, find.text('دع العطر يستقر'));
    expect(find.text('دع العطر يستقر'), findsOneWidget);
  });

  testWidgets('bundles detail shows the three real bundles',
      (tester) async {
    await _pumpSections(tester);
    await _scrollTo(tester, find.text('باقات التوفير'));
    await tester.tap(find.text('باقات التوفير'));
    await tester.pumpAndSettle();
    expect(find.text('بوكس الاستكشاف'), findsOneWidget);
    expect(find.text('ثنائية التفرد'), findsOneWidget);
    await _scrollTo(tester, find.text('الثلاثية الملكية'));
    expect(find.text('الثلاثية الملكية'), findsOneWidget);
  });
}
