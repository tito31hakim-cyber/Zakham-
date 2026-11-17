import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Background message handler — must be a top-level function.
@pragma('vm:entry-point')
Future<void> zakhamPushBackgroundHandler(RemoteMessage message) async {
  await PushService.showFromMessage(message);
}

/// Push notifications for House of Zakham (Firebase Cloud Messaging).
///
/// The client side is complete: permission request, FCM token, foreground
/// and background handling, topic subscriptions (offers / new arrivals /
/// order updates) and local display of incoming messages.
///
/// Activation needs the Firebase project files, which cannot be generated
/// from the repository (see README — الإشعارات الفورية):
///   * Android: `android/app/google-services.json`
///   * iOS: `ios/Runner/GoogleService-Info.plist`
/// Until those files exist, [init] fails safely, [available] stays false,
/// the app runs normally, and the settings page explains what is missing.
/// Sending messages also needs the server side (FCM sender on the store).
class PushService {
  PushService._();

  static final PushService instance = PushService._();

  /// FCM topics. Order updates are delivered to the `zakham_orders` topic
  /// only when the store server sends them (server-side step).
  static const String topicOrders = 'zakham_orders';
  static const String topicOffers = 'zakham_offers';
  static const String topicNewArrivals = 'zakham_new';

  static const String _channelId = 'zakham_default';
  static const String _channelName = 'تنبيهات دار زخم';

  static const Map<String, String> topicTitles = {
    topicOrders: 'تحديثات الطلبات',
    topicOffers: 'العروض والخصومات',
    topicNewArrivals: 'وصل حديثاً',
  };

  static const Map<String, String> _topicPrefKeys = {
    topicOrders: 'zakham_push_topic_orders',
    topicOffers: 'zakham_push_topic_offers',
    topicNewArrivals: 'zakham_push_topic_new',
  };

  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  bool _localReady = false;
  bool _initialized = false;

  /// True only when Firebase initialized successfully on this device.
  bool available = false;

  /// Human-readable reason when [available] is false.
  String unavailableReason = 'لم تُهيَّأ الإشعارات بعد.';

  /// This device's FCM token, when available.
  String? token;

  /// Initializes Firebase + local notifications. Never throws: on any
  /// failure the service reports unavailable and the app keeps working.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      await _initLocal();
      await Firebase.initializeApp();
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      await _local
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        unavailableReason = 'رفضت إذن الإشعارات من إعدادات الجهاز.';
        return;
      }
      FirebaseMessaging.onMessage.listen(_onForegroundMessage);
      FirebaseMessaging.onBackgroundMessage(zakhamPushBackgroundHandler);
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        token = newToken;
      });
      token = await messaging.getToken();
      available = true;
      await _applySavedTopics();
    } catch (e) {
      available = false;
      unavailableReason =
          'ملفات Firebase غير موجودة بعد — أضف google-services.json من مشروع Firebase الخاص بالدار لتفعيل الإشعارات.';
    }
  }

  Future<void> _initLocal() async {
    if (_localReady) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _local.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
    _localReady = true;
  }

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    await showFromMessage(message);
  }

  /// Displays a received FCM message as a local notification.
  /// Safe to call from the background isolate.
  static Future<void> showFromMessage(RemoteMessage message) async {
    final title = message.notification?.title ?? 'دار زخم';
    final body = message.notification?.body ?? '';
    if (body.isEmpty && message.data.isEmpty) return;
    await instance._showLocal(title: title, body: body);
  }

  /// Shows a local notification (used for incoming pushes and for the
  /// test button in the settings page).
  Future<void> showLocal({required String title, required String body}) =>
      _showLocal(title: title, body: body);

  Future<void> _showLocal({required String title, required String body}) async {
    await _initLocal();
    const android = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'تنبيهات دار زخم: الطلبات والعروض والوصلات الجديدة.',
      importance: Importance.high,
      priority: Priority.high,
    );
    const ios = DarwinNotificationDetails();
    await _local.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      const NotificationDetails(android: android, iOS: ios),
    );
  }

  /// Sends a test notification through the local channel.
  Future<void> sendTestNotification() => showLocal(
        title: 'دار زخم',
        body: 'الإشعارات تعمل — هذه رسالة اختبار من التطبيق.',
      );

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<bool> isTopicEnabled(String topic) async {
    final prefs = await _prefs;
    // Order updates default to on; marketing topics default to off.
    return prefs.getBool(_topicPrefKeys[topic] ?? topic) ??
        (topic == topicOrders);
  }

  /// Persists a topic choice and (un)subscribes this device when FCM is
  /// available. The choice is kept even before activation.
  Future<void> setTopicEnabled(String topic, bool enabled) async {
    final prefs = await _prefs;
    await prefs.setBool(_topicPrefKeys[topic] ?? topic, enabled);
    if (!available) return;
    try {
      if (enabled) {
        await FirebaseMessaging.instance.subscribeToTopic(topic);
      } else {
        await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
      }
    } catch (_) {
      // Subscription state is re-applied on the next launch.
    }
  }

  Future<void> _applySavedTopics() async {
    for (final topic in _topicPrefKeys.keys) {
      if (await isTopicEnabled(topic)) {
        try {
          await FirebaseMessaging.instance.subscribeToTopic(topic);
        } catch (_) {
          // Re-applied on the next launch.
        }
      }
    }
  }
}
