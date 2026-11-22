import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_of_zakham/widgets/app_update_dialog.dart';

/// اختبارات حوار «تحديث جديد» (app_update_dialog) — البناء 39.
///
/// يثبت الاختبار أن الحوار يعرض العنوان والنص المعتمدين حرفياً
/// وزرّي «تحديث الآن» و«لاحقاً»، وأن زر التحديث يفتح قناة
/// تليجرام بالضبط ويغلق الحوار، وأن «لاحقاً» يغلقه بلا أي فتح
/// رابط (والرفض لا يُحفظ — إثبات ظهوره مجدداً عند فتح ثانٍ في
/// اختبار التكامل app_update_chat_integration_test).

const _message =
    'يوجد تحديث جديد لتطبيق دار زخم — حدّث التطبيق للحصول على '
    'جميع المزايا الحديثة لدار زخم.';

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
    testWidgets('يعرض العنوان والنص المعتمدين والزرّين', (tester) async {
      final context = await _pumpHost(tester);
      final shown = showAppUpdateDialog(context);
      await tester.pumpAndSettle();
      expect(find.text('تحديث جديد'), findsOneWidget);
      expect(find.text(_message), findsOneWidget);
      expect(find.text('تحديث الآن'), findsOneWidget);
      expect(find.text('لاحقاً'), findsOneWidget);
      await tester.tap(find.text('لاحقاً'));
      await tester.pumpAndSettle();
      await shown;
    });

    testWidgets('زر «تحديث الآن» يفتح قناة تليجرام ويغلق الحوار',
        (tester) async {
      final context = await _pumpHost(tester);
      Uri? launched;
      final shown = showAppUpdateDialog(
        context,
        launch: (uri) async {
          launched = uri;
          return true;
        },
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('تحديث الآن'));
      await tester.pumpAndSettle();
      await shown;
      expect(launched.toString(), zakhamTelegramChannelUrl);
      expect(launched.toString(), 'https://t.me/zakhamapp');
      expect(find.text('تحديث جديد'), findsNothing);
    });

    testWidgets('«لاحقاً» يغلق الحوار بلا فتح رابط', (tester) async {
      final context = await _pumpHost(tester);
      var launched = false;
      final shown = showAppUpdateDialog(
        context,
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
      expect(find.text('تحديث جديد'), findsNothing);
    });
  });
}
