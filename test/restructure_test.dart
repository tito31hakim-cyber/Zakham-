import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:house_of_zakham/data/featured_product.dart';
import 'package:house_of_zakham/pages/account_page.dart';
import 'package:house_of_zakham/pages/home_page.dart';
import 'package:house_of_zakham/providers/customer_provider.dart';
import 'package:house_of_zakham/providers/theme_provider.dart';
import 'package:house_of_zakham/services/customer_auth.dart';
import 'package:house_of_zakham/theme/app_theme.dart';
import 'package:house_of_zakham/widgets/common_widgets.dart';
import 'package:house_of_zakham/widgets/occasions_section.dart';

/// عميل مسجّل وهمي لاختبار مجموعات صفحة الحساب — بلا أي شبكة:
/// الطلبات وتاريخ الميلاد يُحمَّلان كعمليتين فارغتين.
class _FakeMemberProvider extends CustomerProvider {
  _FakeMemberProvider() : super();

  @override
  Customer? get customer => const Customer(
        openId: 'test-open',
        displayName: 'عميل اختبار',
        email: 'test@zakham.test',
        phone: '01000000000',
        phoneVerified: true,
        pointsBalance: 120,
        birthday: '',
      );

  @override
  Future<void> refreshOrders() async {}

  @override
  Future<void> refreshBirthday() async {}
}

Future<void> _pumpHome(WidgetTester tester) async {
  // نافذة طويلة حتى تُبنى كل أقسام الرئيسية دفعة واحدة دون تمرير.
  tester.view.physicalSize = const Size(800, 6000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: MaterialApp(
        theme: AppTheme.dark(),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: HomePage(
              product: featuredProduct,
              onProduct: (_) {},
              onQuiz: () {},
              onFragranceIdentity: () {},
              favorite: false,
              onFavorite: () {},
              onSection: (_) {},
              onOpenSections: () {},
              onFragranceCards: () {},
              onVerify: () {},
              onConsultation: () {},
              isDailyPerfume: true,
              showEmptyCartNudge: true,
              onBrowseCollection: () {},
              onDismissEmptyCartNudge: () {},
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpAccount(
  WidgetTester tester,
  CustomerProvider customerProvider,
) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  // نافذة طويلة حتى تُبنى كل مجموعات الحساب دفعة واحدة دون تمرير.
  tester.view.physicalSize = const Size(800, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<CustomerProvider>.value(value: customerProvider),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: MaterialApp(
        theme: AppTheme.dark(),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: AccountPage(onOpenSections: () {})),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('إعادة هيكلة الرئيسية — هوية المتجر أولاً', () {
    testWidgets('ترويسة الهوية والترتيب الموحّد للأقسام', (tester) async {
      await _pumpHome(tester);

      // هوية المتجر: علامة الدار + الاسم + شارة الرسمية + السطر التعريفي.
      expect(find.byType(StoreIdentityCard), findsOneWidget);
      expect(find.text('متجر دار زخم'), findsOneWidget);
      expect(find.text('المتجر الإلكتروني الرسمي'), findsOneWidget);
      expect(
        find.text(
          'متجر زخم الإلكتروني — التشكيلة الكاملة، حسابك، طلباتك، وتتبع الشحنات.',
        ),
        findsOneWidget,
      );

      // كل الأقسام موجودة — بلا حذف لأي ميزة.
      expect(find.text('اعثر على عطرك'), findsOneWidget);
      expect(find.text('عطر اليوم'), findsOneWidget);
      expect(find.text('أقسام زخم'), findsOneWidget);
      expect(find.text('خدمات الدار'), findsOneWidget);
      expect(find.text('البطاقات العطرية'), findsOneWidget);
      expect(find.text('تحقق من الأصالة'), findsOneWidget);
      expect(find.text('استشارة عطرية'), findsOneWidget);
      expect(find.byType(OccasionsSection), findsOneWidget);
      expect(find.text('اختيار زخم'), findsOneWidget);
      expect(find.text('تجربة تليق بك'), findsOneWidget);
      expect(find.text('سلتك فاضية'), findsOneWidget);

      // الترتيب العمودي: الهوية، ثم شارة عطر اليوم على البطاقة
      // العلوية، ثم الاختبار، ثم الأقسام، ثم «اختيار زخم»، ثم
      // الخدمات، ثم المناسبات، ثم «تجربة تليق بك» (ترتيب 2026-11-21).
      double top(String text) =>
          tester.getTopLeft(find.text(text)).dy;
      expect(top('متجر دار زخم'), lessThan(top('عطر اليوم')));
      expect(top('عطر اليوم'), lessThan(top('اعثر على عطرك')));
      expect(top('عطر اليوم'), lessThan(top('أقسام زخم')));
      expect(top('أقسام زخم'), lessThan(top('اختيار زخم')));
      expect(top('اختيار زخم'), lessThan(top('خدمات الدار')));
      expect(top('خدمات الدار'), lessThan(top('تجربة تليق بك')));
    });

    testWidgets('عنوان القسم يميناً وزر الإجراء يساراً (عربي)',
        (tester) async {
      await _pumpHome(tester);
      final titleX = tester.getCenter(find.text('أقسام زخم')).dx;
      final actionX = tester.getCenter(find.text('عرض الكل')).dx;
      expect(titleX, greaterThan(actionX));
    });
  });

  group('إعادة هيكلة الحساب — مجموعات بعناوين', () {
    testWidgets('الضيف: مجموعتان بلا مجموعة الولاء وبلا التذكيرات',
        (tester) async {
      await _pumpAccount(tester, CustomerProvider());
      expect(find.text('حسابي'), findsOneWidget);
      expect(find.text('الولاء والمكافآت'), findsNothing);
      expect(find.text('ادعُ صديق'), findsNothing);
      // «التذكيرات» انتقلت إلى صفحة «الإشعارات» المتكاملة (2026-11-21)
      // فلا تظهر في «حسابي» لا للضيف ولا للعضو.
      expect(find.text('التذكيرات'), findsNothing);
      expect(find.text('تذكيرات السلة والطلبات'), findsNothing);
      expect(find.text('روابط سريعة'), findsOneWidget);
      expect(find.text('الإعدادات'), findsOneWidget);
      expect(find.text('أهلاً بك في زخم'), findsOneWidget);
      expect(find.text('تسجيل الدخول'), findsOneWidget);
      expect(find.text('الواجهة الفاتحة'), findsOneWidget);
      expect(find.text('أقسام زخم'), findsOneWidget);
      expect(find.text('دخول الإدارة'), findsOneWidget);
      // مراجعة «حسابي» (بناء 41): بطاقة «سلة المشتريات» المكررة مع
      // تبويب «السلة» حُذفت بلا بديل — لا شاشة طلبات منفصلة تُربط بها.
      expect(find.text('سلة المشتريات'), findsNothing);
      // الفوتر: اسم الدار مرة واحدة، وسطر الحقوق مختصر بلا تكرار.
      expect(find.text('دار زخم للعطور • مصر'), findsOneWidget);
      expect(find.text('الإصدار 1.1.0'), findsOneWidget);
      expect(find.text('© 2026 جميع الحقوق محفوظة'), findsOneWidget);
      expect(
        find.text('© 2026 دار زخم للعطور — جميع الحقوق محفوظة'),
        findsNothing,
      );
      // «استشاراتي»: زر الحجز في أسفل البطاقة بعرض كامل.
      expect(find.text('احجز استشارة'), findsOneWidget);
      expect(
        tester
            .getSize(find.widgetWithText(FilledButton, 'احجز استشارة'))
            .width,
        728,
      );
    });

    testWidgets('العضو: الولاء وعيد الميلاد في مجموعة المكافآت',
        (tester) async {
      await _pumpAccount(tester, _FakeMemberProvider());
      expect(find.text('الولاء والمكافآت'), findsOneWidget);
      expect(find.text('نقاط الولاء'), findsOneWidget);
      expect(
        find.text('نقاط الولاء: 120 نقطة — تساوي 120 جنيه خصم'),
        findsOneWidget,
      );
      expect(find.text('هدية عيد ميلادك'), findsOneWidget);
      expect(find.text('ادعُ صديق'), findsOneWidget);
      expect(find.text('عميل اختبار'), findsOneWidget);
      expect(find.text('طلباتي'), findsOneWidget);
      expect(find.text('عناويني المحفوظة'), findsOneWidget);
      expect(find.text('تسجيل الخروج'), findsOneWidget);
      expect(find.text('التذكيرات'), findsNothing);
      expect(find.text('الإعدادات'), findsOneWidget);
    });
  });
}
