import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_of_zakham/widgets/app_update_dialog.dart';

/// اختبارات حوار «تحديث جديد» (app_update_dialog) — البناء 41.
///
/// إعادة تصميم الحوار على نموذج حوار تحديث Truecaller: حوار كبير
/// بخلفية داكنة بهوية زخم، فيه الشعار والعنوان ورقم الإصدار الجديد
/// وقسم «ما الجديد» والتحذير وزر ذهبي كبير «تحديث الآن».
///
/// يثبت الاختبار أن الحوار يعرض العنوان ورقم الإصدار والزرّين
/// والتحذير، وأن قسم «ما الجديد» يظهر فقط عند وجود ملاحظات فعلية
/// ويُخفى عند غيابها أو فراغها، وأن زر التحديث يفتح رابط الرسالة
/// المثبّتة في تليجرام بالضبط (https://t.me/zakhamapp/2) ويغلق
/// الحوار، وأن «لاحقاً» يغلقه بلا أي فتح رابط (والرفض لا يُحفظ —
/// إثبات ظهوره مجدداً عند فتح ثانٍ في اختبار التكامل
/// app_update_chat_integration_test).

const _warning =
    'أنت تستخدم إصداراً أقدم. حدّث إلى أحدث إصدار للاستمتاع بالمزايا الجديدة.';

Future<BuildContext> _pumpHost(WidgetTester tester) async {
  late BuildContext captured;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) {
          captured = context;
          return const Scaffold(body: SizedBox());
        },
      ),
    ),
  );
  await tester.pump();
  return captured;
}

void main() {
  group('showAppUpdateDialog — حوار التحديث', () {
    testWidgets('يعرض العنوان ورقم الإصدار والزرّين والتحذير',
        (tester) async {
      final context = await _pumpHost(tester);
      final shown = showAppUpdateDialog(context, versionName: '1.1.0');
      await tester.pumpAndSettle();
      expect(find.text('تحديث جديد!'), findsOneWidget);
      expect(find.text('دار زخم'), findsOneWidget);
      expect(find.text('الإصدار 1.1.0 متوفر'), findsOneWidget);
      expect(find.text('إصدار جديد'), findsOneWidget);
      expect(find.text(_warning), findsOneWidget);
      expect(find.text('تحديث الآن'), findsOneWidget);
      expect(find.text('لاحقاً'), findsOneWidget);
      // بلا ملاحظات: قسم «ما الجديد» مخفي كاملاً.
      expect(find.textContaining('ما الجديد'), findsNothing);
      await tester.tap(find.text('لاحقاً'));
      await tester.pumpAndSettle();
      await shown;
    });

    testWidgets('يعرض قائمة «ما الجديد» من الملاحظات', (tester) async {
      final context = await _pumpHost(tester);
      final shown = showAppUpdateDialog(
        context,
        versionName: '1.1.0',
        notes: const [
          'تصميم جديد لحوار التحديث',
          'زر التحديث يفتح الرسالة المثبّتة مباشرة',
        ],
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('ما الجديد'), findsOneWidget);
      expect(find.text('تصميم جديد لحوار التحديث'), findsOneWidget);
      expect(
        find.text('زر التحديث يفتح الرسالة المثبّتة مباشرة'),
        findsOneWidget,
      );
      await tester.tap(find.text('لاحقاً'));
      await tester.pumpAndSettle();
      await shown;
    });

    testWidgets('يخفي قسم «ما الجديد» عند فراغ الملاحظات',
        (tester) async {
      final context = await _pumpHost(tester);
      final shown = showAppUpdateDialog(
        context,
        versionName: '1.1.0',
        notes: const [],
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('ما الجديد'), findsNothing);
      await tester.tap(find.text('لاحقاً'));
      await tester.pumpAndSettle();
      await shown;
    });

    testWidgets('زر «تحديث الآن» يفتح رابط الرسالة المثبّتة ويغلق الحوار',
        (tester) async {
      final context = await _pumpHost(tester);
      Uri? launched;
      final shown = showAppUpdateDialog(
        context,
        versionName: '1.1.0',
        launch: (uri) async {
          launched = uri;
          return true;
        },
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('تحديث الآن'));
      await tester.pumpAndSettle();
      await shown;
      expect(launched.toString(), kZakhamUpdatePinnedLink);
      expect(launched.toString(), 'https://t.me/zakhamapp/2');
      expect(find.text('تحديث جديد!'), findsNothing);
    });

    testWidgets('«لاحقاً» يغلق الحوار بلا فتح رابط', (tester) async {
      final context = await _pumpHost(tester);
      var launched = false;
      final shown = showAppUpdateDialog(
        context,
        versionName: '1.1.0',
        launch: (_) async {
          launched = true;
          return true;
        },
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('لاحقاً'));
      await tester.pumpAndSettle();
      await shown;
      expect(launched, isFalse);
      expect(find.text('تحديث جديد!'), findsNothing);
    });
  });
}
