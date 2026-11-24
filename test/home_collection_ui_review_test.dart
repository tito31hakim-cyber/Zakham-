import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_of_zakham/data/featured_product.dart';
import 'package:house_of_zakham/models/product.dart';
import 'package:house_of_zakham/pages/home_page.dart';
import 'package:house_of_zakham/pages/product_page.dart';
import 'package:house_of_zakham/providers/cart_provider.dart';
import 'package:house_of_zakham/providers/theme_provider.dart';
import 'package:house_of_zakham/theme/app_theme.dart';
import 'package:house_of_zakham/widgets/common_widgets.dart';
import 'package:provider/provider.dart';

/// ملاحظات مراجعة الواجهة الفاتحة للرئيسية والتشكيلة وتفاصيل العطر
/// (بناء 41).

Product _productFromNotes(
  String id,
  String name,
  Map<String, dynamic> notes,
) =>
    Product.fromJson(<String, dynamic>{
      'product_id': id,
      'name': name,
      'prices': <String, dynamic>{'100': 500, '50': 350, '30': 250},
      'variants': <String, dynamic>{
        'presence': {
          'prices': {'100': 500, '50': 350, '30': 250}
        },
      },
      'visible': true,
      'stockStatus': 'available',
      'notes': notes,
    });

/// سلطان كما في `/api/storefront` الحي (نوتات نصية مفصولة بفواصل).
const _sultanPick = Product(
  id: 'sultan',
  name: 'سلطان',
  nameEn: 'Sultan VIP',
  price: 500,
  currency: 'EGP',
  size: '100 ml',
  category: 'premium',
  topNotes: <String>['الدافانا، البرغموت الإيطالي، الفلفل الوردي'],
  heartNotes: <String>['العود الكمبودي، العنبر الأبيض، إكليل الجبل'],
  baseNotes: <String>['الجلود، المسك، نجيل الهند، الباتشولي'],
  image: '',
  inStock: true,
  prices: <String, dynamic>{'30': 250, '50': 350, '100': 500},
);

Future<void> _pumpHome(
  WidgetTester tester, {
  Product hero = featuredProduct,
  Product pick = featuredProduct,
}) async {
  // نافذة 800 كاختبار إعادة الهيكلة: خط اختبار Ahem يجعل النص
  // العربي أعرض من الحقيقي، فتفيض العناوين عند 390.
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
              product: hero,
              pickProduct: pick,
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
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('Product.displayNotesLine — نوتات العطر في بطاقة التشكيلة', () {
    test('نوتات نصية مفصولة بفواصل: أول 3 نوتات مفردة', () {
      final royal = _productFromNotes('royal', 'زَخَم رويال', <String, dynamic>{
        'top': 'نفحات الكونياك المعتق، القرفة السيلانية الدافئة.',
        'middle': 'حبوب التونكا، أخشاب البلوط، لمسات اللوز المر.',
        'base': 'الفانيليا المدغشقرية، حلوى البرالين، خشب الصندل، العنبر الملكي.',
      });
      expect(
        royal.displayNotesLine,
        'نفحات الكونياك المعتق · القرفة السيلانية الدافئة · حبوب التونكا',
      );
    });

    test('نوتات قوائم: أول 3 من المقدمة ثم القلب', () {
      final layl = _productFromNotes('layl', 'ليل زخم', <String, dynamic>{
        'top': <String>['برغموت', 'فلفل وردي'],
        'middle': <String>['ورد طائفي', 'ياسمين'],
        'base': <String>['عود', 'مسك', 'عنبر'],
      });
      expect(layl.displayNotesLine, 'برغموت · فلفل وردي · ورد طائفي');
    });

    test('بلا نوتات موثقة: يعود إلى سطر التركيزات كما كان', () {
      final plain = _productFromNotes('plain', 'عطر بلا نوتات', <String, dynamic>{});
      expect(plain.displayNotesLine, 'حُضور');
    });
  });

  group('الرئيسية — ملاحظات المراجعة', () {
    testWidgets('«اختيار زخم» عطر مختلف عن عطر اليوم وبسعر «يبدأ من»',
        (tester) async {
      await _pumpHome(tester, hero: featuredProduct, pick: _sultanPick);

      // البطل رويال في البانر، والاختيار سلطان في البطاقة.
      expect(
        find.descendant(
          of: find.byType(HeroBanner),
          matching: find.text('زَخَم رويال'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(ProductTile),
          matching: find.text('سلطان'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(ProductTile),
          matching: find.text('يبدأ من 250 ج.م'),
        ),
        findsOneWidget,
      );
      // رابط «اكتشف ...» المكرر تحت البطاقة حُذف.
      expect(find.text('اكتشف زَخَم رويال'), findsNothing);
    });

    testWidgets('بطاقتا «اعثر على عطرك» مميزتان بوضوح', (tester) async {
      await _pumpHome(tester);

      expect(find.text('ترشيح سريع في 30 ثانية'), findsOneWidget);
      expect(find.text('تحليل بصمتك العطرية الكاملة'), findsOneWidget);
      expect(find.text('ثلاثة أسئلة فقط'), findsNothing);
      expect(find.text('4 خطوات لترشيح صادق'), findsNothing);
    });

    testWidgets('أوصاف أقسام زخم سطر واحد مكتمل بلا إنجليزي مكرر',
        (tester) async {
      await _pumpHome(tester);

      expect(find.text('صندوق الإهداء الملكي'), findsOneWidget);
      expect(find.text('تجربة التعتيق والرش'), findsOneWidget);
      expect(find.text('تغليف فاخر يليق بك'), findsOneWidget);
      expect(find.text('11 عطراً'), findsOneWidget);
      expect(find.textContaining('THE ZAKHAM RITUAL'), findsNothing);
      expect(find.textContaining('THE ZAKHAM FINISH'), findsNothing);
    });

    testWidgets('«استشارة عطرية» بعرض الصف الكامل', (tester) async {
      await _pumpHome(tester);

      final consultationTile = find.ancestor(
        of: find.text('استشارة عطرية'),
        matching: find.byType(InkWell),
      );
      expect(consultationTile, findsOneWidget);
      // عرض النافذة 800 − هامشا 20 = 760.
      expect(tester.getSize(consultationTile).width, 760);

      // بطاقتا الصف الأول جنباً إلى جنب بنفس الارتفاع.
      final cardsTile = find.ancestor(
        of: find.text('البطاقات العطرية'),
        matching: find.byType(InkWell),
      );
      final verifyTile = find.ancestor(
        of: find.text('تحقق من الأصالة'),
        matching: find.byType(InkWell),
      );
      expect(tester.getTopLeft(cardsTile).dy, tester.getTopLeft(verifyTile).dy);
      expect(tester.getSize(cardsTile).width, 375);
    });
  });

  group('صفحة العطر — الهرم العطري وأزرار الحجم', () {
    testWidgets('الهرم: النقطة يميناً ثم العنوان ثم المكونات',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: NoteCard(
                title: 'المقدمة',
                notes: const <String>[
                  'نفحات الكونياك المعتق',
                  'القرفة السيلانية الدافئة',
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('المقدمة:'), findsOneWidget);
      final dot = find.byIcon(Icons.circle);
      final title = find.text('المقدمة:');
      final notes = find.text('نفحات الكونياك المعتق، القرفة السيلانية الدافئة');
      expect(dot, findsOneWidget);
      expect(notes, findsOneWidget);
      // من اليمين لليسار: النقطة ثم العنوان ثم المكونات.
      expect(
        tester.getTopLeft(dot).dx,
        greaterThan(tester.getTopRight(title).dx),
      );
      expect(
        tester.getTopLeft(title).dx,
        greaterThan(tester.getTopRight(notes).dx),
      );
    });

    testWidgets('أزرار الحجم الثلاثة في صف أفقي واحد متساوٍ',
        (tester) async {
      tester.view.physicalSize = const Size(800, 6000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => CartProvider()),
          ],
          child: MaterialApp(
            theme: AppTheme.dark(),
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(
                body: ProductPage(
                  product: featuredProduct,
                  favorite: false,
                  onFavorite: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final sizeChips = find.ancestor(
        of: find.textContaining('مل •'),
        matching: find.byType(ChoiceChip),
      );
      expect(sizeChips, findsNWidgets(3));
      final tops = <double>{
        for (var i = 0; i < 3; i++) tester.getTopLeft(sizeChips.at(i)).dy,
      };
      // القمم الثلاث متساوية: صف واحد لا سطران.
      expect(tops.length, 1);
      final widths = <double>{
        for (var i = 0; i < 3; i++) tester.getSize(sizeChips.at(i)).width,
      };
      // عروض متساوية.
      expect(widths.length, 1);
    });
  });
}
