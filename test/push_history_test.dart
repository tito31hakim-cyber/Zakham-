import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
