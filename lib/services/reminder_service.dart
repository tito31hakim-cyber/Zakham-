import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/cart_item.dart';
import 'birthday.dart';
import 'daily_perfume.dart';
import 'occasions.dart';

/// نتيجة الضغط على إشعار تذكير.
enum ReminderTapKind {
  cart,
  collection,
  reorder,
  offer,
  daily,
  birthday,
  occasion,
  unknown,
}

/// ما يعنيه الضغط على إشعار تذكير — يُحلَّل من الـ payload.
class ReminderTap {
  const ReminderTap(this.kind, [this.productId]);

  final ReminderTapKind kind;

  /// معرّف العطر لتذكير إعادة الشراء أو عرض المفضلة.
  final String? productId;

  static const String cartPayload = 'zakham:cart';
  static const String collectionPayload = 'zakham:collection';

  static String reorderPayload(String productId) => 'zakham:reorder:$productId';

  static String offerPayload(String productId) => 'zakham:offer:$productId';

  static String dailyPayload(String productId) => 'zakham:daily:$productId';

  /// الضغط على إشعار عيد الميلاد يفتح صفحة الحساب (بانر الهدية).
  static const String birthdayPayload = 'zakham:birthday';

  /// الضغط على إشعار مناسبة يفتح صفحة أول عطر مقترح كهدية لها.
  static String occasionPayload(String productId) =>
      'zakham:occasion:$productId';

  static ReminderTap parse(String? payload) {
    if (payload == null || payload.isEmpty) {
      return const ReminderTap(ReminderTapKind.unknown);
    }
    if (payload == cartPayload) return const ReminderTap(ReminderTapKind.cart);
    if (payload == collectionPayload) {
      return const ReminderTap(ReminderTapKind.collection);
    }
    if (payload == birthdayPayload) {
      return const ReminderTap(ReminderTapKind.birthday);
    }
    const reorderPrefix = 'zakham:reorder:';
    if (payload.startsWith(reorderPrefix)) {
      final id = payload.substring(reorderPrefix.length).trim();
      if (id.isNotEmpty) return ReminderTap(ReminderTapKind.reorder, id);
    }
    const offerPrefix = 'zakham:offer:';
    if (payload.startsWith(offerPrefix)) {
      final id = payload.substring(offerPrefix.length).trim();
      if (id.isNotEmpty) return ReminderTap(ReminderTapKind.offer, id);
    }
    const dailyPrefix = 'zakham:daily:';
    if (payload.startsWith(dailyPrefix)) {
      final id = payload.substring(dailyPrefix.length).trim();
      if (id.isNotEmpty) return ReminderTap(ReminderTapKind.daily, id);
    }
    const occasionPrefix = 'zakham:occasion:';
    if (payload.startsWith(occasionPrefix)) {
      final id = payload.substring(occasionPrefix.length).trim();
      if (id.isNotEmpty) return ReminderTap(ReminderTapKind.occasion, id);
    }
    return const ReminderTap(ReminderTapKind.unknown);
  }
}

/// تذكير إعادة شراء معلّق (محفوظ ليبقى بعد إعادة التشغيل).
class PendingReorder {
  const PendingReorder({
    required this.notificationId,
    required this.orderRef,
    required this.productId,
    required this.productName,
    required this.fireAt,
  });

  final int notificationId;
  final String orderRef;
  final String productId;
  final String productName;
  final DateTime fireAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'notificationId': notificationId,
        'orderRef': orderRef,
        'productId': productId,
        'productName': productName,
        'fireAt': fireAt.millisecondsSinceEpoch,
      };

  factory PendingReorder.fromJson(Map<String, dynamic> json) =>
      PendingReorder(
        notificationId: (json['notificationId'] as num?)?.toInt() ?? 0,
        orderRef: '${json['orderRef'] ?? ''}',
        productId: '${json['productId'] ?? ''}',
        productName: '${json['productName'] ?? ''}',
        fireAt: DateTime.fromMillisecondsSinceEpoch(
          (json['fireAt'] as num?)?.toInt() ?? 0,
        ),
      );
}

/// موعد تذكير السلة: بعد آخر تغيير في السلة بـ [ReminderService.cartReminderDelay].
DateTime cartReminderFireAt(DateTime now) =>
    now.add(ReminderService.cartReminderDelay);

/// موعد تذكير إعادة الشراء: بعد إتمام الطلب بـ [ReminderService.reorderReminderDelay].
DateTime reorderFireAt(DateTime now) =>
    now.add(ReminderService.reorderReminderDelay);

/// موعد تذكير «السلة الفارغة»: بعد آخر نشاط في التطبيق بـ
/// [ReminderService.emptyCartDelay]؛ وإن مضى هذا الموعد أصلاً (عاد
/// المستخدم بعد غياب طويل) يُجدوَل بعد يوم واحد بدلاً من الإطلاق الفوري.
DateTime emptyCartFireAt(DateTime lastActivity, DateTime now) {
  final candidate = lastActivity.add(ReminderService.emptyCartDelay);
  if (candidate.isAfter(now)) return candidate;
  return now.add(const Duration(days: 1));
}

/// هل يسمح سقف تكرار تذكير «السلة الفارغة» (مرة كل
/// [ReminderService.emptyCartMinInterval] على الأكثر) بإرسال جديد؟
/// [lastSentAt] هو موعد آخر تذكير مجدوَل (أو null إن لم يُرسل أبداً).
bool emptyCartCapAllows(DateTime? lastSentAt, DateTime now) {
  if (lastSentAt == null) return true;
  return now.difference(lastSentAt) >= ReminderService.emptyCartMinInterval;
}

/// التذكيرات المحلية لدار زخم: تذكير السلة، وتذكير إعادة الشراء،
/// وتذكير «السلة الفارغة» — كلها بإشعارات محلية مجدوَلة على الجهاز
/// (flutter_local_notifications)، بلا أي اتصال بالخادم.
///
/// كل العمليات best-effort: أي فشل (قناة المنصة غير متاحة، إذن
/// مرفوض، تخزين فاشل) يُتجاهل بهدوء فلا يكسر إطلاق التطبيق أو السلة
/// أو إتمام الطلب أبداً. النية المحفوظة (مواعيد الإطلاق) تُكتب في
/// SharedPreferences قبل طلب الجدولة من النظام، وتعيد
/// [reconcileOnStart] مزامنتها مع الإشعارات المعلّقة عند كل تشغيل
/// (مثلاً بعد إعادة تشغيل الجهاز التي تمسح المنبّهات).
class ReminderService {
  ReminderService._();

  static final ReminderService instance = ReminderService._();

  /// تذكير السلة بعد تركها دون إتمام الطلب.
  static const Duration cartReminderDelay = Duration(hours: 4);

  /// تذكير إعادة الشراء بعد إتمام الطلب.
  static const Duration reorderReminderDelay = Duration(days: 60);

  /// تذكير «السلة الفارغة» بعد آخر نشاط في التطبيق.
  static const Duration emptyCartDelay = Duration(days: 3);

  /// سقف تكرار تذكير «السلة الفارغة»: مرة كل 3 أيام على الأكثر.
  static const Duration emptyCartMinInterval = Duration(days: 3);

  /// أقصى عدد عطور يُجدوَل لها تذكير إعادة شراء من طلب واحد.
  static const int maxReorderProducts = 3;

  static const int cartNotificationId = 1001;
  static const int emptyCartNotificationId = 1003;
  static const int reorderNotificationIdBase = 1100;

  /// إشعار «عطر اليوم» اليومي الساعة 18:00.
  static const int dailyPerfumeNotificationId = 1200;

  /// إشعارات المناسبات (واحد لكل نوع مناسبة، بترتيب جدول
  /// [zakhamOccasions]).
  static const int occasionNotificationIdBase = 1300;

  /// إشعار هدية عيد الميلاد (قبل عيد الميلاد بـ 3 أيام).
  static const int birthdayNotificationId = 1400;

  static const String _enabledKey = 'zakham_reminders_enabled';
  static const String _dailyPerfumeEnabledKey = 'zakham_daily_perfume_enabled';
  static const String _dailyPerfumeFireKey = 'zakham_daily_perfume_ms';
  static const String _birthdayFireKey = 'zakham_birthday_reminder_ms';
  static const String _occasionFireKeyPrefix = 'zakham_occasion_ms_';
  static const String _lastActivityKey = 'zakham_last_activity_ms';
  static const String _emptyCartLastSentKey =
      'zakham_emptycart_last_sent_ms';
  static const String _cartReminderFireKey = 'zakham_cart_reminder_ms';
  static const String _reorderPendingKey = 'zakham_reorder_pending_v1';

  static const String _channelId = 'zakham_default';
  static const String _channelName = 'تنبيهات دار زخم';

  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// يُستدعى عند الضغط على إشعار تذكير — يضبطه الغلاف (StoreShell)
  /// قبل [init] ليعمل أيضاً عند التشغيل البارد من الإشعار.
  ValueChanged<String>? onNotificationTap;

  /// تسلسل عمليات الجدولة حتى لا تتداخل إلغاءات وجدولات متزامنة.
  Future<void> _queue = Future<void>.value();

  Future<void> _runSerialized(Future<void> Function() work) {
    final run = _queue.then((_) async {
      try {
        await work();
      } catch (_) {
        // best-effort — لا يوقف السلسلة.
      }
    });
    _queue = run;
    return run;
  }

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  /// يهيّئ قناة الإشعارات المحلية ومعالج الضغط. لا يرمي أبداً.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      tz.initializeTimeZones();
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const ios = DarwinInitializationSettings();
      await _local.initialize(
        const InitializationSettings(android: android, iOS: ios),
        onDidReceiveNotificationResponse: (response) {
          final payload = response.payload;
          if (payload != null && payload.isNotEmpty) {
            try {
              onNotificationTap?.call(payload);
            } catch (_) {}
          }
        },
      );
      // التشغيل البارد من الضغط على إشعار: يصل عبر تفاصيل الإطلاق.
      final launch = await _local.getNotificationAppLaunchDetails();
      final payload = launch?.notificationResponse?.payload;
      if (launch?.didNotificationLaunchApp == true &&
          payload != null &&
          payload.isNotEmpty) {
        try {
          onNotificationTap?.call(payload);
        } catch (_) {}
      }
    } catch (_) {
      // التذكيرات غير متاحة — يعمل التطبيق طبيعياً بدونها.
    }
  }

  /// هل التذكيرات المحلية مفعّلة؟ الافتراضي نعم (تذكيرات عن سلة
  /// العميل وطلباته، لا تسويق جماعي).
  Future<bool> isEnabled() async {
    try {
      final prefs = await _prefs;
      return prefs.getBool(_enabledKey) ?? true;
    } catch (_) {
      return true;
    }
  }

  Future<void> _cancelQuietly(int id) async {
    try {
      await _local.cancel(id);
    } catch (_) {
      // best-effort.
    }
  }

  /// يفعّل/يوقف كل التذكيرات. الإيقاف يلغي المعلّق منها فوراً.
  Future<void> setEnabled(bool enabled) async {
    try {
      final prefs = await _prefs;
      await prefs.setBool(_enabledKey, enabled);
    } catch (_) {}
    if (enabled) return;
    await _runSerialized(() async {
      await _cancelQuietly(cartNotificationId);
      await _cancelQuietly(emptyCartNotificationId);
      await _cancelQuietly(birthdayNotificationId);
      for (var i = 0; i < zakhamOccasions.length; i++) {
        await _cancelQuietly(occasionNotificationIdBase + i);
      }
      for (var i = 0; i < maxReorderProducts; i++) {
        await _cancelQuietly(reorderNotificationIdBase + i);
      }
      try {
        final prefs = await _prefs;
        await prefs.remove(_cartReminderFireKey);
        await prefs.remove(_reorderPendingKey);
        await prefs.remove(_birthdayFireKey);
      } catch (_) {}
    });
  }

  /// هل إشعار «عطر اليوم» اليومي مفعّل؟ الافتراضي نعم — مبدّل مستقل
  /// عن مبدّل تذكيرات السلة والطلبات.
  Future<bool> isDailyPerfumeEnabled() async {
    try {
      final prefs = await _prefs;
      return prefs.getBool(_dailyPerfumeEnabledKey) ?? true;
    } catch (_) {
      return true;
    }
  }

  /// يفعّل/يوقف إشعار «عطر اليوم». الإيقاف يلغي المجدوَل فوراً؛
  /// التفعيل يترك الجدولة لاستدعاء ensureDailyPerfumeScheduled مع
  /// عطر اليوم (عند بدء التشغيل أو من مبدّل صفحة الحساب).
  Future<void> setDailyPerfumeEnabled(bool enabled) async {
    try {
      final prefs = await _prefs;
      await prefs.setBool(_dailyPerfumeEnabledKey, enabled);
    } catch (_) {}
    if (enabled) return;
    await _runSerialized(() async {
      await _cancelQuietly(dailyPerfumeNotificationId);
      try {
        final prefs = await _prefs;
        await prefs.remove(_dailyPerfumeFireKey);
      } catch (_) {}
    });
  }

  /// يجدول إشعار «عطر اليوم» لموعد 18:00 التالي بعطر ذلك اليوم.
  /// يُستدعى عند بدء التشغيل وعند تفعيل المبدّل؛ يعيد الجدولة فقط إن
  /// تغيّر الموعد أو فُقد الإشعار من النظام (مثلاً بعد إعادة تشغيل
  /// الجهاز). الإشعار لقطة واحدة — لا تكرار يومي بمحتوى ثابت —
  /// فيُجدَّد محتواه مع كل تشغيل للتطبيق. best-effort.
  Future<void> ensureDailyPerfumeScheduled({
    required String productId,
    required String productName,
    required double price,
    String currency = 'EGP',
    DateTime? now,
  }) async {
    if (!await isDailyPerfumeEnabled()) return;
    await _runSerialized(() async {
      final fireAt = nextDailyPerfumeFireAt(now ?? DateTime.now());
      final prefs = await _prefs;
      final savedMs = prefs.getInt(_dailyPerfumeFireKey);
      final pending = await _pendingIds();
      if (savedMs == fireAt.millisecondsSinceEpoch &&
          pending.contains(dailyPerfumeNotificationId)) {
        return;
      }
      // النية تُحفظ أولاً، ثم تُجدوَل.
      await prefs.setInt(_dailyPerfumeFireKey, fireAt.millisecondsSinceEpoch);
      await _scheduleAt(
        dailyPerfumeNotificationId,
        'دار زخم',
        'عطر اليوم: «$productName» — ${price.toStringAsFixed(0)} $currency. اضغط لعرض العطر.',
        fireAt,
        ReminderTap.dailyPayload(productId),
      );
    });
  }

  /// يجدول إشعار هدية عيد الميلاد: قبل عيد الميلاد بـ 3 أيام الساعة
  /// 12:00 ظهراً. يُستدعى عند تحميل تاريخ الميلاد وعند حفظه؛ يعيد
  /// الجدولة فقط إن تغيّر الموعد أو فُقد الإشعار من النظام. بعد
  /// إطلاق الإشعار يعيد التشغيل التالي جدولته للسنة القادمة.
  /// best-effort، ولا يعمل إن أوقف العميل مبدّل التذكيرات.
  Future<void> ensureBirthdayReminder({
    required DateTime birthday,
    DateTime? now,
  }) async {
    if (!await isEnabled()) return;
    await _runSerialized(() async {
      final fireAt = nextBirthdayReminderAt(birthday, now ?? DateTime.now());
      final prefs = await _prefs;
      final savedMs = prefs.getInt(_birthdayFireKey);
      final pending = await _pendingIds();
      if (savedMs == fireAt.millisecondsSinceEpoch &&
          pending.contains(birthdayNotificationId)) {
        return;
      }
      await prefs.setInt(_birthdayFireKey, fireAt.millisecondsSinceEpoch);
      await _scheduleAt(
        birthdayNotificationId,
        'دار زخم',
        'عيد ميلادك بعد 3 أيام — هديتك بانتظارك خلال أسبوع عيد ميلادك.',
        fireAt,
        ReminderTap.birthdayPayload,
      );
    });
  }

  /// يجدول إشعار كل مناسبة قادمة: قبلها بأسبوع الساعة 12:00 ظهراً،
  /// بعنوان المناسبة واقتراح إهدائها. يُستدعى عند بدء التشغيل؛
  /// يُجدول فقط الوقوع القادم لكل نوع مناسبة، ويتخطى ما مضى موعد
  /// إشعاره (أقل من أسبوع على المناسبة — يبقى قسم المناسبات داخل
  /// التطبيق يعرضها). best-effort.
  Future<void> ensureOccasionReminders({DateTime? now}) async {
    if (!await isEnabled()) return;
    await _runSerialized(() async {
      final at = now ?? DateTime.now();
      final prefs = await _prefs;
      final pending = await _pendingIds();
      for (var i = 0; i < zakhamOccasions.length; i++) {
        final occasion = zakhamOccasions[i];
        final next = nextOccurrence(occasion, at);
        if (next == null) continue;
        final fireAt = occasionReminderFireAt(next);
        if (!fireAt.isAfter(at)) continue;
        final id = occasionNotificationIdBase + i;
        final key = '$_occasionFireKeyPrefix${occasion.id}_${next.year}';
        final savedMs = prefs.getInt(key);
        if (savedMs == fireAt.millisecondsSinceEpoch &&
            pending.contains(id)) {
          continue;
        }
        await prefs.setInt(key, fireAt.millisecondsSinceEpoch);
        final firstGift = occasion.giftProductIds.isNotEmpty
            ? occasion.giftProductIds.first
            : '';
        await _scheduleAt(
          id,
          'دار زخم',
          'مناسبة «${occasion.title}» بعد أسبوع — ${occasion.giftNote}.',
          fireAt,
          ReminderTap.occasionPayload(firstGift),
        );
      }
    });
  }

  /// موعد إشعار «عطر اليوم» المحفوظ (للاختبارات والتشخيص)، أو null.
  Future<DateTime?> dailyPerfumeFireTime() async {
    try {
      final prefs = await _prefs;
      final ms = prefs.getInt(_dailyPerfumeFireKey);
      return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
    } catch (_) {
      return null;
    }
  }

  /// يسجّل نشاطاً (فتح التطبيق / تغيير السلة / إتمام طلب) — أساس
  /// حساب موعد تذكير «السلة الفارغة».
  Future<void> noteActivity({DateTime? now}) async {
    try {
      final prefs = await _prefs;
      await prefs.setInt(
        _lastActivityKey,
        (now ?? DateTime.now()).millisecondsSinceEpoch,
      );
    } catch (_) {}
  }

  /// يُستدعى عند أي تغيير في السلة: سلة غير فارغة تُجدوَل لها تذكير
  /// بعد 4 ساعات (يُجدَّد مع كل تغيير) وتُلغى تذكير «الفارغة»؛ وسلة
  /// فارغة تُلغي تذكير الإتمام وتُسلَّح لها تذكير «الفارغة». إضافة عطر
  /// إلى السلة تلغي أيضاً أي تذكير إعادة شراء معلّق لذلك العطر.
  Future<void> onCartChanged({
    required bool cartEmpty,
    required Set<String> cartProductIds,
    DateTime? now,
  }) async {
    final at = now ?? DateTime.now();
    await noteActivity(now: at);
    if (!await isEnabled()) return;
    await _runSerialized(() async {
      if (cartEmpty) {
        await _cancelQuietly(cartNotificationId);
        try {
          final prefs = await _prefs;
          await prefs.remove(_cartReminderFireKey);
        } catch (_) {}
        await _armEmptyCart(at);
      } else {
        await _cancelQuietly(emptyCartNotificationId);
        await _removeReorderEntriesFor(cartProductIds);
        await _scheduleCartReminder(at);
      }
    });
  }

  /// يُستدعى بعد إتمام طلب بنجاح: يلغي تذكير السلة، ويجدول تذكير
  /// إعادة شراء بعد 60 يوماً لكل عطر في الطلب (3 عطور كحد أقصى).
  Future<void> onOrderCompleted({
    required String orderRef,
    required List<CartItem> items,
    DateTime? now,
  }) async {
    final at = now ?? DateTime.now();
    await noteActivity(now: at);
    if (!await isEnabled()) return;
    if (items.isEmpty) return;
    await _runSerialized(() async {
      await _cancelQuietly(cartNotificationId);
      try {
        final prefs = await _prefs;
        await prefs.remove(_cartReminderFireKey);
      } catch (_) {}
      for (var i = 0; i < maxReorderProducts; i++) {
        await _cancelQuietly(reorderNotificationIdBase + i);
      }
      // عطور مميزة بالترتيب، بلا تكرار.
      final seen = <String>{};
      final unique = <CartItem>[];
      for (final item in items) {
        if (seen.add(item.product.id)) unique.add(item);
      }
      final entries = <PendingReorder>[];
      for (var i = 0; i < unique.length && i < maxReorderProducts; i++) {
        final item = unique[i];
        final id = reorderNotificationIdBase + i;
        final fireAt = reorderFireAt(at);
        entries.add(PendingReorder(
          notificationId: id,
          orderRef: orderRef,
          productId: item.product.id,
          productName: item.product.name,
          fireAt: fireAt,
        ));
      }
      try {
        final prefs = await _prefs;
        await prefs.setString(
          _reorderPendingKey,
          jsonEncode(entries.map((e) => e.toJson()).toList()),
        );
      } catch (_) {}
      for (final entry in entries) {
        await _scheduleReorderEntry(entry);
      }
    });
  }

  /// مزامنة عند كل تشغيل: يعيد جدولة النوايا المحفوظة التي فقدها
  /// النظام (مثلاً بعد إعادة تشغيل الجهاز)، ويحذف تذكيرات إعادة
  /// الشراء القديمة (مرّ على موعدها أكثر من 30 يوماً).
  Future<void> reconcileOnStart({
    required bool cartEmpty,
    required Set<String> cartProductIds,
    DateTime? now,
  }) async {
    final at = now ?? DateTime.now();
    await noteActivity(now: at);
    if (!await isEnabled()) return;
    await _runSerialized(() async {
      final prefs = await _prefs;
      await _pruneStaleReorders(prefs, at);
      // يعيد جدولة تذكيرات إعادة شراء محفوظة فقدها النظام.
      final pendingIds = await _pendingIds();
      for (final entry in _readReorderEntries(prefs)) {
        if (entry.fireAt.isAfter(at) &&
            !pendingIds.contains(entry.notificationId)) {
          await _scheduleReorderEntry(entry);
        }
      }
      if (cartEmpty) {
        await _cancelQuietly(cartNotificationId);
        try {
          await prefs.remove(_cartReminderFireKey);
        } catch (_) {}
        await _armEmptyCart(at);
      } else {
        await _removeReorderEntriesFor(cartProductIds);
        final fireMs = prefs.getInt(_cartReminderFireKey);
        final fireAt = fireMs == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(fireMs);
        if (fireAt == null || fireAt.isBefore(at)) {
          await _scheduleCartReminder(at);
        } else if (!pendingIds.contains(cartNotificationId)) {
          await _scheduleAt(
            cartNotificationId,
            'دار زخم',
            'تركت عطراً في سلتك — أكمل طلبك.',
            fireAt,
            ReminderTap.cartPayload,
          );
        }
      }
    });
  }

  /// تذكيرات إعادة الشراء المعلّقة حالياً (للاختبارات والتشخيص).
  Future<List<PendingReorder>> pendingReorders() async {
    try {
      final prefs = await _prefs;
      return _readReorderEntries(prefs);
    } catch (_) {
      return const <PendingReorder>[];
    }
  }

  /// موعد تذكير السلة المحفوظ (للاختبارات والتشخيص)، أو null.
  Future<DateTime?> cartReminderFireTime() async {
    try {
      final prefs = await _prefs;
      final ms = prefs.getInt(_cartReminderFireKey);
      return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
    } catch (_) {
      return null;
    }
  }

  /// موعد آخر تذكير «سلة فارغة» مجدوَل (للاختبارات والتشخيص)، أو null.
  Future<DateTime?> emptyCartLastSentAt() async {
    try {
      final prefs = await _prefs;
      final ms = prefs.getInt(_emptyCartLastSentKey);
      return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
    } catch (_) {
      return null;
    }
  }

  List<PendingReorder> _readReorderEntries(SharedPreferences prefs) {
    final raw = prefs.getString(_reorderPendingKey);
    if (raw == null || raw.isEmpty) return const <PendingReorder>[];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map(PendingReorder.fromJson)
          .where((e) => e.productId.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const <PendingReorder>[];
    }
  }

  Future<void> _pruneStaleReorders(
    SharedPreferences prefs,
    DateTime now,
  ) async {
    final entries = _readReorderEntries(prefs);
    if (entries.isEmpty) return;
    final cutoff = now.subtract(const Duration(days: 30));
    final kept = <PendingReorder>[];
    var changed = false;
    for (final entry in entries) {
      if (entry.fireAt.isBefore(cutoff)) {
        changed = true;
        try {
          await _local.cancel(entry.notificationId);
        } catch (_) {}
      } else {
        kept.add(entry);
      }
    }
    if (changed) {
      await prefs.setString(
        _reorderPendingKey,
        jsonEncode(kept.map((e) => e.toJson()).toList()),
      );
    }
  }

  Future<void> _removeReorderEntriesFor(Set<String> productIds) async {
    if (productIds.isEmpty) return;
    final prefs = await _prefs;
    final entries = _readReorderEntries(prefs);
    if (entries.isEmpty) return;
    final kept = <PendingReorder>[];
    var changed = false;
    for (final entry in entries) {
      if (productIds.contains(entry.productId)) {
        changed = true;
        try {
          await _local.cancel(entry.notificationId);
        } catch (_) {}
      } else {
        kept.add(entry);
      }
    }
    if (changed) {
      await prefs.setString(
        _reorderPendingKey,
        jsonEncode(kept.map((e) => e.toJson()).toList()),
      );
    }
  }

  Future<void> _armEmptyCart(DateTime now) async {
    final prefs = await _prefs;
    final lastSentMs = prefs.getInt(_emptyCartLastSentKey);
    final lastSent = lastSentMs == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(lastSentMs);
    if (lastSent != null && lastSent.isAfter(now)) {
      // مجدوَل بالفعل لموعد قادم — يُعاد جدولته فقط إن فقده النظام
      // (مثلاً بعد إعادة تشغيل الجهاز).
      final pending = await _pendingIds();
      if (pending.contains(emptyCartNotificationId)) return;
      await _scheduleAt(
        emptyCartNotificationId,
        'دار زخم',
        'سلتك فاضية — تصفح التشكيلة واختر عطرك.',
        lastSent,
        ReminderTap.collectionPayload,
      );
      return;
    }
    if (!emptyCartCapAllows(lastSent, now)) return;
    final lastActivityMs = prefs.getInt(_lastActivityKey);
    final lastActivity = lastActivityMs == null
        ? now
        : DateTime.fromMillisecondsSinceEpoch(lastActivityMs);
    final fireAt = emptyCartFireAt(lastActivity, now);
    // النية تُحفظ أولاً، ثم تُجدوَل — إن فشلت الجدولة تعيد
    // reconcileOnStart المحاولة عند التشغيل التالي.
    await prefs.setInt(
      _emptyCartLastSentKey,
      fireAt.millisecondsSinceEpoch,
    );
    await _scheduleAt(
      emptyCartNotificationId,
      'دار زخم',
      'سلتك فاضية — تصفح التشكيلة واختر عطرك.',
      fireAt,
      ReminderTap.collectionPayload,
    );
  }

  Future<void> _scheduleCartReminder(DateTime now) async {
    final fireAt = cartReminderFireAt(now);
    final prefs = await _prefs;
    await prefs.setInt(_cartReminderFireKey, fireAt.millisecondsSinceEpoch);
    await _scheduleAt(
      cartNotificationId,
      'دار زخم',
      'تركت عطراً في سلتك — أكمل طلبك.',
      fireAt,
      ReminderTap.cartPayload,
    );
  }

  Future<void> _scheduleReorderEntry(PendingReorder entry) async {
    await _scheduleAt(
      entry.notificationId,
      'دار زخم',
      'عطرك «${entry.productName}» قرّب يخلص؟ أعد طلبه بضغطة واحدة.',
      entry.fireAt,
      ReminderTap.reorderPayload(entry.productId),
    );
  }

  Future<void> _scheduleAt(
    int id,
    String title,
    String body,
    DateTime fireAt,
    String payload,
  ) async {
    try {
      await _local.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(fireAt.toUtc(), tz.UTC),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription:
                'تنبيهات دار زخم: الطلبات والعروض والوصلات الجديدة.',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        // inexact: لا يحتاج إذن المنبّه الدقيق (SCHEDULE_EXACT_ALARM).
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: payload,
      );
    } catch (_) {
      // الجدولة فاشلة (إذن مرفوض مثلاً) — النية المحفوظة تبقى
      // لتعيد reconcileOnStart المحاولة لاحقاً.
    }
  }

  Future<Set<int>> _pendingIds() async {
    try {
      final pending = await _local.pendingNotificationRequests();
      return pending.map((request) => request.id).toSet();
    } catch (_) {
      return <int>{};
    }
  }
}
