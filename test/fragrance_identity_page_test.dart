import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_of_zakham/data/fragrance_cards.dart';
import 'package:house_of_zakham/models/product.dart';
import 'package:house_of_zakham/pages/fragrance_identity_page.dart';
import 'package:house_of_zakham/providers/cart_provider.dart';
import 'package:house_of_zakham/theme/app_theme.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('تدفق بصمة زخم: 4 خطوات ثم النتيجة مع قسم الثقة',
      (tester) async {
    final products = [
      Product(
        id: 'royal',
        name: 'زخم رويال',
        price: 500.0,
        currency: 'EGP',
        size: '100 ml',
        category: 'عطور',
        topNotes: const ['برغموت'],
        heartNotes: const ['ورد'],
        baseNotes: const ['عود'],
        image: 'assets/products/royal-official.webp',
        inStock: true,
        description: 'هوية ملكية.',
        season: 'شتوي',
        occasion: 'formal',
        tags: const ['gender:male'],
        variants: const {
          'presence': {
            'prices': {'30': 250.0, '50': 350.0, '100': 500.0},
          },
          'nuclear': {
            'prices': {'50': 650.0, '100': 950.0},
          },
        },
      ),
      Product(
        id: 'aurora',
        name: 'أورورا',
        price: 500.0,
        currency: 'EGP',
        size: '100 ml',
        category: 'عطور',
        topNotes: const ['ليمون'],
        heartNotes: const ['ياسمين'],
        baseNotes: const ['مسك'],
        image: 'assets/products/aurora.webp',
        inStock: true,
        description: 'انتعاش صباحي.',
        season: 'صيفي',
        occasion: 'fresh',
        tags: const ['gender:female'],
        variants: const {
          'presence': {
            'prices': {'30': 250.0, '50': 350.0, '100': 500.0},
          },
        },
      ),
    ];
    final cards = products
        .map(
          (p) => FragranceCard(
            extra: FragranceCardExtra(
              code: '',
              tag: '',
              quote: 'ملكي.',
              top: '',
              heart: '',
              base: '',
              stats: const [96, 92, 95, 20, 98],
              wizardCategory: p.occasion,
              wizardType: p.id == 'royal' ? 'wood' : 'floral',
            ),
            product: p,
          ),
        )
        .toList();

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => CartProvider(),
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: FragranceIdentityPage(
              initialCards: cards,
              onProduct: (_) {},
              onConsultation: () {},
              onOpenChat: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // الخطوة 1: المناسبة — الخيار الأول (رسمية).
    expect(
      find.text('ما هي طبيعة المناسبة أو الأجواء المراد ارتداء العطر فيها؟'),
      findsOneWidget,
    );
    await tester.tap(find.byType(OutlinedButton).first);
    await tester.pumpAndSettle();

    // الخطوة 2: الطابع — الخيار الأول (خشبي).
    expect(
      find.text('ما هو طابع الروائح والأكوردات التي تميل إليها حواسك؟'),
      findsOneWidget,
    );
    await tester.tap(find.byType(OutlinedButton).first);
    await tester.pumpAndSettle();

    // الخطوة 3: التركيز.
    expect(find.text('ما التركيز الذي تفضله؟'), findsOneWidget);
    await tester.tap(find.byType(OutlinedButton).first);
    await tester.pumpAndSettle();

    // الخطوة 4: الحجم.
    expect(find.text('ما الحجم المناسب لك؟'), findsOneWidget);
    await tester.tap(find.byType(OutlinedButton).first);
    await tester.pumpAndSettle();

    // شاشة النتيجة: ملف الهوية + ترشيح رويال أولاً + قسم الثقة.
    expect(find.text('بصمتك العطرية'), findsOneWidget);
    expect(find.text('زخم رويال'), findsWidgets);
    // قسم الثقة أسفل البطاقات — يُمرَّر إليه داخل القائمة أولاً.
    await tester.scrollUntilVisible(find.text('ثقة وشفافية'), 200);
    await tester.pumpAndSettle();
    expect(find.text('ثقة وشفافية'), findsOneWidget);
    expect(
      find.text('الشحن 120 ج.م لجميع المحافظات خلال 4–7 أيام عمل.'),
      findsOneWidget,
    );
    expect(find.text('أضف للسلة'), findsWidgets);
  });
}
