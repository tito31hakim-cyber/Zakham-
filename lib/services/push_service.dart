import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Background message handler — must be a top-level function.
@pragma('vm:entry-point')
Future<void> zakhamPushBackgroundHandler(RemoteMessage message) async {
  await PushService.showFromMessage(message);
}

/// One received notification, as kept in the in-app history.
class PushHistoryEntry {
  const PushHistoryEntry({
    required this.title,
    required this.body,
    this.orderRef = '',
    this.event = '',
    required this.receivedAt,
  });

  final String title;
  final String body;

  /// رقم الطلب المرتبط بالإشعار ('' إن لم يكن إشعار طلب).
  final String orderRef;

  /// نوع الحدث كما أرسله الخادم (مثل order_created / payment_verified /
  /// shipped / delivered)، أو '' للإشعارات العامة.
  final String event;
  final DateTime receivedAt;

  /// بطاقة تحديث تطبيق: إشعارات التحديث التي يرسلها المتجر تحمل
  /// العنوان المعتمد «تحديث جديد …» (بناء 35 و36 و37 كلها به)،
  /// فتظهر في البطاقة زر «تحديث الآن». إشعارات الطلب تحمل
  /// «تحديث للطلب …» فلا تطابق هذا الفحص.
  bool get isAppUpdate => title.contains('تحديث جديد');

  Map<String, dynamic> toJson() => <String, dynamic>{
        'title': title,
        'body': body,
        'orderRef': orderRef,
        'event': event,
        'receivedAt': receivedAt.millisecondsSinceEpoch,
      };

  factory PushHistoryEntry.fromJson(Map<String, dynamic> json) =>
      PushHistoryEntry(
        title: '${json['title'] ?? 'دار زخم'}',
        body: '${json['body'] ?? ''}',
        orderRef: '${json['orderRef'] ?? ''}',
        event: '${json['event'] ?? ''}',
        receivedAt: DateTime.fromMillisecondsSinceEpoch(
          (json['receivedAt'] as num?)?.toInt() ?? 0,
        ),
      );
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

  /// سجل الإشعارات داخل التطبيق (آخر 50 إشعاراً، الأحدث أولاً).
  static const String _historyKey = 'zakham_notification_history';
  static const int _maxHistory = 50;

  /// رقم طلب بانتظار فتحه: يُحفظ عند نقر إشعار أو فتح التطبيق من
  /// إشعار، وتقرؤه صفحة الإشعارات لتعرض زر «عرض طلباتي».
  static const String _pendingOrderKey = 'zakham_pending_order_ref';

  /// يبني سجلاً من رسالة FCM — الربط برقم الطلب يأتي من حقل
  /// data.orderRef الذي يرسله الخادم مع إشعارات أحداث الطلب.
  static PushHistoryEntry entryFromMessage(RemoteMessage message) =>
      PushHistoryEntry(
        title: message.notification?.title ?? 'دار زخم',
        body: message.notification?.body ?? '',
        orderRef: '${message.data['orderRef'] ?? ''}'.trim(),
        event: '${message.data['event'] ?? ''}'.trim(),
        receivedAt: DateTime.now(),
      );

  /// يحفظ رسالة في سجل الإشعارات (الأحدث أولاً، بحد أقصى 50).
  /// لا يرمي أبداً — فشل الحفظ لا يمنع عرض الإشعار نفسه.
  static Future<void> recordMessage(RemoteMessage message) async {
    try {
      final entry = entryFromMessage(message);
      if (entry.body.isEmpty && entry.orderRef.isEmpty) return;
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_historyKey) ?? <String>[];
      final entries = <PushHistoryEntry>[];
      for (final item in raw) {
        try {
          entries.add(
            PushHistoryEntry.fromJson(
              jsonDecode(item) as Map<String, dynamic>,
            ),
          );
        } catch (_) {
          // سجل تالف يُتجاهل.
        }
        if (entries.length >= _maxHistory) break;
      }
      // نفس الإشعار قد يُسجَّل مرتين (معالج الخلفية ثم فتح التطبيق
      // منه): يُتجاهل إن كان أحدث سجل مطابقاً خلال دقيقتين.
      if (entries.isNotEmpty) {
        final latest = entries.first;
        if (latest.title == entry.title &&
            latest.body == entry.body &&
            latest.orderRef == entry.orderRef &&
            entry.receivedAt.difference(latest.receivedAt).inSeconds.abs() <
                120) {
          return;
        }
      }
      entries.insert(0, entry);
      await prefs.setStringList(
        _historyKey,
        entries
            .take(_maxHistory)
            .map((e) => jsonEncode(e.toJson()))
            .toList(),
      );
    } catch (_) {
      // السجل ميزة ثانوية — لا يوقف الإشعار.
    }
  }

  /// سجل الإشعارات المحفوظ (الأحدث أولاً).
  Future<List<PushHistoryEntry>> fetchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_historyKey) ?? <String>[];
    final entries = <PushHistoryEntry>[];
    for (final item in raw) {
      try {
        entries.add(
          PushHistoryEntry.fromJson(jsonDecode(item) as Map<String, dynamic>),
        );
      } catch (_) {
        // يتجاهل سجلاً تالفاً.
      }
    }
    return entries;
  }

  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
  }

  /// يحفظ رقم طلب فُتح التطبيق من إشعاره.
  static Future<void> setPendingOrderRef(String ref) async {
    if (ref.trim().isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pendingOrderKey, ref.trim());
    } catch (_) {
      // لا يوقف شيئاً.
    }
  }

  /// يقرأ رقم الطلب المعلق ويمسحه (يُستهلك مرة واحدة).
  Future<String?> takePendingOrderRef() async {
    final prefs = await SharedPreferences.getInstance();
    final ref = prefs.getString(_pendingOrderKey);
    if (ref != null) await prefs.remove(_pendingOrderKey);
    return ref;
  }

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
      // فتح التطبيق من إشعار (خلفية أو مغلق): يسجَّل الإشعار ويُحفظ
      // رقم طلبه المرتبط ليُعرض زر «عرض طلباتي» في صفحة الإشعارات.
      FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpened);
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) await _onMessageOpened(initial);
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
      // نقر إشعار معروض محلياً: حمولته رقم الطلب المرتبط (إن وجد).
      onDidReceiveNotificationResponse: (response) async {
        final ref = (response.payload ?? '').trim();
        if (ref.isNotEmpty) await setPendingOrderRef(ref);
      },
    );
    _localReady = true;
  }

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    await showFromMessage(message);
  }

  Future<void> _onMessageOpened(RemoteMessage message) async {
    await recordMessage(message);
    final ref = entryFromMessage(message).orderRef;
    if (ref.isNotEmpty) await setPendingOrderRef(ref);
  }

  /// Displays a received FCM message as a local notification and records
  /// it in the in-app history (linked to its orderRef when present).
  /// Safe to call from the background isolate.
  static Future<void> showFromMessage(RemoteMessage message) async {
    final entry = entryFromMessage(message);
    await recordMessage(message);
    if (entry.body.isEmpty && entry.orderRef.isEmpty) return;
    await instance._showLocal(
      title: entry.title,
      body: entry.body,
      payload: entry.orderRef,
    );
  }

  /// Shows a local notification (used for incoming pushes and for the
  /// test button in the settings page).
  Future<void> showLocal({required String title, required String body}) =>
      _showLocal(title: title, body: body);

  Future<void> _showLocal({
    required String title,
    required String body,
    String payload = '',
  }) async {
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
      payload: payload.isEmpty ? null : payload,
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
