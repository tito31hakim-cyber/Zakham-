import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:house_of_zakham/app.dart';
import 'package:house_of_zakham/providers/cart_provider.dart';
import 'package:house_of_zakham/providers/discount_provider.dart';
import 'package:house_of_zakham/providers/theme_provider.dart';

/// تشكيلة محفوظة محلياً: عطران ظاهران فقط — بلا المنتج المميز، حتى
/// لا ينجح الاختبار من ذاكرة الجلسة الافتتاحية وحدها.
const String _cachedStorefront = '''
{"products": [
  {"product_id": "layl", "name": "ليل زخم", "prices": {"100": 500},
   "variants": {}, "visible": true, "stockStatus": "available",
   "notes": {"top": ["ورد"], "middle": ["عود"], "base": ["مسك"]},
   "tags": ["gender:unisex"], "season": "كل الفصول", "occasion": "يومي ومسائي"},
  {"product_id": "fahd", "name": "فهد الأساطير", "prices": {"100": 500},
   "variants": {}, "visible": true, "stockStatus": "available",
   "notes": {"top": ["زعفران"], "middle": ["عود"], "base": ["عنبر"]},
   "tags": ["gender:unisex"], "season": "كل الفصول", "occasion": "مسائي"}
]}
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'restored favorites show on the favorites tab without opening the collection',
    (tester) async {
      // محاكاة إعادة التشغيل: معرّفات محفوظة + كتالوج محفوظ،
      // وبلا أي منتج فُتح أو فُضّل في هذه الجلسة.
      SharedPreferences.setMockInitialValues(<String, Object>{
        'zakham_favorites': <String>['layl', 'fahd'],
        'zakham_storefront_cache_v1': _cachedStorefront,
        'zakham_storefront_cache_time_v1': 0,
      });
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => CartProvider()),
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
            ChangeNotifierProvider(create: (_) => DiscountProvider()),
          ],
          child: const ZakhamApp(),
        ),
      );
      await tester.pumpAndSettle();
      // الانتقال إلى تبويب المفضلة مباشرة (بلا فتح التشكيلة أولاً).
      await tester.tap(find.text('المفضلة'));
      await tester.pumpAndSettle();
      expect(find.text('عطورك المحفوظة'), findsOneWidget);
      expect(find.text('لم تحفظ أي عطر بعد'), findsNothing);
      expect(find.text('ليل زخم'), findsOneWidget);
      expect(find.text('فهد الأساطير'), findsOneWidget);
    },
  );
}
