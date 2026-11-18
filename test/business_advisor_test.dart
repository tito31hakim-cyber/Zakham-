import 'package:flutter_test/flutter_test.dart';
import 'package:house_of_zakham/services/admin_api.dart';
import 'package:house_of_zakham/services/business_advisor.dart';

/// اختبارات خدمة مستشار دار زخم (ملفات المستخدم — قراءة وتحليل فقط).
///
/// تختبر المنطق الخالص ببيانات وهمية بنفس أشكال الخادم الحقيقية:
/// analytics() بمفاتيح orders/revenue/pending/delivered (بلا customers
/// إطلاقاً في api.php — الخدمة تتعامل مع ذلك بالرجوع إلى طول القائمة)،
/// وorders() بخريطة فيها مفتاح 'orders'، وcustomers() قائمة، وproducts()
/// بخرائط فيها stockQty/stockStatus.
///
/// ملاحظة سلوك موثقة (بلا تغيير في كود المستخدم): منتج بلا stockQty
/// يُقرأ صفراً فيُحتسب منخفض المخزون (0 <= 3).

class FakeAdminApi extends AdminApi {
  FakeAdminApi({
    required this.analyticsData,
    required this.ordersData,
    required this.customersData,
    required this.productsData,
  });

  final Map<String, dynamic> analyticsData;
  final Map<String, dynamic> ordersData;
  final List<dynamic> customersData;
  final List<dynamic> productsData;

  @override
  Future<Map<String, dynamic>> analytics() async => analyticsData;

  @override
  Future<Map<String, dynamic>> orders({
    String status = '',
    String governorate = '',
    String paymentMethod = '',
    String paymentStatus = '',
    String dateFrom = '',
    String dateTo = '',
    int page = 1,
  }) async =>
      ordersData;

  @override
  Future<List<dynamic>> customers([String query = '']) async => customersData;

  @override
  Future<List<dynamic>> products() async => productsData;
}

Map<String, dynamic> _order(String status) => {
      'order_ref': 'ZH-$status',
      'created_at': '2026-11-18 10:00:00',
      'total': 370,
      'status': status,
      'payment_status': 'unpaid',
      'payment_method': 'InstaPay | إنستاباي',
      'governorate': 'كفر الشيخ',
    };

void main() {
  group('تقرير المستشار — بيانات حية', () {
    late AdvisorReport report;

    setUp(() async {
      final api = FakeAdminApi(
        analyticsData: {
          'orders': 5,
          'revenue': 2400.0,
          'pending': 2,
          'delivered': 1,
        },
        ordersData: {
          'orders': [
            _order('pending_transfer'),
            _order('pending_transfer'),
            _order('delivered'),
            _order('paid'),
            _order('cancelled'),
          ],
          'total': 5,
          'page': 1,
          'totalPages': 1,
        },
        customersData: [
          {'displayName': 'أحمد', 'ordersCount': 3, 'ordersValue': 1500},
          {'displayName': 'منى', 'ordersCount': 1, 'ordersValue': 370},
          {'displayName': 'كريم', 'ordersCount': 0, 'ordersValue': 0},
        ],
        productsData: [
          {'id': 'layl', 'name': 'ليل زخم', 'stockQty': 2, 'stockStatus': 'in_stock'},
          {'id': 'royal', 'name': 'زخم رويال', 'stockQty': 10, 'stockStatus': 'in_stock'},
          {'id': 'elixir', 'name': 'إلكسير القوة', 'stockQty': 0, 'stockStatus': 'out_of_stock'},
        ],
      );
      report = await BusinessAdvisorService(api).analyze();
    });

    test('الملخص يأخذ الأرقام من analytics مع الرجوع للقوائم عند الغياب', () {
      expect(report.orders, 5);
      // مفتاح customers غائب من analytics في api.php — يرجع لطول القائمة.
      expect(report.customers, 3);
      expect(report.products, 3);
      expect(report.revenue, 2400);
      expect(report.pendingPayments, 2);
    });

    test('الإشارات الخمس موجودة بالترتيب: دفع/مخزون/عملاء/مسار/تشكيلة', () {
      expect(report.insights.length, 5);
      expect(
        report.insights.map((i) => i.icon).toList(),
        ['payment', 'inventory', 'customers', 'flow', 'catalog'],
      );
    });

    test('إشارة الدفع: طلبان بانتظار التأكيد — عاجل', () {
      final insight = report.insights[0];
      expect(insight.title, 'أولوية اليوم: مراجعة الدفع');
      expect(insight.priority, 'عاجل');
      expect(insight.body, contains('2'));
    });

    test('إشارة المخزون: منتجان منخفضان (كمية 2 + غير متاح)', () {
      final insight = report.insights[1];
      expect(insight.title, 'مخزون يحتاج انتباهًا');
      expect(insight.priority, 'مرتفع');
      expect(insight.body, contains('2'));
    });

    test('إشارة العملاء: عميل متكرر واحد — فرصة إعادة شراء', () {
      final insight = report.insights[2];
      expect(insight.title, 'قاعدة عملاء قابلة لإعادة الشراء');
      expect(insight.priority, 'فرصة');
      expect(insight.body, contains('1'));
    });

    test('إشارة المسار: نسبة تسليم 20% — تشخيص', () {
      final insight = report.insights[3];
      expect(insight.title, 'التحدي في التحويل إلى تسليم');
      expect(insight.priority, 'تشخيص');
      expect(insight.body, contains('20%'));
    });

    test('إشارة التشكيلة: 3 منتجات — جاهزة للتحليل العميق', () {
      final insight = report.insights[4];
      expect(insight.title, 'التشكيلة جاهزة للتحليل العميق');
      expect(insight.priority, 'فرصة');
      expect(insight.body, contains('3'));
    });
  });

  group('تقرير المستشار — حالات الفراغ', () {
    test('بلا بيانات إطلاقاً: أصفار وإشارات المراقبة/البيانات', () async {
      final api = FakeAdminApi(
        analyticsData: const {},
        ordersData: const {'orders': []},
        customersData: const [],
        productsData: const [],
      );
      final report = await BusinessAdvisorService(api).analyze();
      expect(report.orders, 0);
      expect(report.customers, 0);
      expect(report.products, 0);
      expect(report.revenue, 0);
      expect(report.pendingPayments, 0);
      expect(report.insights[0].title, 'تدفق الدفع مستقر');
      expect(report.insights[1].title, 'المخزون لا يظهر خطرًا مباشرًا');
      expect(
        report.insights[2].title,
        'البيانات تحتاج بناء ذاكرة العميل',
      );
      expect(report.insights[3].title, 'مسار الطلبات تحت السيطرة');
      expect(report.insights[4].title, 'لا توجد بيانات تشكيلة كافية');
    });

    test('غياب pending من analytics يرجع لعدّ الطلبات بانتظار التحويل', () async {
      final api = FakeAdminApi(
        analyticsData: {'orders': 2, 'revenue': 740.0, 'delivered': 0},
        ordersData: {
          'orders': [_order('pending_transfer'), _order('paid')],
        },
        customersData: const [],
        productsData: const [],
      );
      final report = await BusinessAdvisorService(api).analyze();
      expect(report.pendingPayments, 1);
      expect(report.insights[0].priority, 'عاجل');
    });

    test('منتج بلا stockQty يُحتسب منخفضاً (سلوك موثق في الخدمة)', () async {
      final api = FakeAdminApi(
        analyticsData: const {'orders': 0, 'revenue': 0},
        ordersData: const {'orders': []},
        customersData: const [],
        productsData: [
          {'id': 'x', 'name': 'بلا مخزون ظاهر'},
        ],
      );
      final report = await BusinessAdvisorService(api).analyze();
      expect(report.insights[1].title, 'مخزون يحتاج انتباهًا');
    });
  });
}
