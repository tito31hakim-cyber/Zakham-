import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:house_of_zakham/pages/business_advisor_page.dart';
import 'package:house_of_zakham/services/admin_api.dart';
import 'package:house_of_zakham/services/api_headers.dart';
import 'package:house_of_zakham/services/research_sync_api.dart';
import 'package:house_of_zakham/theme/app_theme.dart';

/// اختبارات واجهة خلاصة «بحث وابتكار» في مركز الذكاء.
///
/// لا استدعاء شبكة حقيقي إطلاقاً: الردود من `MockClient`، وتحليل
/// المتجر من `FakeAdminApi` ببيانات وهمية بنفس أشكال الخادم.
/// ما يثبته الاختبار:
/// - عند تعذّر تحميل مسودات الميكسات تُعرض آخر خلاصة محفوظة بتاريخها
///   مع تنبيه، ولا تظهر رسالة التعذر الجافة.
/// - عند غياب أي خلاصة محفوظة (فشل ملخص المعرفة) تظهر رسالة التعذر.
/// - عند عدم بدء أي دورة بعد تظهر رسالة هادئة تشرح أن البدء معلّق،
///   لا رسالة تعذر.
/// - تنبيهات الإرشاد وحماية البيانات تبقى كما هي: المسودات غير
///   معتمدة حتى مراجعتها بشرياً، وبلا نسب كاملة ولا موردين ولا تكاليف.
///
/// ملاحظتان عن الاختبار:
/// - القسم أسفل قائمة طويلة تُبنى كسولاً (ListView)، فتُرفع نافذة
///   الاختبار إلى 8000 بكسل منطقي حتى تُبنى كل العناصر بلا تمرير —
///   ونافذة الاختبار بكثافة 3.0 فالحجم الفيزيائي 2400×24000.
/// - بطاقة الزكاة تقرأ SharedPreferences عند بنائها، فتُهيَّأ قيم
///   وهمية فارغة وإلا بقي مؤشر التحميل يدور أبداً.
/// - في حالة غياب الخلاصة تُؤخَّر ردود البحث 500ms حتى يشترك
///   FutureBuilder قبل اكتمال المستقبل بخطأ؛ وإلا أُبلغ الخطأ
///   كغير معالَج قبل بناء القسم (نافذة قديمة في الصفحة: المستقبل
///   يُنشأ في initState بينما القسم يُبنى بعد اكتمال التحليل).

http.Response _jsonResponse(Object body, int status) =>
    http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

Map<String, dynamic> _trialRunSummary() => {
      'lastRun': {
        'run_key': 'trial-run-001',
        'started_at': '2026-11-19T11:46:00Z',
        'status': 'review',
        'sources_found': 1,
        'sources_accepted': 1,
        'new_materials': 2,
        'new_mixes': 1,
        'agent_version': '0.1.0',
      },
    };

ResearchSyncApi _researchApi({
  required bool mixesFail,
  bool summaryFail = false,
  bool summaryEmpty = false,
  Duration delay = Duration.zero,
}) =>
    ResearchSyncApi(
      credentials: const ApiCredentials(),
      client: MockClient((request) async {
        if (delay != Duration.zero) await Future.delayed(delay);
        if (request.url.path.endsWith('/mixes')) {
          if (mixesFail) return http.Response('', 500);
          return _jsonResponse({'mixes': []}, 200);
        }
        if (request.url.path.endsWith('/knowledge-summary')) {
          if (summaryFail) return http.Response('', 500);
          if (summaryEmpty) return _jsonResponse({}, 200);
          return _jsonResponse(_trialRunSummary(), 200);
        }
        return http.Response('', 404);
      }),
    );

String _ts(DateTime t) =>
    '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')} '
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

Map<String, dynamic> _order(
  String status, {
  int total = 370,
  DateTime? createdAt,
}) =>
    {
      'order_ref': 'ZH-$status-${createdAt?.millisecondsSinceEpoch ?? 0}',
      'created_at': _ts(createdAt ?? DateTime.now()),
      'total': total,
      'status': status,
      'payment_status': 'unpaid',
      'payment_method': 'InstaPay | إنستاباي',
      'governorate': 'كفر الشيخ',
    };

class _FakeAdminApi extends AdminApi {
  _FakeAdminApi({required this.researchApi});

  final ResearchSyncApi researchApi;

  @override
  ResearchSyncApi get researchSyncApi => researchApi;

  @override
  Future<Map<String, dynamic>> analytics() async => {
        'orders': 5,
        'revenue': 2400.0,
        'pending': 2,
        'delivered': 1,
      };

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
    final recent = DateTime.now().subtract(const Duration(hours: 5));
    final all = [
      _order('pending_transfer', createdAt: recent),
      _order('pending_transfer', createdAt: recent),
      _order('delivered', createdAt: recent, total: 620),
      _order('paid', createdAt: recent, total: 500),
      _order('cancelled', createdAt: recent, total: 250),
    ];
    return {
      'orders': all,
      'total': all.length,
      'page': page,
      'totalPages': 1,
      'bucketCounts': {
        'all': 5,
        'waiting_payment': 2,
        'in_progress': 2,
        'completed': 1,
        'archive': 1,
      },
    };
  }

  @override
  Future<List<dynamic>> customers([String query = '']) async => [
        {'displayName': 'أحمد', 'ordersCount': 3, 'ordersValue': 1500},
        {'displayName': 'منى', 'ordersCount': 1, 'ordersValue': 370},
        {'displayName': 'كريم', 'ordersCount': 0, 'ordersValue': 0},
      ];

  @override
  Future<List<dynamic>> products() async => [
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
}

Future<void> _pumpPage(WidgetTester tester, AdminApi api) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  // نافذة الاختبار بكثافة 3.0: 2400×24000 فيزيائي = 800×8000 منطقي.
  tester.view.physicalSize = const Size(2400, 24000);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    MaterialApp(theme: AppTheme.dark(), home: BusinessAdvisorPage(api: api)),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('تعذّر الميكسات يعرض آخر خلاصة محفوظة بتاريخها',
      (tester) async {
    await _pumpPage(
      tester,
      _FakeAdminApi(researchApi: _researchApi(mixesFail: true)),
    );

    expect(
      find.textContaining('تعذّر تحميل خلاصة البحث حالياً'),
      findsNothing,
    );
    expect(
      find.textContaining('آخر خلاصة محفوظة بتاريخ 19/11/2026'),
      findsOneWidget,
    );
    expect(
      find.textContaining('آخر دورة بحث — 19/11/2026'),
      findsOneWidget,
    );
    // تنبيهات الإرشاد وحماية البيانات تبقى كما هي.
    expect(
      find.textContaining('مسودات للمراجعة فقط'),
      findsWidgets,
    );
    expect(
      find.textContaining('المسودات غير معتمدة حتى مراجعتها بشرياً'),
      findsOneWidget,
    );
  });

  testWidgets('غياب الخلاصة المحفوظة يعرض رسالة التعذر', (tester) async {
    await _pumpPage(
      tester,
      _FakeAdminApi(
        researchApi: _researchApi(
          mixesFail: true,
          summaryFail: true,
          delay: const Duration(milliseconds: 500),
        ),
      ),
    );

    expect(
      find.textContaining('تعذّر تحميل خلاصة البحث حالياً'),
      findsOneWidget,
    );
    expect(find.textContaining('آخر خلاصة محفوظة'), findsNothing);
  });

  testWidgets('عدم بدء أي دورة يعرض رسالة هادئة لا رسالة تعذر',
      (tester) async {
    await _pumpPage(
      tester,
      _FakeAdminApi(
        researchApi: _researchApi(mixesFail: false, summaryEmpty: true),
      ),
    );

    expect(
      find.textContaining('تعذّر تحميل خلاصة البحث حالياً'),
      findsNothing,
    );
    expect(
      find.textContaining('لم تبدأ الدورة الأسبوعية بعد'),
      findsOneWidget,
    );
    expect(
      find.textContaining('مراجعة المالك للدورة التجريبية'),
      findsOneWidget,
    );
    expect(
      find.textContaining('رمز المصادقة'),
      findsOneWidget,
    );
    expect(find.textContaining('آخر دورة بحث'), findsNothing);
  });
}
