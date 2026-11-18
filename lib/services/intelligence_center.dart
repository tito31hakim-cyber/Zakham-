import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'admin_api.dart';

/// مركز ذكاء دار زخم — النسخة الأولى: قراءة وتحليل فقط (2026-11-18).
///
/// يقرأ بيانات المتجر من نقاط الإدارة الموجودة أصلاً (قائمة الطلبات +
/// تفاصيل الطلب + المنتجات + العملاء) ويحسب منها إحاطة اليوم وفرز
/// الطلبات وإجابات المستشار — بلا أي كتابة على الخادم، وبلا أي إرسال،
/// وبلا أي استدعاء ذكاء اصطناعي أو مفتاح API. المحادثة الحرة بالذكاء
/// مرحلة لاحقة منفصلة.
///
/// كل منطق التحليل دوال خالصة على خرائط عادية (بلا HTTP) حتى تُختبر
/// ببيانات وهمية؛ وجلب البيانات وحده في [IntelligenceRepository].

/// تسميات التركيز العربية — نفس قيم product.dart (presence=حضور،
/// extra=فَوْحان، nuclear=نووي).
String intelligenceConcentrationLabel(String key) => switch (key.trim()) {
      'presence' => 'حضور',
      'extra' => 'فَوْحان',
      'nuclear' => 'نووي',
      _ => key.trim(),
    };

double _num(dynamic v, [double fallback = 0]) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.trim()) ?? fallback;
  return fallback;
}

String _str(dynamic v) => (v ?? '').toString().trim();

/// تاريخ بصيغة YYYY-MM-DD من DateTime محلي.
String _ymd(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime? _parseCreatedAt(dynamic v) {
  final s = _str(v);
  if (s.isEmpty) return null;
  return DateTime.tryParse(s);
}

/// يوحّد رقم هاتف مصري للمقارنة: أرقام فقط، و0020/20+ تتحول إلى 0.
/// يرجع '' عند غياب رقم صالح.
String normalizePhone(dynamic raw) {
  var digits = _str(raw).replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('0020')) digits = digits.substring(4);
  if (digits.startsWith('20') && digits.length == 12) {
    digits = '0${digits.substring(2)}';
  }
  return digits;
}

/// الحزمة الخام التي يجلبها المستودع من الخادم قبل التحليل.
class BriefingData {
  const BriefingData({
    required this.now,
    required this.todayOrders,
    required this.unpaidOrders,
    required this.proofSubmittedOrders,
    required this.recentOrders,
    required this.lastWeekOrders,
    required this.cancelledOrders,
    required this.orderDetails,
    required this.products,
    required this.customers,
    required this.detailsSkipped,
  });

  /// لحظة الجلب (التوقيت المحلي للجهاز).
  final DateTime now;

  /// صفوف قائمة الطلبات لليوم (order_ref/total/status/payment_status/...).
  final List<Map<String, dynamic>> todayOrders;

  /// صفوف بلا تأكيد دفع: payment_status = unpaid.
  final List<Map<String, dynamic>> unpaidOrders;

  /// صفوف بانتظار المراجعة: payment_status = proof_submitted.
  final List<Map<String, dynamic>> proofSubmittedOrders;

  /// صفوف آخر 30 يوماً (لمقارنة الأسبوع والمبيعات والحملات).
  final List<Map<String, dynamic>> recentOrders;

  /// صفوف الأسبوع قبل الماضي (الأيام 8–14) لمقارنة الأسبوع.
  final List<Map<String, dynamic>> lastWeekOrders;

  /// صفوف الطلبات الملغاة (صفحة أولى فقط).
  final List<Map<String, dynamic>> cancelledOrders;

  /// تفاصيل الطلبات الكاملة (orderDetail) مفتاحها orderRef.
  final Map<String, Map<String, dynamic>> orderDetails;

  /// منتجات الإدارة (مع variantRows).
  final List<Map<String, dynamic>> products;

  /// عملاء الإدارة (مع ordersCount/ordersValue).
  final List<Map<String, dynamic>> customers;

  /// عدد تفاصيل الطلبات التي تعذّر جلبها (تُعرض كملاحظة لا كخطأ).
  final int detailsSkipped;
}

class LowStockVariant {
  const LowStockVariant({
    required this.productName,
    required this.sizeMl,
    required this.concentration,
    required this.stockQty,
  });

  final String productName;
  final int sizeMl;
  final String concentration;
  final int stockQty;

  String get label =>
      '$productName — $sizeMl مل (${intelligenceConcentrationLabel(concentration)})';
}

class DailyBriefing {
  const DailyBriefing({
    required this.todayCount,
    required this.todayRevenue,
    required this.todayDelivered,
    required this.unpaidCount,
    required this.proofSubmittedCount,
    required this.awaitingPaymentTotal,
    required this.topPerfumeName,
    required this.topPerfumeQty,
    required this.topPerfumeOrders,
    required this.lowStock,
  });

  final int todayCount;
  final double todayRevenue;
  final int todayDelivered;
  final int unpaidCount;
  final int proofSubmittedCount;
  final double awaitingPaymentTotal;
  final String topPerfumeName;
  final int topPerfumeQty;
  final int topPerfumeOrders;
  final List<LowStockVariant> lowStock;

  int get awaitingPaymentCount => unpaidCount + proofSubmittedCount;
}

enum TriageSeverity { high, medium, low }

class TriageFlag {
  const TriageFlag({
    required this.orderRef,
    required this.severity,
    required this.rule,
    required this.title,
    required this.detail,
    required this.createdAt,
  });

  final String orderRef;
  final TriageSeverity severity;
  final String rule;
  final String title;
  final String detail;
  final String createdAt;

  String get severityLabel => switch (severity) {
        TriageSeverity.high => 'عالية',
        TriageSeverity.medium => 'متوسطة',
        TriageSeverity.low => 'منخفضة',
      };
}

class WeekComparison {
  const WeekComparison({
    required this.thisWeekCount,
    required this.thisWeekRevenue,
    required this.lastWeekCount,
    required this.lastWeekRevenue,
    required this.thisWeekCancelled,
    required this.lastWeekCancelled,
    required this.thisWeekAwaiting,
    required this.verdict,
  });

  final int thisWeekCount;
  final double thisWeekRevenue;
  final int lastWeekCount;
  final double lastWeekRevenue;
  final int thisWeekCancelled;
  final int lastWeekCancelled;
  final int thisWeekAwaiting;
  final String verdict;
}

class TopCustomer {
  const TopCustomer({
    required this.displayName,
    required this.email,
    required this.ordersCount,
    required this.ordersValue,
  });

  final String displayName;
  final String email;
  final int ordersCount;
  final double ordersValue;
}

class RestockSuggestion {
  const RestockSuggestion({
    required this.productName,
    required this.soldQty30d,
    required this.stockQty,
    required this.reason,
  });

  final String productName;
  final int soldQty30d;
  final int stockQty;
  final String reason;
}

class CampaignDraft {
  const CampaignDraft({
    required this.perfumeName,
    required this.buyersOrders,
    required this.audienceText,
    required this.message,
    required this.whatsappText,
    required this.notificationText,
    required this.suggestedTime,
    required this.offerText,
  });

  final String perfumeName;
  final int buyersOrders;
  final String audienceText;
  final String message;
  final String whatsappText;
  final String notificationText;
  final String suggestedTime;
  final String offerText;
}

/// إدخال في سجل قرارات المركز: ماذا حلّل، وعلى أي بيانات، ولماذا اقترح.
class DecisionLogEntry {
  const DecisionLogEntry({
    required this.time,
    required this.kind,
    required this.summary,
    required this.basis,
    required this.reason,
  });

  final DateTime time;
  final String kind;
  final String summary;
  final String basis;
  final String reason;

  Map<String, dynamic> toJson() => {
        'time': time.toIso8601String(),
        'kind': kind,
        'summary': summary,
        'basis': basis,
        'reason': reason,
      };

  static DecisionLogEntry? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final time = DateTime.tryParse(_str(raw['time']));
    if (time == null) return null;
    return DecisionLogEntry(
      time: time,
      kind: _str(raw['kind']),
      summary: _str(raw['summary']),
      basis: _str(raw['basis']),
      reason: _str(raw['reason']),
    );
  }
}

/// سجل قرارات المركز — محلي فقط (SharedPreferences، آخر 50 إدخالاً).
class IntelligenceLog {
  static const String key = 'zakham_intelligence_log';
  static const int maxEntries = 50;

  static Future<List<DecisionLogEntry>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .map(DecisionLogEntry.fromJson)
          .whereType<DecisionLogEntry>()
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  static Future<void> add(DecisionLogEntry entry) async {
    try {
      final current = await load();
      final next = [entry, ...current].take(maxEntries).toList();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        key,
        jsonEncode(next.map((e) => e.toJson()).toList()),
      );
    } catch (_) {
      // فشل حفظ السجل لا يوقف عرض المركز.
    }
  }

  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    } catch (_) {
      // لا شيء.
    }
  }
}

/// كل منطق التحليل الخالص — بلا HTTP وبلا حالة، ليُختبر ببيانات وهمية.
class IntelligenceAnalysis {
  /// حد انخفاض المخزون: متغير نشط بمخزون 5 أو أقل يُعتبر قارباً على النفاد.
  static const int lowStockThreshold = 5;

  /// قواعد لا يمكن حسابها من البيانات الحالية — تُعرض كملاحظة صريحة
  /// بدل اختلاق أرقام: لا يوجد مبلغ تحويل في بيانات الطلب (مرجع الإيصال
  /// نص فقط)، ولا تاريخ آخر طلب في قائمة العملاء، ولا رابط بين العميل
  /// وطلباته في القوائم.
  static const List<String> unavailableRules = [
    'مقارنة قيمة التحويل بالإجمالي: بيانات الطلب لا تحمل مبلغ التحويل.',
    'العملاء الغائبون 45 يوماً: قائمة العملاء بلا تاريخ آخر طلب، وقوائم '
        'الطلبات بلا رابط بالعميل.',
  ];

  /// إحاطة اليوم من الحزمة الخام.
  static DailyBriefing computeBriefing(BriefingData data) {
    final today = data.todayOrders;
    var revenue = 0.0;
    var delivered = 0;
    for (final o in today) {
      if (_str(o['status']) == 'cancelled') continue;
      revenue += _num(o['total']);
      if (_str(o['status']) == 'delivered') delivered++;
    }
    var awaitingTotal = 0.0;
    for (final o in [...data.unpaidOrders, ...data.proofSubmittedOrders]) {
      awaitingTotal += _num(o['total']);
    }

    // العطر الأعلى طلباً اليوم: تجميع الكميات من تفاصيل طلبات اليوم.
    final todayStr = _ymd(data.now);
    final qtyByName = <String, int>{};
    final ordersByName = <String, Set<String>>{};
    for (final detail in data.orderDetails.values) {
      final created = _str(detail['createdAt']);
      if (!created.startsWith(todayStr)) continue;
      if (_str(detail['status']) == 'cancelled') continue;
      final items = (detail['items'] as List?) ?? const [];
      for (final raw in items) {
        if (raw is! Map) continue;
        final name = _str(raw['nameAr']).isNotEmpty
            ? _str(raw['nameAr'])
            : _str(raw['productId']);
        if (name.isEmpty) continue;
        final qty = _num(raw['quantity'], 1).toInt();
        qtyByName[name] = (qtyByName[name] ?? 0) + qty;
        (ordersByName[name] ??= <String>{})
            .add(_str(detail['orderRef']));
      }
    }
    var topName = '';
    var topQty = 0;
    var topOrders = 0;
    for (final entry in qtyByName.entries) {
      if (entry.value > topQty) {
        topName = entry.key;
        topQty = entry.value;
        topOrders = ordersByName[entry.key]?.length ?? 0;
      }
    }

    // المتغيرات القاربة على النفاد: متغير نشط بمخزون <= 5.
    final low = <LowStockVariant>[];
    for (final p in data.products) {
      final name = _str(p['name']);
      if (name.isEmpty) continue;
      final rows = (p['variantRows'] as List?) ?? const [];
      for (final raw in rows) {
        if (raw is! Map) continue;
        final active = raw['is_active'];
        if (active == 0 || active == false || active == '0') continue;
        final stock = _num(raw['stock_qty']).toInt();
        if (stock <= lowStockThreshold) {
          low.add(LowStockVariant(
            productName: name,
            sizeMl: _num(raw['size_ml']).toInt(),
            concentration: _str(raw['concentration_key']),
            stockQty: stock,
          ));
        }
      }
    }
    low.sort((a, b) => a.stockQty.compareTo(b.stockQty));

    return DailyBriefing(
      todayCount: today.length,
      todayRevenue: revenue,
      todayDelivered: delivered,
      unpaidCount: data.unpaidOrders.length,
      proofSubmittedCount: data.proofSubmittedOrders.length,
      awaitingPaymentTotal: awaitingTotal,
      topPerfumeName: topName,
      topPerfumeQty: topQty,
      topPerfumeOrders: topOrders,
      lowStock: low,
    );
  }

  /// وكيل فرز الطلبات (قراءة فقط): أعلام مرتبة بالأولوية.
  ///
  /// القواعد المحسوبة: بيانات ناقصة، نفس الهاتف 3 طلبات خلال 10 دقائق،
  /// طلبات ملغاة سابقة لنفس الهاتف، بلا إثبات دفع منذ أكثر من 24 ساعة.
  /// قاعدة مبلغ التحويل غير محسوبة — انظر [unavailableRules].
  static List<TriageFlag> triageOrders(BriefingData data) {
    final flags = <TriageFlag>[];
    final details = data.orderDetails.values.toList();
    final byPhone = <String, List<Map<String, dynamic>>>{};
    final cancelledPhones = <String>{};
    for (final d in details) {
      final phone = normalizePhone(d['phone']);
      if (phone.isEmpty) continue;
      (byPhone[phone] ??= []).add(d);
      if (_str(d['status']) == 'cancelled') cancelledPhones.add(phone);
    }

    for (final d in details) {
      final ref = _str(d['orderRef']);
      final created = _str(d['createdAt']);
      final phone = normalizePhone(d['phone']);
      final status = _str(d['status']);
      final paymentStatus = _str(d['paymentStatus']);

      // 1) بيانات ناقصة أو غير صالحة.
      final missing = <String>[];
      if (phone.length < 10) missing.add('الهاتف');
      if (_str(d['governorate']).isEmpty) missing.add('المحافظة');
      if (_str(d['address']).isEmpty) missing.add('العنوان');
      final items = (d['items'] as List?) ?? const [];
      if (items.isEmpty) missing.add('الأصناف');
      if (_num(d['total']) <= 0) missing.add('الإجمالي');
      if (missing.isNotEmpty) {
        flags.add(TriageFlag(
          orderRef: ref,
          severity: missing.contains('الهاتف')
              ? TriageSeverity.high
              : TriageSeverity.medium,
          rule: 'missing_data',
          title: 'بيانات ناقصة',
          detail: 'ناقص: ${missing.join('، ')}',
          createdAt: created,
        ));
      }

      // 2) طلبات ملغاة سابقة لنفس الهاتف.
      if (phone.isNotEmpty &&
          cancelledPhones.contains(phone) &&
          status != 'cancelled') {
        flags.add(TriageFlag(
          orderRef: ref,
          severity: TriageSeverity.medium,
          rule: 'previous_cancelled',
          title: 'طلبات ملغاة سابقة',
          detail: 'نفس الهاتف له طلب ملغى سابقاً — راجع قبل التجهيز.',
          createdAt: created,
        ));
      }

      // 3) بلا إثبات دفع منذ أكثر من 24 ساعة.
      if (status == 'pending_transfer' &&
          paymentStatus == 'unpaid' &&
          d['receiptAvailable'] != true) {
        final createdAt = _parseCreatedAt(created);
        if (createdAt != null &&
            data.now.difference(createdAt) > const Duration(hours: 24)) {
          flags.add(TriageFlag(
            orderRef: ref,
            severity: TriageSeverity.medium,
            rule: 'no_receipt_24h',
            title: 'بلا إثبات دفع',
            detail: 'لم يرفع العميل إثبات دفع منذ أكثر من 24 ساعة.',
            createdAt: created,
          ));
        }
      }
    }

    // 4) نفس الهاتف أنشأ 3 طلبات خلال 10 دقائق — يُعلَّم أحدث طلب
    // غير ملغى في النافذة (أو الأحدث إن كانت كلها ملغاة).
    for (final group in byPhone.values) {
      if (group.length < 3) continue;
      final sorted = [...group]
        ..sort((a, b) =>
            _str(a['createdAt']).compareTo(_str(b['createdAt'])));
      for (var i = 0; i < sorted.length; i++) {
        final start = _parseCreatedAt(sorted[i]['createdAt']);
        if (start == null) continue;
        final window = sorted.where((d) {
          final t = _parseCreatedAt(d['createdAt']);
          if (t == null) return false;
          final diff = t.difference(start);
          return !diff.isNegative && diff <= const Duration(minutes: 10);
        }).toList();
        if (window.length >= 3) {
          final target = window.lastWhere(
            (d) => _str(d['status']) != 'cancelled',
            orElse: () => window.last,
          );
          flags.add(TriageFlag(
            orderRef: _str(target['orderRef']),
            severity: TriageSeverity.high,
            rule: 'repeat_phone',
            title: 'احتمال تكرار',
            detail:
                'نفس الهاتف أنشأ ${window.length} طلبات خلال 10 دقائق — '
                'راجع قبل التجهيز.',
            createdAt: _str(target['createdAt']),
          ));
          break;
        }
      }
    }

    int rank(TriageSeverity s) => switch (s) {
          TriageSeverity.high => 0,
          TriageSeverity.medium => 1,
          TriageSeverity.low => 2,
        };
    flags.sort((a, b) {
      final bySeverity = rank(a.severity).compareTo(rank(b.severity));
      if (bySeverity != 0) return bySeverity;
      return b.createdAt.compareTo(a.createdAt);
    });
    return flags;
  }

  /// مقارنة المبيعات: آخر 7 أيام مقابل الأيام 8–14 (بلا الملغاة في الإيراد).
  static WeekComparison compareWeeks(
    List<Map<String, dynamic>> thisWeek,
    List<Map<String, dynamic>> lastWeek,
  ) {
    double revenue(List<Map<String, dynamic>> rows) {
      var sum = 0.0;
      for (final o in rows) {
        if (_str(o['status']) == 'cancelled') continue;
        sum += _num(o['total']);
      }
      return sum;
    }

    int countWhere(List<Map<String, dynamic>> rows, String status) =>
        rows.where((o) => _str(o['status']) == status).length;
    int awaiting(List<Map<String, dynamic>> rows) => rows
        .where((o) =>
            _str(o['payment_status']) == 'unpaid' ||
            _str(o['payment_status']) == 'proof_submitted')
        .length;

    final twRevenue = revenue(thisWeek);
    final lwRevenue = revenue(lastWeek);
    final verdict = _weekVerdict(
      thisWeekCount: thisWeek.length,
      thisWeekRevenue: twRevenue,
      lastWeekCount: lastWeek.length,
      lastWeekRevenue: lwRevenue,
      thisWeekCancelled: countWhere(thisWeek, 'cancelled'),
      lastWeekCancelled: countWhere(lastWeek, 'cancelled'),
      thisWeekAwaiting: awaiting(thisWeek),
    );
    return WeekComparison(
      thisWeekCount: thisWeek.length,
      thisWeekRevenue: twRevenue,
      lastWeekCount: lastWeek.length,
      lastWeekRevenue: lwRevenue,
      thisWeekCancelled: countWhere(thisWeek, 'cancelled'),
      lastWeekCancelled: countWhere(lastWeek, 'cancelled'),
      thisWeekAwaiting: awaiting(thisWeek),
      verdict: verdict,
    );
  }

  static String _weekVerdict({
    required int thisWeekCount,
    required double thisWeekRevenue,
    required int lastWeekCount,
    required double lastWeekRevenue,
    required int thisWeekCancelled,
    required int lastWeekCancelled,
    required int thisWeekAwaiting,
  }) {
    if (thisWeekCount == 0 && lastWeekCount == 0) {
      return 'لا توجد طلبات في الأسبوعين — لا بيانات كافية للمقارنة.';
    }
    final money = (double v) => '${v.toStringAsFixed(0)} ج.م';
    final parts = <String>[];
    if (lastWeekRevenue > 0) {
      final pct =
          ((thisWeekRevenue - lastWeekRevenue) / lastWeekRevenue * 100);
      final direction = pct < 0 ? 'انخفضت' : 'ارتفعت';
      parts.add(
        '$direction المبيعات بنسبة ${pct.abs().toStringAsFixed(0)}% هذا الأسبوع '
        '(${money(thisWeekRevenue)} مقابل ${money(lastWeekRevenue)}، '
        '$thisWeekCount طلباً مقابل $lastWeekCount).',
      );
    } else {
      parts.add(
        'هذا الأسبوع: ${money(thisWeekRevenue)} من $thisWeekCount طلباً '
        '(الأسبوع الماضي بلا إيراد مسجل).',
      );
    }
    if (thisWeekCancelled > lastWeekCancelled) {
      parts.add(
        'الطلبات الملغاة زادت هذا الأسبوع ($thisWeekCancelled مقابل '
        '$lastWeekCancelled) — راجع أسباب الإلغاء في فرز الطلبات.',
      );
    }
    if (thisWeekAwaiting > 0) {
      parts.add(
        '$thisWeekAwaiting طلباً ما زال بلا تأكيد دفع — تأكيدها يرفع إيراد '
        'الأسبوع دون أي حملة.',
      );
    }
    return parts.join(' ');
  }

  /// أفضل العملاء لإطلاق عطر جديد: الأعلى قيمة طلبات موثقة، ثم عدد الطلبات.
  static List<TopCustomer> topCustomers(
    List<Map<String, dynamic>> customers, {
    int limit = 20,
  }) {
    final list = customers.map((c) {
      return TopCustomer(
        displayName: _str(c['displayName']),
        email: _str(c['email']),
        ordersCount: _num(c['ordersCount']).toInt(),
        ordersValue: _num(c['ordersValue']),
      );
    }).toList();
    list.sort((a, b) {
      final byValue = b.ordersValue.compareTo(a.ordersValue);
      if (byValue != 0) return byValue;
      return b.ordersCount.compareTo(a.ordersCount);
    });
    return list.take(limit).toList();
  }

  /// الكميات المباعة لكل منتج من تفاصيل الطلبات غير الملغاة.
  static Map<String, int> soldByProduct(
    Iterable<Map<String, dynamic>> details,
  ) {
    final sold = <String, int>{};
    for (final d in details) {
      if (_str(d['status']) == 'cancelled') continue;
      final items = (d['items'] as List?) ?? const [];
      for (final raw in items) {
        if (raw is! Map) continue;
        final id = _str(raw['productId']);
        if (id.isEmpty) continue;
        sold[id] = (sold[id] ?? 0) + _num(raw['quantity'], 1).toInt();
      }
    }
    return sold;
  }

  /// اقتراحات إعادة المخزون: منتج بِيع خلال 30 يوماً ومخزونه الكلي <= 5.
  static List<RestockSuggestion> restockSuggestions(
    List<Map<String, dynamic>> products,
    Map<String, int> soldByProductId,
  ) {
    final out = <RestockSuggestion>[];
    for (final p in products) {
      final id = _str(p['id']);
      final name = _str(p['name']);
      final sold = soldByProductId[id] ?? 0;
      if (sold <= 0 || name.isEmpty) continue;
      var stock = 0;
      var found = false;
      final rows = (p['variantRows'] as List?) ?? const [];
      for (final raw in rows) {
        if (raw is! Map) continue;
        final active = raw['is_active'];
        if (active == 0 || active == false || active == '0') continue;
        stock += _num(raw['stock_qty']).toInt();
        found = true;
      }
      if (!found) stock = _num(p['stockQty']).toInt();
      if (stock <= lowStockThreshold) {
        out.add(RestockSuggestion(
          productName: name,
          soldQty30d: sold,
          stockQty: stock,
          reason: 'بِيع $sold خلال 30 يوماً والمخزون الحالي $stock فقط.',
        ));
      }
    }
    out.sort((a, b) => b.soldQty30d.compareTo(a.soldQty30d));
    return out;
  }

  /// أكثر وقت تصل فيه الطلبات (اليوم + الساعة الأكثر تكراراً).
  static String busiestOrderTime(List<Map<String, dynamic>> orders) {
    if (orders.isEmpty) return '—';
    const weekdays = <int, String>{
      6: 'السبت',
      7: 'الأحد',
      1: 'الاثنين',
      2: 'الثلاثاء',
      3: 'الأربعاء',
      4: 'الخميس',
      5: 'الجمعة',
    };
    final dayCount = <int, int>{};
    final hourCount = <int, int>{};
    for (final o in orders) {
      final t = _parseCreatedAt(o['created_at'] ?? o['createdAt']);
      if (t == null) continue;
      dayCount[t.weekday] = (dayCount[t.weekday] ?? 0) + 1;
      hourCount[t.hour] = (hourCount[t.hour] ?? 0) + 1;
    }
    if (dayCount.isEmpty || hourCount.isEmpty) return '—';
    final day = dayCount.entries.reduce(
      (a, b) => a.value >= b.value ? a : b,
    ).key;
    final hour = hourCount.entries.reduce(
      (a, b) => a.value >= b.value ? a : b,
    ).key;
    return '${weekdays[day] ?? ''} حوالي الساعة $hour:00';
  }

  /// مسودة حملة بلا خصم مباشر — نص فقط، بلا أي إرسال.
  static CampaignDraft campaignDraft({
    required String perfumeName,
    required int buyersOrders,
    required String busiestTime,
  }) {
    final audience =
        '$buyersOrders طلباً اشتروا «$perfumeName» خلال آخر 30 يوماً';
    const offer = 'عينة فَوْحان مجانية مع الطلب — بلا خصم مباشر';
    final message =
        '«$perfumeName» — عطرك المفضل يستحق الحجم الأكبر. اطلب 100 مل الآن '
        'وتصلك معه عينة فَوْحان هدية، لتجربة التركيز الأقوى قبل أن تختاره '
        'في طلبك القادم.';
    return CampaignDraft(
      perfumeName: perfumeName,
      buyersOrders: buyersOrders,
      audienceText: audience,
      message: message,
      whatsappText: 'مرحباً من دار زخم 🌸 $message',
      notificationText:
          '«$perfumeName» بحجم 100 مل + عينة فَوْحان هدية — اطلب الآن.',
      suggestedTime: busiestTime,
      offerText: offer,
    );
  }
}

/// جلب بيانات المركز من نقاط الإدارة الموجودة أصلاً — قراءة فقط.
/// لا ينشئ أي نقطة خادم ولا يكتب شيئاً.
class IntelligenceRepository {
  IntelligenceRepository(this.api);

  final AdminApi api;

  /// حد أقصى لصفحات كل قائمة (صفحة = 25 طلباً) حتى لا يطول الجلب.
  static const int maxListPages = 4;

  /// حد أقصى لتفاصيل الطلبات المجلبة في المرة الواحدة.
  static const int maxDetails = 80;

  Future<BriefingData> fetchBriefing({DateTime? now}) async {
    final current = now ?? DateTime.now();
    final todayStr = _ymd(current);
    final from30 = _ymd(current.subtract(const Duration(days: 30)));
    final from14 = _ymd(current.subtract(const Duration(days: 14)));
    final to8 = _ymd(current.subtract(const Duration(days: 8)));

    final today = await _ordersPages(
      dateFrom: todayStr,
      dateTo: todayStr,
      maxPages: 2,
    );
    final unpaid = await _ordersPages(
      paymentStatus: 'unpaid',
      maxPages: 2,
    );
    final proof = await _ordersPages(
      paymentStatus: 'proof_submitted',
      maxPages: 2,
    );
    final recent = await _ordersPages(
      dateFrom: from30,
      dateTo: todayStr,
    );
    final lastWeek = await _ordersPages(
      dateFrom: from14,
      dateTo: to8,
      maxPages: 2,
    );
    final cancelled = await _ordersPages(
      status: 'cancelled',
      maxPages: 1,
    );
    final products = await api.products();
    final customers = await api.customers();

    // تفاصيل الطلبات: اتحاد مراجع اليوم + آخر 30 يوماً + الملغاة، بحد أقصى.
    final refs = <String>{};
    for (final row in [...today, ...recent, ...cancelled]) {
      final ref = _str(row['order_ref']);
      if (ref.isNotEmpty) refs.add(ref);
    }
    final details = <String, Map<String, dynamic>>{};
    var skipped = 0;
    final refList = refs.take(maxDetails).toList();
    for (var i = 0; i < refList.length; i += 8) {
      final chunk = refList.skip(i).take(8);
      final results = await Future.wait(chunk.map((ref) async {
        try {
          final data = await api.orderDetail(ref);
          final order = data['order'];
          if (order is Map<String, dynamic>) return MapEntry(ref, order);
          return null;
        } catch (_) {
          return null;
        }
      }));
      for (final entry in results) {
        if (entry == null) {
          skipped++;
        } else {
          details[entry.key] = entry.value;
        }
      }
    }

    return BriefingData(
      now: current,
      todayOrders: today,
      unpaidOrders: unpaid,
      proofSubmittedOrders: proof,
      recentOrders: recent,
      lastWeekOrders: lastWeek,
      cancelledOrders: cancelled,
      orderDetails: details,
      products: products.whereType<Map<String, dynamic>>().toList(),
      customers: customers.whereType<Map<String, dynamic>>().toList(),
      detailsSkipped: skipped,
    );
  }

  Future<List<Map<String, dynamic>>> _ordersPages({
    String status = '',
    String paymentStatus = '',
    String dateFrom = '',
    String dateTo = '',
    int maxPages = maxListPages,
  }) async {
    final out = <Map<String, dynamic>>[];
    var page = 1;
    var totalPages = 1;
    while (page <= totalPages && page <= maxPages) {
      final data = await api.orders(
        status: status,
        paymentStatus: paymentStatus,
        dateFrom: dateFrom,
        dateTo: dateTo,
        page: page,
      );
      final rows = (data['orders'] as List?) ?? const [];
      out.addAll(rows.whereType<Map<String, dynamic>>());
      totalPages = (data['totalPages'] as num?)?.toInt() ?? 1;
      if (rows.isEmpty) break;
      page++;
    }
    return out;
  }
}
