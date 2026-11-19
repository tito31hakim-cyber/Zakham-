import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_of_zakham/services/app_update_api.dart';
import 'package:house_of_zakham/widgets/app_update_dialog.dart';

/// اختبارات حوار «يوجد تحديث جديد» (app_update_dialog) — البناء 35.
///
/// يثبت الاختبار أن الحوار يعرض اسم الإصدار وزرّي «تثبيت التحديث»
/// و«لاحقاً»، وأن زر التثبيت يفتح رابط التحميل بالضبط ويغلق
/// الحوار، وأن «لاحقاً» يغلقه بلا أي فتح رابط.

const _info = AppUpdateInfo(
  versionCode: 5,
  versionName: '1.1.0',
  downloadUrl: 'https://zakhamhouse.shop/downloads/zakhamhouse.apk',
);

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
    testWidgets('يعرض اسم الإصدار والزرّين', (tester) async {
      final context = await _pumpHost(tester);
      final shown = showAppUpdateDialog(context, _info);
      await tester.pumpAndSettle();
      expect(find.text('يوجد تحديث جديد'), findsOneWidget);
      expect(find.textContaining('1.1.0'), findsOneWidget);
      expect(find.text('تثبيت التحديث'), findsOneWidget);
      expect(find.text('لاحقاً'), findsOneWidget);
      await tester.tap(find.text('لاحقاً'));
      await tester.pumpAndSettle();
      await shown;
    });

    testWidgets('زر التثبيت يفتح رابط التحميل ويغلق الحوار', (tester) async {
      final context = await _pumpHost(tester);
      Uri? launched;
      final shown = showAppUpdateDialog(
        context,
        _info,
        launch: (uri) async {
          launched = uri;
          return true;
        },
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('تثبيت التحديث'));
      await tester.pumpAndSettle();
      await shown;
      expect(
        launched.toString(),
        'https://zakhamhouse.shop/downloads/zakhamhouse.apk',
      );
      expect(find.text('يوجد تحديث جديد'), findsNothing);
    });

    testWidgets('«لاحقاً» يغلق الحوار بلا فتح رابط', (tester) async {
      final context = await _pumpHost(tester);
      var launched = false;
      final shown = showAppUpdateDialog(
        context,
        _info,
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
      expect(find.text('يوجد تحديث جديد'), findsNothing);
    });
  });
}
