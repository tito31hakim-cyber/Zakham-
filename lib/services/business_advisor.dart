import 'dart:ui';

import 'admin_api.dart';
import 'product_stock.dart';

/// مستشار دار زخم التجاري — قراءة وتحليل فقط (ملفات المستخدم v2 بعد ضبط).
///
/// يقرأ بيانات المتجر من نقاط الإدارة الموجودة أصلاً (analytics +
/// orders + customers + products) ويحسب 5 إشارات — بلا أي كتابة على
/// الخادم، وبلا إرسال، وبلا أي استدعاء ذكاء اصطناعي.
///
/// حدود البيانات الموثقة هنا (لا تُتجاوز):
/// - `analytics()` يرجع `orders`/`revenue`/`pending`/`delivered` فقط —
///   بلا مفتاح `customers`؛ فعدد العملاء من طول قائمة العملاء (النقطة
///   غير مرقّمة).
/// - قائمة الطلبات صفحة 25 طلباً؛ تُجلب صفحات إضافية حتى 100 طلب كحد
///   أقصى، والمجاميع الكلية من `analytics` و`bucketCounts` لا من القائمة.
/// - صفوف قائمة الطلبات تحمل `order_ref`/`created_at`/`total`/`status`/
///   `payment_status`/`payment_method`/`governorate` فقط — بلا عناصر
///   وبلا هواتف وبلا أسماء عملاء؛ فلا «أعلى عطر» ولا «هاتف مكرر» ولا
///   «عملاء غائبون» من هذه البيانات، ولا تُبنى أي إشارة عليها.
/// - مخزون المنتجات يُشتق من `variantRows` (انظر [adminStockFor])؛
///   المخزون المجهول لا يُعدّ منخفضاً أبداً.

/// أولوية الإشارة — enum بدل النصوص الحرة حتى لا تنكسر المقارنات.
enum AdvisorPriority {
  urgent('عاجل', Color(0xFFD32F2F)),
  high('مرتفع', Color(0xFFEF6C00)),
  opportunity('فرصة', Color(0xFF2E7D32)),
  watch('مراقبة', Color(0xFF757575)),
  learning('تعلم', Color(0xFF5E35B1)),
  diagnosis('تشخيص', Color(0xFF1565C0)),
  data('بيانات', Color(0xFF757575));

  const AdvisorPriority(this.label, this.color);

  final String label;
  final Color color;

  /// عاجل أو مرتفع: تُبرز البطاقة بحد برتقالي/أحمر في الصفحة.
  bool get isUrgent => this == urgent || this == high;
}

/// أيقونة الإشارة — enum تحوّله الصفحة إلى IconData (بلا نصوص).
enum AdvisorIcon { payment, inventory, customers, flow, pending }

class AdvisorInsight {
  const AdvisorInsight({
    required this.title,
    required this.body,
    required this.priority,
    required this.icon,
  });

  final String title;
  final String body;
  final AdvisorPriority priority;
  final AdvisorIcon icon;
}

class AdvisorReport {
  const AdvisorReport({
    required this.generatedAt,
    required this.orders,
    required this.customers,
    required this.products,
    required this.revenue,
    required this.pendingPayments,
    required this.deliveryRatio,
    required this.repeatCustomers,
    required this.lowStockCount,
    required this.lowStockUnknown,
    required this.ordersExamined,
    required this.unavailable,
    required this.insights,
    required this.businessContext,
    required this.nextFocus,
  });

  final DateTime generatedAt;

  /// إجمالي الطلبات من analytics (أو bucketCounts أو المفحوص).
  final int orders;

  /// عدد العملاء من طول قائمة العملاء (analytics بلا مفتاح customers).
  final int customers;
  final int products;
  final double revenue;
  final int pendingPayments;

  /// نسبة الطلبات المسلّمة من الإجمالي (0..1) — تظهر في ملخص الصفحة.
  final double deliveryRatio;

  /// عملاء لديهم طلبان أو أكثر — يظهر في ملخص الصفحة.
  final int repeatCustomers;

  /// منتجات مخزونها معروف ومنخفض — تظهر في ملخص الصفحة.
  final int lowStockCount;

  /// منتجات تعذّر تحديد مخزونها (بلا stockQty ولا variantRows).
  final int lowStockUnknown;

  /// عدد صفوف الطلبات المفحوصة فعلياً (حتى 100) — لنطاق الإشارات.
  final int ordersExamined;

  /// مفاتيح الأقسام التي تعذّر جلبها ('analytics'/'orders'/'customers'/
  /// 'products') — تعرض الصفحة «غير متاح» بدل صفحة خطأ كاملة.
  final List<String> unavailable;

  final List<AdvisorInsight> insights;

  /// السياق التجاري الثابت للدار — ذاكرة عمل المستشار (من v2).
  final String businessContext;

  /// قائمة التركيز التالية المحسوبة من البيانات (من v2).
  final List<String> nextFocus;
}

class BusinessAdvisorService {
  const BusinessAdvisorService(this.api);

  final AdminApi api;

  /// مهلة كل استدعاء خادم على حدة.
  static const Duration perCallTimeout = Duration(seconds: 15);

  /// حد صفحات قائمة الطلبات (صفحة = 25 طلباً) — 4 صفحات = 100 طلب.
  static const int maxOrderPages = 4;

  /// حد صفوف الطلبات المفحوصة في التحليل الواحد.
  static const int maxOrdersExamined = 100;

  /// مخزون معروف يساوي هذا الحد أو أقل يُعدّ منخفضاً.
  static const int lowStockThreshold = 3;

  /// عميل بهذا العدد من الطلبات أو أكثر يُعدّ متكرراً.
  static const int repeatCustomerMinOrders = 2;

  /// نسبة تسليم أقل من هذا الحد تُشخَّص كتحدٍّ في التحويل.
  static const double deliveryRatioWarning = 0.35;

  /// طلب معلق أقدم من هذا العمر يُصعَّد أولويته.
  static const int pendingStaleHours = 48;

  Future<AdvisorReport> analyze() async {
    final now = DateTime.now();
    final unavailable = <String>[];

    final analytics = await _call<Map<String, dynamic>>(
      'analytics',
      unavailable,
      () async => Map<String, dynamic>.from(await api.analytics()),
      const {},
    );
    final customers = await _call<List<dynamic>>(
      'customers',
      unavailable,
      () async => List<dynamic>.from(await api.customers()),
      const [],
    );
    final products = await _call<List<dynamic>>(
      'products',
      unavailable,
      () async => List<dynamic>.from(await api.products()),
      const [],
    );
    final orderPages = await _fetchOrderPages(unavailable);
    final orders = orderPages.rows;
    final bucketCounts = orderPages.bucketCounts;

    final totalOrders = _totalOrders(analytics, bucketCounts, orders.length);
    final pendingCount = _integer(
      analytics['pending'],
      _integer(
        bucketCounts['waiting_payment'],
        _countStatus(orders, 'pending_transfer'),
      ),
    );
    final deliveredCount = _integer(
      analytics['delivered'],
      _integer(
        bucketCounts['completed'],
        _countStatus(orders, 'delivered'),
      ),
    );
    final deliveryRatio =
        totalOrders == 0 ? 0 : deliveredCount / totalOrders;
    final repeatCustomers = customers.where((item) {
      if (item is! Map) return false;
      final value = item['ordersCount'] ?? item['orders_count'] ?? 0;
      return _number(value) >= repeatCustomerMinOrders;
    }).length;

    var lowStock = 0;
    var unknownStock = 0;
    for (final item in products) {
      final product = item is Map<String, dynamic>
          ? item
          : (item is Map
              ? Map<String, dynamic>.from(item)
              : const <String, dynamic>{});
      final stock = adminStockFor(product);
      if (stock == null) {
        unknownStock++;
      } else if (stock <= lowStockThreshold) {
        lowStock++;
      }
    }

    final ordersFailed = unavailable.contains('orders');
    final analyticsFailed = unavailable.contains('analytics');
    final insights = <AdvisorInsight>[
      _paymentInsight(pendingCount,
          dataMissing: analyticsFailed && ordersFailed),
      _stockInsight(lowStock, unknownStock,
          dataMissing: unavailable.contains('products')),
      _customerInsight(customers, orders, repeatCustomers,
          dataMissing: unavailable.contains('customers')),
      _orderFlowInsight(
        totalOrders,
        deliveryRatio,
        dataMissing: analyticsFailed && ordersFailed,
      ),
      _pendingValueInsight(orders, now,
          dataMissing: ordersFailed && orders.isEmpty),
    ];

    return AdvisorReport(
      generatedAt: now,
      orders: totalOrders,
      customers: customers.length,
      products: products.length,
      revenue: _number(analytics['revenue']),
      pendingPayments: pendingCount,
      deliveryRatio: deliveryRatio,
      repeatCustomers: repeatCustomers,
      lowStockCount: lowStock,
      lowStockUnknown: unknownStock,
      ordersExamined: orders.length,
      unavailable: unavailable,
      insights: insights,
      businessContext:
          'دار زخم بيت عطور فاخر: القرار التجاري يتأثر بالعطر والتركيز والحجم، وبالدفع المسبق والشحن للمحافظات، ثم بإعادة شراء العميل وثقته.',
      nextFocus: _nextFocus(
        products: products,
        customers: customers,
        orders: orders,
      ),
    );
  }

  /// قائمة التركيز التالية (من v2 حرفياً): ما الذي يحتاجه التحليل
  /// ليصبح أدق في الدورة التالية — بلا أي تغيير تلقائي في المتجر.
  List<String> _nextFocus({
    required List<dynamic> products,
    required List<dynamic> customers,
    required List<dynamic> orders,
  }) {
    final focus = <String>[];
    if (orders.isEmpty) {
      focus.add('ابدأ بتجميع تاريخ طلبات كافٍ قبل اتخاذ قرارات نمو قوية.');
    } else {
      focus.add('اربط كل طلب بالعطر والتركيز والحجم حتى يصبح التحليل تجاريًا لا عدديًا فقط.');
    }
    if (customers.isEmpty) {
      focus.add('فعّل تسجيل العملاء واستخدمه لبناء ذاكرة إعادة الشراء.');
    } else {
      focus.add('سجّل سبب الإلغاء أو عدم إعادة الشراء؛ هذه البيانات أهم من عدد الزيارات.');
    }
    if (products.isNotEmpty) {
      focus.add('أضف تكلفة المنتج والتغليف والشحن لحساب الربحية الحقيقية، لا الإيرادات فقط.');
    }
    focus.add('كل دورة تحديث تضيف قاعدة تحليل جديدة بعد مراجعة نتائجها، ولا تغيّر سلوك المتجر تلقائيًا.');
    return focus;
  }

  /// استدعاء واحد بمهلة ومعالجة مستقلة: عند الفشل يُسجَّل القسم
  /// في [unavailable] ويُرجع البديل بدل إسقاط التحليل كله.
  Future<T> _call<T>(
    String section,
    List<String> unavailable,
    Future<T> Function() fn,
    T fallback,
  ) async {
    try {
      return await fn().timeout(perCallTimeout);
    } catch (_) {
      unavailable.add(section);
      return fallback;
    }
  }

  /// صفحات قائمة الطلبات حتى 100 صف (4 صفحات × 25)؛ كل صفحة بمهلتها
  /// ومعالجتها المستقلة — فشل صفحة لاحقة يُبقي ما جُلب قبلها.
  Future<_OrderPages> _fetchOrderPages(List<String> unavailable) async {
    final rows = <Map<String, dynamic>>[];
    var bucketCounts = const <String, dynamic>{};
    var page = 1;
    var totalPages = 1;
    var failed = false;
    while (page <= totalPages &&
        page <= maxOrderPages &&
        rows.length < maxOrdersExamined) {
      try {
        final data = await api.orders(page: page).timeout(perCallTimeout);
        final pageRows = (data['orders'] as List?) ?? const [];
        rows.addAll(pageRows.whereType<Map<String, dynamic>>());
        if (page == 1) {
          final buckets = data['bucketCounts'];
          if (buckets is Map<String, dynamic>) bucketCounts = buckets;
        }
        totalPages = (data['totalPages'] as num?)?.toInt() ?? 1;
        if (pageRows.isEmpty) break;
      } catch (_) {
        failed = true;
        break;
      }
      page++;
    }
    if (failed && !unavailable.contains('orders')) {
      unavailable.add('orders');
    }
    return _OrderPages(
      rows: rows.take(maxOrdersExamined).toList(),
      bucketCounts: bucketCounts,
    );
  }

  static int _totalOrders(
    Map<String, dynamic> analytics,
    Map<String, dynamic> bucketCounts,
    int examined,
  ) {
    final fromAnalytics = analytics['orders'];
    if (fromAnalytics is num) return fromAnalytics.toInt();
    final fromBuckets = bucketCounts['all'];
    if (fromBuckets is num) return fromBuckets.toInt();
    return examined;
  }

  AdvisorInsight _paymentInsight(
    int pending, {
    required bool dataMissing,
  }) {
    if (dataMissing) {
      return const AdvisorInsight(
        title: 'بيانات الدفع غير متاحة',
        body:
            'تعذّر تحميل ملخص الدفع وقائمة الطلبات — تحقق من الاتصال وأعد المحاولة. باقي الإشارات مبنية على ما توفر.',
        priority: AdvisorPriority.data,
        icon: AdvisorIcon.payment,
      );
    }
    if (pending > 0) {
      return AdvisorInsight(
        title: 'أولوية اليوم: مراجعة الدفع',
        body:
            'يوجد $pending طلبًا ينتظر تأكيد الدفع. مراجعتها أولًا تمنع تعطّل التجهيز وتوضح التدفق النقدي الحقيقي.',
        priority: AdvisorPriority.urgent,
        icon: AdvisorIcon.payment,
      );
    }
    return const AdvisorInsight(
      title: 'تدفق الدفع مستقر',
      body:
          'لا توجد طلبات معلّقة ظاهرة في ملخص الخادم. راقب ذلك يوميًا قبل إطلاق أي حملة.',
      priority: AdvisorPriority.watch,
      icon: AdvisorIcon.payment,
    );
  }

  AdvisorInsight _stockInsight(
    int low,
    int unknown, {
    required bool dataMissing,
  }) {
    if (dataMissing) {
      return const AdvisorInsight(
        title: 'بيانات المخزون غير متاحة',
        body:
            'تعذّر تحميل بيانات المنتجات — تحقق من الاتصال وأعد المحاولة. باقي الإشارات مبنية على ما توفر.',
        priority: AdvisorPriority.data,
        icon: AdvisorIcon.inventory,
      );
    }
    if (low > 0) {
      return AdvisorInsight(
        title: 'مخزون يحتاج انتباهًا',
        body:
            'هناك $low منتجًا منخفض المخزون ($lowStockThreshold أو أقل). لا تطلق عرضًا واسعًا قبل مراجعة الأصناف المتأثرة.'
            '${unknown > 0 ? ' و$unknown منتجًا تعذّر تحديد مخزونه.' : ''}',
        priority: AdvisorPriority.high,
        icon: AdvisorIcon.inventory,
      );
    }
    if (unknown > 0) {
      return AdvisorInsight(
        title: 'تعذّر تحديد مخزون $unknown منتجًا',
        body:
            'بيانات المخزون غير مكتملة لبعض المنتجات (بلا stockQty ولا variantRows) — لم تُحتسب منخفضة. راجع المنتجات من لوحة الإدارة.',
        priority: AdvisorPriority.data,
        icon: AdvisorIcon.inventory,
      );
    }
    return const AdvisorInsight(
      title: 'المخزون لا يظهر خطرًا مباشرًا',
      body:
          'لم يعثر التحليل الحالي على أصناف منخفضة المخزون في البيانات المتاحة.',
      priority: AdvisorPriority.watch,
      icon: AdvisorIcon.inventory,
    );
  }

  AdvisorInsight _customerInsight(
    List<dynamic> customers,
    List<dynamic> orders,
    int repeat, {
    required bool dataMissing,
  }) {
    if (dataMissing) {
      return const AdvisorInsight(
        title: 'بيانات العملاء غير متاحة',
        body:
            'تعذّر تحميل قائمة العملاء — تحقق من الاتصال وأعد المحاولة. باقي الإشارات مبنية على ما توفر.',
        priority: AdvisorPriority.data,
        icon: AdvisorIcon.customers,
      );
    }
    if (repeat > 0) {
      return AdvisorInsight(
        title: 'قاعدة عملاء قابلة لإعادة الشراء',
        body:
            'يوجد $repeat عميلًا لديه طلبان أو أكثر. هؤلاء أفضل جمهور لتحليل إعادة الشراء بدل إرسال عرض عام للجميع.',
        priority: AdvisorPriority.opportunity,
        icon: AdvisorIcon.customers,
      );
    }
    return AdvisorInsight(
      title: 'البيانات تحتاج بناء ذاكرة العميل',
      body:
          'لم يظهر عدد كافٍ من العملاء المتكررين في البيانات الحالية (${customers.length} عميلًا و${orders.length} طلبًا مفحوصًا).',
      priority: AdvisorPriority.learning,
      icon: AdvisorIcon.customers,
    );
  }

  AdvisorInsight _orderFlowInsight(
    int total,
    double ratio, {
    required bool dataMissing,
  }) {
    if (dataMissing) {
      return const AdvisorInsight(
        title: 'بيانات مسار الطلبات غير متاحة',
        body:
            'تعذّر تحميل ملخص الطلبات وقائمتها — تحقق من الاتصال وأعد المحاولة. باقي الإشارات مبنية على ما توفر.',
        priority: AdvisorPriority.data,
        icon: AdvisorIcon.flow,
      );
    }
    if (total > 0 && ratio < deliveryRatioWarning) {
      return AdvisorInsight(
        title: 'التحدي في التحويل إلى تسليم',
        body:
            'نسبة الطلبات المسلّمة من الإجمالي الظاهر منخفضة (${(ratio * 100).round()}%). راجع أسباب التأخير والإلغاء قبل زيادة الإنفاق التسويقي.',
        priority: AdvisorPriority.diagnosis,
        icon: AdvisorIcon.flow,
      );
    }
    return const AdvisorInsight(
      title: 'مسار الطلبات تحت السيطرة',
      body:
          'لا تظهر النسبة الحالية إشارة تعطل حادة في الانتقال نحو التسليم. استمر في مراقبة المراحل أسبوعيًا.',
      priority: AdvisorPriority.watch,
      icon: AdvisorIcon.flow,
    );
  }

  /// إشارة محسوبة من المتاح: قيمة الطلبات بلا تأكيد دفع + عمر أقدم طلب
  /// معلق + توزيع المحافظات وطرق الدفع — من صفوف القائمة المفحوصة فقط
  /// (حتى 100 طلب)، ويُذكر النطاق في النص.
  AdvisorInsight _pendingValueInsight(
    List<dynamic> orders,
    DateTime now, {
    required bool dataMissing,
  }) {
    if (dataMissing) {
      return const AdvisorInsight(
        title: 'بيانات الطلبات غير متاحة',
        body:
            'تعذّر تحميل قائمة الطلبات — تحقق من الاتصال وأعد المحاولة. باقي الإشارات مبنية على ما توفر.',
        priority: AdvisorPriority.data,
        icon: AdvisorIcon.pending,
      );
    }
    final pending = orders
        .whereType<Map<String, dynamic>>()
        .where((o) => '${o['status'] ?? ''}' == 'pending_transfer')
        .toList();
    if (pending.isEmpty) {
      return const AdvisorInsight(
        title: 'لا طلبات معلقة بلا تأكيد',
        body:
            'لا توجد طلبات بانتظار تأكيد الدفع في الصفوف المفحوصة — القيمة المعلقة صفر.',
        priority: AdvisorPriority.watch,
        icon: AdvisorIcon.pending,
      );
    }
    var value = 0.0;
    DateTime? oldest;
    final governorates = <String, int>{};
    final methods = <String, int>{};
    for (final o in pending) {
      value += _number(o['total']);
      final created = DateTime.tryParse('${o['created_at'] ?? ''}');
      if (created != null && (oldest == null || created.isBefore(oldest))) {
        oldest = created;
      }
      final gov = '${o['governorate'] ?? ''}'.trim();
      if (gov.isNotEmpty) governorates[gov] = (governorates[gov] ?? 0) + 1;
      final method = '${o['payment_method'] ?? ''}'.trim();
      if (method.isNotEmpty) methods[method] = (methods[method] ?? 0) + 1;
    }
    final topGov = _topEntry(governorates);
    final topMethod = _topEntry(methods);
    final ageHours = oldest == null ? 0 : now.difference(oldest).inHours;
    final ageText = ageHours >= 24
        ? 'منذ ${ageHours ~/ 24} يوم'
        : 'منذ $ageHours ساعة';
    return AdvisorInsight(
      title: 'قيمة معلقة بلا تأكيد دفع',
      body:
          'قيمة الطلبات بلا تأكيد: ${value.toStringAsFixed(0)} ج.م في ${pending.length} طلبًا (من أول ${orders.length} طلب مفحوص). '
          'أقدم طلب معلق $ageText. '
          '${topGov == null ? '' : 'أكثر محافظة: $topGov. '}'
          '${topMethod == null ? '' : 'أكثر طريقة دفع: $topMethod.'}',
      priority: ageHours > pendingStaleHours
          ? AdvisorPriority.high
          : AdvisorPriority.opportunity,
      icon: AdvisorIcon.pending,
    );
  }

  static String? _topEntry(Map<String, int> counts) {
    if (counts.isEmpty) return null;
    final top = counts.entries.reduce(
      (a, b) => a.value >= b.value ? a : b,
    );
    return '${top.key} (${top.value})';
  }

  static int _countStatus(List<dynamic> orders, String status) => orders
      .where((item) => item is Map && '${item['status'] ?? ''}' == status)
      .length;

  static int _integer(dynamic value, int fallback) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? fallback;

  static double _number(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
}

class _OrderPages {
  const _OrderPages({required this.rows, required this.bucketCounts});

  final List<Map<String, dynamic>> rows;
  final Map<String, dynamic> bucketCounts;
}
