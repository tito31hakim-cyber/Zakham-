import 'package:flutter_test/flutter_test.dart';
import 'package:house_of_zakham/services/admin_api.dart';
import 'package:house_of_zakham/services/business_advisor.dart';

/// اختبارات خدمة مستشار دار زخم (ملفات المستخدم بعد الضبط الاحترافي).
///
/// تختبر المنطق الخالص ببيانات وهمية بنفس أشكال الخادم الحقيقية:
/// analytics() بمفاتيح orders/revenue/pending/delivered (بلا customers
/// إطلاقاً في api.php — الخدمة تتعامل مع ذلك بالرجوع إلى طول القائمة)،
/// وorders() بخريطة فيها مفتاح 'orders' + totalPages + bucketCounts،
/// وcustomers() قائمة، وproducts() بخرائط فيها stockQty أو variantRows.
///
/// ملاحظات سلوك موثقة:
/// - منتج بلا stockQty ولا variantRows مخزونه «مجهول» ولا يُعدّ منخفضاً.
/// - قائمة الطلبات تُفحص حتى 100 صف؛ والمجاميع من analytics/bucketCounts.

String _ts(DateTime t) =>
    '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')} '
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

Map<String, dynamic> _order(
  String status, {
  int total = 370,
  String governorate = 'كفر الشيخ',
  String method = 'InstaPay | إنستاباي',
  DateTime? createdAt,
}) => {
      'order_ref': 'ZH-$status-${createdAt?.millisecondsSinceEpoch ?? 0}',
      'created_at': _ts(createdAt ?? DateTime.now()),
      'total': total,
      'status': status,
      'payment_status': 'unpaid',
      'payment_method': method,
      'governorate': governorate,
    };

class FakeAdminApi extends AdminApi {
  FakeAdminApi({
    required this.analyticsData,
    required this.allOrders,
    required this.customersData,
    required this.productsData,
    this.failSections = const {},
  });

  final Map<String, dynamic> analyticsData;
  final List<Map<String, dynamic>> allOrders;
  final List<dynamic> customersData;
  final List<dynamic> productsData;
  final Set<String> failSections;

  @override
  Future<Map<String, dynamic>> analytics() async {
    if (failSections.contains('analytics')) {
      throw Exception('analytics down');
    }
    return analyticsData;
  }

  @override
  Future<Map<String, dynamic>> orders({
    String status = '',
    String governorate = '',
    String paymentMethod = '',
    String paymentStatus = '',
    String dateFrom = '',
    String dateTo = '',
    int page = 1,
  }) async {
    if (failSections.contains('orders')) throw Exception('orders down');
    const pageSize = 25;
    final start = (page - 1) * pageSize;
    final end = start + pageSize > allOrders.length
        ? allOrders.length
        : start + pageSize;
    final slice = start < allOrders.length
        ? allOrders.sublist(start, end)
        : const <Map<String, dynamic>>[];
    final totalPages =
        (allOrders.length / pageSize).ceil().clamp(1, 1000000);
    return {
      'orders': slice,
      'total': allOrders.length,
      'page': page,
      'totalPages': totalPages,
      'bucketCounts': {
        'all': allOrders.length,
        'waiting_payment': allOrders
            .where((o) => o['status'] == 'pending_transfer')
            .length,
        'in_progress': allOrders
            .where((o) =>
                ['paid', 'processing', 'shipped'].contains(o['status']))
            .length,
        'completed':
            allOrders.where((o) => o['status'] == 'delivered').length,
        'archive':
            allOrders.where((o) => o['status'] == 'cancelled').length,
      },
    };
  }

  @override
  Future<List<dynamic>> customers([String query = '']) async {
    if (failSections.contains('customers')) {
      throw Exception('customers down');
    }
    return customersData;
  }

  @override
  Future<List<dynamic>> products() async {
    if (failSections.contains('products')) throw Exception('products down');
    return productsData;
  }
}

List<Map<String, dynamic>> _fiveOrders(DateTime recent) => [
      _order('pending_transfer', createdAt: recent, total: 370),
      _order('pending_transfer', createdAt: recent, total: 370),
      _order('delivered',
          createdAt: recent, total: 620, governorate: 'القاهرة'),
      _order('paid', createdAt: recent, total: 500, governorate: 'الجيزة'),
      _order('cancelled', createdAt: recent, total: 250),
    ];

List<dynamic> _threeCustomers() => [
      {'displayName': 'أحمد', 'ordersCount': 3, 'ordersValue': 1500},
      {'displayName': 'منى', 'ordersCount': 1, 'ordersValue': 370},
      {'displayName': 'كريم', 'ordersCount': 0, 'ordersValue': 0},
    ];

List<dynamic> _threeProducts() => [
      {
        'id': 'layl',
        'name': 'ليل زخم',
        'stockQty': 2,
        'stockStatus': 'in_stock',
      },
      {
        'id': 'royal',
        'name': 'زخم رويال',
        'stockQty': 10,
        'stockStatus': 'in_stock',
      },
      {
        'id': 'elixir',
        'name': 'إلكسير القوة',
        'stockQty': 0,
        'stockStatus': 'out_of_stock',
      },
    ];

Future<AdvisorReport> _analyze({
  Map<String, dynamic>? analytics,
  List<Map<String, dynamic>>? orders,
  List<dynamic>? customers,
  List<dynamic>? products,
  Set<String> fail = const {},
}) {
  final recent = DateTime.now().subtract(const Duration(hours: 5));
  return BusinessAdvisorService(
    FakeAdminApi(
      analyticsData: analytics ??
          {
            'orders': 5,
            'revenue': 2400.0,
            'pending': 2,
            'delivered': 1,
          },
      allOrders: orders ?? _fiveOrders(recent),
      customersData: customers ?? _threeCustomers(),
      productsData: products ?? _threeProducts(),
      failSections: fail,
    ),
  ).analyze();
}

void main() {
  group('تقرير المستشار — بيانات حية', () {
    late AdvisorReport report;

    setUp(() async {
      report = await _analyze();
    });

    test('الملخص: من analytics مع الرجوع للقوائم عند الغياب', () {
      expect(report.orders, 5);
      // مفتاح customers غائب من analytics في api.php — يرجع لطول القائمة.
      expect(report.customers, 3);
      expect(report.products, 3);
      expect(report.revenue, 2400);
      expect(report.pendingPayments, 2);
      expect(report.deliveryRatio, closeTo(0.2, 0.001));
      expect(report.repeatCustomers, 1);
      expect(report.lowStockCount, 2);
      expect(report.lowStockUnknown, 0);
      expect(report.ordersExamined, 5);
      expect(report.unavailable, isEmpty);
    });

    test('الإشارات الخمس بالترتيب وبالـ enum', () {
      expect(report.insights.length, 5);
      expect(
        report.insights.map((i) => i.icon).toList(),
        [
          AdvisorIcon.payment,
          AdvisorIcon.inventory,
          AdvisorIcon.customers,
          AdvisorIcon.flow,
          AdvisorIcon.pending,
        ],
      );
      expect(
        report.insights.map((i) => i.priority).toList(),
        [
          AdvisorPriority.urgent,
          AdvisorPriority.high,
          AdvisorPriority.opportunity,
          AdvisorPriority.diagnosis,
          AdvisorPriority.opportunity,
        ],
      );
    });

    test('إشارة الدفع: طلبان بانتظار التأكيد — عاجل', () {
      final insight = report.insights[0];
      expect(insight.title, 'أولوية اليوم: مراجعة الدفع');
      expect(insight.priority, AdvisorPriority.urgent);
      expect(insight.priority.label, 'عاجل');
      expect(insight.priority.isUrgent, isTrue);
      expect(insight.body, contains('2'));
    });

    test('إشارة المخزون: منتجان منخفضان (كمية 2 + صفر)', () {
      final insight = report.insights[1];
      expect(insight.title, 'مخزون يحتاج انتباهًا');
      expect(insight.priority, AdvisorPriority.high);
      expect(insight.body, contains('2'));
    });

    test('إشارة العملاء: عميل متكرر واحد — فرصة', () {
      final insight = report.insights[2];
      expect(insight.title, 'قاعدة عملاء قابلة لإعادة الشراء');
      expect(insight.priority, AdvisorPriority.opportunity);
      expect(insight.body, contains('1'));
    });

    test('إشارة المسار: نسبة تسليم 20% — تشخيص', () {
      final insight = report.insights[3];
      expect(insight.title, 'التحدي في التحويل إلى تسليم');
      expect(insight.priority, AdvisorPriority.diagnosis);
      expect(insight.body, contains('20%'));
    });

    test('إشارة القيمة المعلقة: 740 ج.م + أقدم طلب + توزيع', () {
      final insight = report.insights[4];
      expect(insight.title, 'قيمة معلقة بلا تأكيد دفع');
      expect(insight.body, contains('740'));
      expect(insight.body, contains('2 طلبًا'));
      expect(insight.body, contains('كفر الشيخ'));
      expect(insight.body, contains('إنستاباي'));
      expect(insight.body, contains('من أول 5 طلب مفحوص'));
      expect(insight.body, contains('منذ 5 ساعة'));
    });
  });

  group('تقرير المستشار — حالات الفراغ', () {
    test('بلا بيانات إطلاقاً: أصفار وإشارات المراقبة', () async {
      final report = await _analyze(
        analytics: const {},
        orders: const [],
        customers: const [],
        products: const [],
      );
      expect(report.orders, 0);
      expect(report.customers, 0);
      expect(report.products, 0);
      expect(report.revenue, 0);
      expect(report.pendingPayments, 0);
      expect(report.deliveryRatio, 0);
      expect(report.ordersExamined, 0);
      expect(report.insights[0].title, 'تدفق الدفع مستقر');
      expect(report.insights[0].priority, AdvisorPriority.watch);
      expect(report.insights[1].title, 'المخزون لا يظهر خطرًا مباشرًا');
      expect(
        report.insights[2].title,
        'البيانات تحتاج بناء ذاكرة العميل',
      );
      expect(report.insights[2].priority, AdvisorPriority.learning);
      expect(report.insights[3].title, 'مسار الطلبات تحت السيطرة');
      expect(report.insights[4].title, 'لا طلبات معلقة بلا تأكيد');
    });
  });

  group('تقرير المستشار — تدهور جزئي عند فشل استدعاء', () {
    test('فشل المنتجات وحدها: إشارة مخزون «غير متاحة» وباقي التحليل سليم', () async {
      final report = await _analyze(fail: {'products'});
      expect(report.unavailable, ['products']);
      expect(report.insights[1].title, 'بيانات المخزون غير متاحة');
      expect(report.insights[1].priority, AdvisorPriority.data);
      expect(report.insights[0].priority, AdvisorPriority.urgent);
      expect(report.orders, 5);
    });

    test('فشل analytics وحدها: المجاميع من bucketCounts والقوائم', () async {
      final report = await _analyze(fail: {'analytics'});
      expect(report.unavailable, ['analytics']);
      expect(report.orders, 5);
      expect(report.pendingPayments, 2);
      expect(report.revenue, 0);
      expect(report.insights[0].priority, AdvisorPriority.urgent);
    });

    test('فشل الطلبات وحدها: إشارة القيمة «غير متاحة» والدفع من analytics', () async {
      final report = await _analyze(fail: {'orders'});
      expect(report.unavailable, ['orders']);
      expect(report.ordersExamined, 0);
      expect(report.pendingPayments, 2);
      expect(report.insights[4].title, 'بيانات الطلبات غير متاحة');
      expect(report.insights[0].priority, AdvisorPriority.urgent);
    });

    test('فشل الأربعة معاً: لا استثناء — كل الإشارات «غير متاحة»', () async {
      final report = await _analyze(
        fail: {'analytics', 'orders', 'customers', 'products'},
      );
      expect(report.unavailable.length, 4);
      expect(report.orders, 0);
      for (final insight in report.insights) {
        expect(insight.priority, AdvisorPriority.data);
        expect(insight.title, contains('غير متاحة'));
      }
    });
  });

  group('المخزون — اشتقاق من variantRows والمجهول لا منخفض', () {
    test('بلا stockQty: يُشتق من variantRows النشطة فقط', () async {
      final report = await _analyze(
        products: [
          {
            'id': 'a',
            'name': 'أ',
            'variantRows': [
              {'size_ml': 50, 'concentration_key': 'presence', 'stock_qty': 2, 'is_active': 1},
              {'size_ml': 100, 'concentration_key': 'presence', 'stock_qty': 1, 'is_active': 1},
              {'size_ml': 100, 'concentration_key': 'nuclear', 'stock_qty': 10, 'is_active': 0},
            ],
          },
          {'id': 'b', 'name': 'ب'},
          {'id': 'c', 'name': 'ج', 'stockQty': '2'},
        ],
      );
      // أ: 2+1=3 منخفض؛ ب: مجهول؛ ج: نص '2' منخفض.
      expect(report.lowStockCount, 2);
      expect(report.lowStockUnknown, 1);
      expect(report.insights[1].title, 'مخزون يحتاج انتباهًا');
      expect(report.insights[1].body, contains('تعذّر تحديد مخزونه'));
    });

    test('كل المخزون مجهول: إشارة «تعذر تحديد» لا «منخفض»', () async {
      final report = await _analyze(
        products: [
          {'id': 'a', 'name': 'أ'},
          {'id': 'b', 'name': 'ب', 'variantRows': []},
        ],
      );
      expect(report.lowStockCount, 0);
      expect(report.lowStockUnknown, 2);
      expect(report.insights[1].title, 'تعذّر تحديد مخزون 2 منتجًا');
      expect(report.insights[1].priority, AdvisorPriority.data);
    });
  });

  group('نطاق الطلبات — صفحات حتى 100 والمجاميع من analytics', () {
    test('60 طلباً: تُفحص كلها (3 صفحات)', () async {
      final orders = List.generate(
        60,
        (i) => _order(i % 2 == 0 ? 'paid' : 'delivered',
            createdAt: DateTime.now()),
      );
      final report = await _analyze(
        analytics: {'orders': 60, 'revenue': 10000.0, 'pending': 0, 'delivered': 30},
        orders: orders,
      );
      expect(report.ordersExamined, 60);
      expect(report.orders, 60);
    });

    test('120 طلباً: السقف 100 والمجموع الكلي من analytics', () async {
      final orders = List.generate(
        120,
        (i) => _order(i % 2 == 0 ? 'paid' : 'delivered',
            createdAt: DateTime.now()),
      );
      final report = await _analyze(
        analytics: {'orders': 120, 'revenue': 20000.0, 'pending': 0, 'delivered': 60},
        orders: orders,
      );
      expect(report.ordersExamined, 100);
      expect(report.orders, 120);
    });

    test('طلب معلق قديم 5 أيام يصعّد الأولوية إلى مرتفع', () async {
      final old = DateTime.now().subtract(const Duration(days: 5));
      final report = await _analyze(
        orders: [_order('pending_transfer', createdAt: old, total: 900)],
      );
      final insight = report.insights[4];
      expect(insight.priority, AdvisorPriority.high);
      expect(insight.body, contains('منذ 5 يوم'));
      expect(insight.body, contains('900'));
    });
  });
}
