import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:house_of_zakham/config/app_version.dart';
import 'package:house_of_zakham/services/push_service.dart';

/// اختبارات الأولوية 6 — سجل الإشعارات وربطها برقم الطلب.
///
/// تختبر المنطق الخالص فقط (بناء السجل من رسالة FCM وتسلسله)؛
/// الإرسال الفعلي من الخادم وFCM لا يُختبران هنا.

void main() {
  group('سجل الإشعارات — ربط رقم الطلب', () {
    test('يستخرج رقم الطلب ونوع الحدث من بيانات الرسالة', () {
      final entry = PushService.entryFromMessage(
        const RemoteMessage(
          data: {'orderRef': 'ZH-NOV-000002', 'event': 'payment_verified'},
          notification: RemoteNotification(
            title: 'تم تأكيد الدفع',
            body: 'تم تأكيد دفع طلبك.',
          ),
        ),
      );

      expect(entry.orderRef, 'ZH-NOV-000002');
      expect(entry.event, 'payment_verified');
      expect(entry.title, 'تم تأكيد الدفع');
      expect(entry.body, 'تم تأكيد دفع طلبك.');
    });

    test('رسالة بلا بيانات طلب: رقم طلب فارغ وعنوان افتراضي', () {
      final entry = PushService.entryFromMessage(
        const RemoteMessage(
          data: {},
          notification: RemoteNotification(body: 'وصل عطر جديد.'),
        ),
      );

      expect(entry.orderRef, '');
      expect(entry.event, '');
      expect(entry.title, 'دار زخم');
      expect(entry.body, 'وصل عطر جديد.');
    });

    test('تسلسل السجل ذهاباً وإياباً يحفظ كل الحقول', () {
      final entry = PushHistoryEntry(
        title: 'تم الشحن',
        body: 'طلبك في الطريق.',
        orderRef: 'ZH-NOV-000003',
        event: 'shipped',
        receivedAt: DateTime.fromMillisecondsSinceEpoch(1794800000000),
      );

      final restored = PushHistoryEntry.fromJson(entry.toJson());

      expect(restored.title, 'تم الشحن');
      expect(restored.body, 'طلبك في الطريق.');
      expect(restored.orderRef, 'ZH-NOV-000003');
      expect(restored.event, 'shipped');
      expect(
        restored.receivedAt.millisecondsSinceEpoch,
        1794800000000,
      );
    });

    test('سجل ناقص الحقول يُقرأ بقيم افتراضية ولا يكسر الصفحة', () {
      final restored = PushHistoryEntry.fromJson({});

      expect(restored.title, 'دار زخم');
      expect(restored.body, '');
      expect(restored.orderRef, '');
      expect(restored.event, '');
    });
  });

  group('بطاقات التحديث — زر «تحديث الآن»', () {
    PushHistoryEntry entry(String title) => PushHistoryEntry(
          title: title,
          body: 'يتوفر الآن تحديث جديد لتطبيق دار زَخَم للعطور.',
          receivedAt: DateTime.fromMillisecondsSinceEpoch(1794800000000),
        );

    test('عناوين التحديث المعتمدة (35 و36 و37) بطاقات تحديث', () {
      expect(entry('تحديث جديد – دار زَخَم للعطور (1.1.0)').isAppUpdate,
          isTrue);
      expect(entry('يوجد تحديث جديد لتطبيق دار زخم').isAppUpdate, isTrue);
    });

    test('إشعار طلب («تحديث للطلب») ليس بطاقة تحديث', () {
      final order = PushHistoryEntry(
        title: 'تحديث للطلب ZH-NOV-000002',
        body: 'تم شحن طلبك.',
        orderRef: 'ZH-NOV-000002',
        event: 'shipped',
        receivedAt: DateTime.fromMillisecondsSinceEpoch(1794800000000),
      );
      expect(order.isAppUpdate, isFalse);
    });

    test('إشعار عام ليس بطاقة تحديث', () {
      expect(entry('وصل عطر جديد').isAppUpdate, isFalse);
    });
  });

  group('منع تكرار إشعار التحديث — البناء 40', () {
    const updateTitle = 'تحديث جديد لتطبيق دار زخم';
    const updateBody =
        'يوجد تحديث جديد لتطبيق دار زخم — حدّث التطبيق للحصول على جميع المزايا الحديثة لدار زخم.';

    RemoteMessage _updateMessage() => const RemoteMessage(
          notification: RemoteNotification(
            title: updateTitle,
            body: updateBody,
          ),
        );

    PushHistoryEntry _seededUpdate({
      required int versionCode,
      required DateTime receivedAt,
      String body = updateBody,
    }) =>
        PushHistoryEntry(
          title: updateTitle,
          body: body,
          receivedAt: receivedAt,
          versionCode: versionCode,
        );

    Future<void> _seed(List<PushHistoryEntry> entries) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'zakham_notification_history':
            entries.map((e) => jsonEncode(e.toJson())).toList(),
      });
    }

    Future<List<PushHistoryEntry>> _history() =>
        PushService.instance.fetchHistory();

    test('تسلسل السجل يحفظ الإصدار المثبَّت وقت التسجيل', () {
      final entry = PushHistoryEntry(
        title: updateTitle,
        body: updateBody,
        receivedAt: DateTime.fromMillisecondsSinceEpoch(1794800000000),
        versionCode: 10,
      );
      final restored = PushHistoryEntry.fromJson(entry.toJson());
      expect(restored.versionCode, 10);
      // سجل قديم بلا الحقل يُقرأ صفراً ولا يكسر الصفحة.
      expect(PushHistoryEntry.fromJson({}).versionCode, 0);
    });

    test('إعادة إرسال إشعار التحديث نفسه بعد ساعات لا تُسجَّل', () async {
      await _seed([
        _seededUpdate(
          versionCode: AppVersion.versionCode,
          receivedAt: DateTime.now().subtract(const Duration(hours: 2)),
        ),
      ]);
      // الحالة الحية المبلَّغ عنها: 10:12 ثم 10:14 — ساعتان هنا
      // أبعد بكثير من نافذة الدقيقتين القديمة.
      await PushService.recordMessage(_updateMessage());
      final history = await _history();
      expect(history, hasLength(1));
      expect(history.first.title, updateTitle);
    });

    test('إعلان بناء أحدث بعد تثبيت الجديد يُسجَّل', () async {
      await _seed([
        _seededUpdate(
          versionCode: AppVersion.versionCode - 1,
          receivedAt: DateTime.now().subtract(const Duration(hours: 2)),
        ),
      ]);
      await PushService.recordMessage(_updateMessage());
      final history = await _history();
      expect(history, hasLength(2));
      expect(history.first.versionCode, AppVersion.versionCode);
    });

    test('إشعار تحديث بنص مختلف يُسجَّل', () async {
      await _seed([
        _seededUpdate(
          versionCode: AppVersion.versionCode,
          receivedAt: DateTime.now().subtract(const Duration(hours: 2)),
        ),
      ]);
      await PushService.recordMessage(
        const RemoteMessage(
          notification: RemoteNotification(
            title: updateTitle,
            body: 'إشعار تحديث مختلف تماماً.',
          ),
        ),
      );
      expect(await _history(), hasLength(2));
    });

    test('إشعار طلب مطابق بعد ساعات يُسجَّل — المنع الطويل للتحديث فقط',
        () async {
      const orderTitle = 'تحديث للطلب ZH-NOV-000002';
      await _seed([
        PushHistoryEntry(
          title: orderTitle,
          body: 'تم شحن طلبك.',
          orderRef: 'ZH-NOV-000002',
          event: 'shipped',
          receivedAt: DateTime.now().subtract(const Duration(hours: 2)),
          versionCode: AppVersion.versionCode,
        ),
      ]);
      await PushService.recordMessage(
        const RemoteMessage(
          data: {'orderRef': 'ZH-NOV-000002', 'event': 'shipped'},
          notification: RemoteNotification(
            title: orderTitle,
            body: 'تم شحن طلبك.',
          ),
        ),
      );
      expect(await _history(), hasLength(2));
    });
  });

  group('توجيه نقر الإشعار — البناء 40', () {
    const updateTitle = 'تحديث جديد لتطبيق دار زخم';
    const updateBody =
        'يوجد تحديث جديد لتطبيق دار زخم — حدّث التطبيق للحصول على جميع المزايا الحديثة لدار زخم.';

    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('نقر إشعار تحديث يرفع راية فتح صفحة الإشعارات', () async {
      await PushService.handleMessageOpened(
        const RemoteMessage(
          notification: RemoteNotification(
            title: updateTitle,
            body: updateBody,
          ),
        ),
      );
      expect(
        await PushService.instance.takePendingOpenNotifications(),
        isTrue,
      );
      // تُستهلك مرة واحدة.
      expect(
        await PushService.instance.takePendingOpenNotifications(),
        isFalse,
      );
      expect(await PushService.instance.takePendingOrderRef(), isNull);
    });

    test('نقر إشعار طلب يحفظ رقم الطلب فقط بلا راية إشعارات', () async {
      await PushService.handleMessageOpened(
        const RemoteMessage(
          data: {'orderRef': 'ZH-NOV-000002', 'event': 'shipped'},
          notification: RemoteNotification(
            title: 'تحديث للطلب ZH-NOV-000002',
            body: 'تم شحن طلبك.',
          ),
        ),
      );
      expect(
        await PushService.instance.takePendingOrderRef(),
        'ZH-NOV-000002',
      );
      expect(
        await PushService.instance.takePendingOpenNotifications(),
        isFalse,
      );
    });

    test('راية فتح الإشعارات تُستهلك مرة واحدة', () async {
      await PushService.setPendingOpenNotifications();
      expect(
        await PushService.instance.takePendingOpenNotifications(),
        isTrue,
      );
      expect(
        await PushService.instance.takePendingOpenNotifications(),
        isFalse,
      );
    });
  });
}
