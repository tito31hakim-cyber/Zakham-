import 'admin_api.dart';

class AdvisorInsight {
  const AdvisorInsight({
    required this.title,
    required this.body,
    required this.priority,
    required this.icon,
  });

  final String title;
  final String body;
  final String priority;
  final String icon;
}

class AdvisorReport {
  const AdvisorReport({
    required this.generatedAt,
    required this.orders,
    required this.customers,
    required this.products,
    required this.revenue,
    required this.pendingPayments,
    required this.insights,
  });

  final DateTime generatedAt;
  final int orders;
  final int customers;
  final int products;
  final double revenue;
  final int pendingPayments;
  final List<AdvisorInsight> insights;
}

class BusinessAdvisorService {
  const BusinessAdvisorService(this.api);

  final AdminApi api;

  Future<AdvisorReport> analyze() async {
    final results = await Future.wait<dynamic>([
      api.analytics(),
      api.orders(),
      api.customers(),
      api.products(),
    ]);
    final analytics = Map<String, dynamic>.from(results[0] as Map);
    final orderPage = Map<String, dynamic>.from(results[1] as Map);
    final customers = List<dynamic>.from(results[2] as List);
    final products = List<dynamic>.from(results[3] as List);
    final orders = List<dynamic>.from(orderPage['orders'] as List? ?? const []);

    final insights = <AdvisorInsight>[
      _paymentInsight(analytics, orders),
      _stockInsight(products),
      _customerInsight(customers, orders),
      _orderFlowInsight(analytics, orders),
      _catalogInsight(products),
    ];

    return AdvisorReport(
      generatedAt: DateTime.now(),
      orders: _integer(analytics['orders'], orders.length),
      customers: _integer(analytics['customers'], customers.length),
      products: products.length,
      revenue: _number(analytics['revenue']),
      pendingPayments: _integer(
        analytics['pending'],
        _countStatus(orders, 'pending_transfer'),
      ),
      insights: insights,
    );
  }

  AdvisorInsight _paymentInsight(
    Map<String, dynamic> analytics,
    List<dynamic> orders,
  ) {
    final pending = _integer(
      analytics['pending'],
      _countStatus(orders, 'pending_transfer'),
    );
    if (pending > 0) {
      return AdvisorInsight(
        title: 'أولوية اليوم: مراجعة الدفع',
        body:
            'يوجد $pending طلبًا ينتظر تأكيد الدفع. مراجعتها أولًا تمنع تعطّل التجهيز وتوضح التدفق النقدي الحقيقي.',
        priority: 'عاجل',
        icon: 'payment',
      );
    }
    return const AdvisorInsight(
      title: 'تدفق الدفع مستقر',
      body: 'لا توجد طلبات معلّقة ظاهرة في ملخص الخادم. راقب ذلك يوميًا قبل إطلاق أي حملة.',
      priority: 'مراقبة',
      icon: 'payment',
    );
  }

  AdvisorInsight _stockInsight(List<dynamic> products) {
    final low = products.where((item) {
      final product = item is Map ? item : const <String, dynamic>{};
      final qty = _number(product['stockQty']);
      final status = '${product['stockStatus'] ?? ''}'.toLowerCase();
      return status.contains('out') || (qty >= 0 && qty <= 3);
    }).length;
    if (low > 0) {
      return AdvisorInsight(
        title: 'مخزون يحتاج انتباهًا',
        body:
            'هناك $low منتجًا منخفض المخزون أو غير متاح. لا تطلق عرضًا واسعًا قبل مراجعة الأصناف المتأثرة.',
        priority: 'مرتفع',
        icon: 'inventory',
      );
    }
    return const AdvisorInsight(
      title: 'المخزون لا يظهر خطرًا مباشرًا',
      body: 'لم يعثر التحليل الحالي على أصناف منخفضة المخزون في البيانات المتاحة.',
      priority: 'مراقبة',
      icon: 'inventory',
    );
  }

  AdvisorInsight _customerInsight(
    List<dynamic> customers,
    List<dynamic> orders,
  ) {
    final repeat = customers.where((item) {
      if (item is! Map) return false;
      final value = item['ordersCount'] ?? item['orders_count'] ?? 0;
      return _number(value) >= 2;
    }).length;
    if (repeat > 0) {
      return AdvisorInsight(
        title: 'قاعدة عملاء قابلة لإعادة الشراء',
        body:
            'يوجد $repeat عميلًا لديه طلبان أو أكثر. هؤلاء أفضل جمهور لتحليل إعادة الشراء بدل إرسال عرض عام للجميع.',
        priority: 'فرصة',
        icon: 'customers',
      );
    }
    return AdvisorInsight(
      title: 'البيانات تحتاج بناء ذاكرة العميل',
      body:
          'لم يظهر عدد كافٍ من العملاء المتكررين في البيانات الحالية (${customers.length} عميلًا و${orders.length} طلبًا مفحوصًا).',
      priority: 'تعلم',
      icon: 'customers',
    );
  }

  AdvisorInsight _orderFlowInsight(
    Map<String, dynamic> analytics,
    List<dynamic> orders,
  ) {
    final delivered = _integer(
      analytics['delivered'],
      _countStatus(orders, 'delivered'),
    );
    final total = _integer(analytics['orders'], orders.length);
    final ratio = total == 0 ? 0 : delivered / total;
    if (total > 0 && ratio < .35) {
      return AdvisorInsight(
        title: 'التحدي في التحويل إلى تسليم',
        body:
            'نسبة الطلبات المسلّمة من الإجمالي الظاهر منخفضة (${(ratio * 100).round()}%). راجع أسباب التأخير والإلغاء قبل زيادة الإنفاق التسويقي.',
        priority: 'تشخيص',
        icon: 'flow',
      );
    }
    return const AdvisorInsight(
      title: 'مسار الطلبات تحت السيطرة',
      body: 'لا تظهر النسبة الحالية إشارة تعطل حادة في الانتقال نحو التسليم. استمر في مراقبة المراحل أسبوعيًا.',
      priority: 'مراقبة',
      icon: 'flow',
    );
  }

  AdvisorInsight _catalogInsight(List<dynamic> products) {
    if (products.isEmpty) {
      return const AdvisorInsight(
        title: 'لا توجد بيانات تشكيلة كافية',
        body: 'يحتاج المستشار إلى بيانات المنتجات حتى يقارن الطلب بالمخزون والتشكيلة.',
        priority: 'بيانات',
        icon: 'catalog',
      );
    }
    return AdvisorInsight(
      title: 'التشكيلة جاهزة للتحليل العميق',
      body:
          'تم تحميل ${products.length} منتجًا. الخطوة التالية المنطقية هي ربط المبيعات لكل حجم وتركيز لاكتشاف الأكثر ربحية.',
      priority: 'فرصة',
      icon: 'catalog',
    );
  }

  static int _countStatus(List<dynamic> orders, String status) => orders
      .where((item) => item is Map && '${item['status'] ?? ''}' == status)
      .length;
  static int _integer(dynamic value, int fallback) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? fallback;
  static double _number(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
}
