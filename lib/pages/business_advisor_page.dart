import 'package:flutter/material.dart';

import '../services/admin_api.dart';
import '../services/business_advisor.dart';
import '../theme/app_theme.dart';

/// صفحة «مركز ذكاء دار زخم» — تُفتح مدفوعة من لوحة الإدارة (بطاقة
/// دخول)، لذلك لها Scaffold وAppBar خاصان. قراءة وتحليل فقط.

class BusinessAdvisorPage extends StatefulWidget {
  const BusinessAdvisorPage({super.key, required this.api});
  final AdminApi api;

  @override
  State<BusinessAdvisorPage> createState() => _BusinessAdvisorPageState();
}

class _BusinessAdvisorPageState extends State<BusinessAdvisorPage> {
  late Future<AdvisorReport> report;

  @override
  void initState() {
    super.initState();
    report = BusinessAdvisorService(widget.api).analyze();
  }

  /// يعيد Future يُنتظر حتى اكتمال التحليل الجديد — حتى لا يختفي
  /// مؤشر السحب للتحديث قبل وصول البيانات.
  Future<void> _refresh() async {
    final future = BusinessAdvisorService(widget.api).analyze();
    setState(() => report = future);
    try {
      await future;
    } catch (_) {
      // يعرض FutureBuilder حالة الخطأ الودودة أدناه.
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('مركز ذكاء دار زخم'),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث التحليل',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<AdvisorReport>(
          future: report,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _errorState();
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            return _content(context, snapshot.data!);
          },
        ),
      ),
    ),
  );

  /// حالة الخطأ: رسالة عربية واضحة بلا تفاصيل تقنية، مع إعادة المحاولة.
  Widget _errorState() => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      const SizedBox(height: 80),
      Icon(
        Icons.psychology_outlined,
        color: context.goldText,
        size: 64,
      ),
      const SizedBox(height: 18),
      Text(
        'تعذر بناء التحليل',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: context.ink,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
      const SizedBox(height: 10),
      Text(
        'تحقق من الاتصال بالإنترنت ومن جلسة الإدارة، ثم حاول مجدداً.',
        textAlign: TextAlign.center,
        style: TextStyle(color: context.subdued),
      ),
      const SizedBox(height: 18),
      FilledButton.icon(
        onPressed: _refresh,
        icon: const Icon(Icons.refresh),
        label: const Text('إعادة المحاولة'),
      ),
    ],
  );

  Widget _content(BuildContext context, AdvisorReport data) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
    children: [
      Row(
        children: [
          Icon(Icons.psychology_outlined, color: context.goldText, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'قراءة وتحليل فقط — لا ينفذ أي إجراء',
              style: TextStyle(color: context.subdued, fontSize: 13),
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      if (data.unavailable.isNotEmpty) ...[
        _unavailableBanner(context, data.unavailable),
        const SizedBox(height: 14),
      ],
      _summary(context, data),
      const SizedBox(height: 22),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'ماذا يحدث الآن؟',
            style: TextStyle(
              color: context.ink,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            'تحليل آلي',
            style: TextStyle(
              color: context.goldText,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      ...data.insights.map((insight) => _insightCard(context, insight)),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.goldText.withOpacity(.22)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, color: context.goldText),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'المستشار يقرأ بيانات الخادم الحالية ويعرض إشارات قابلة للمراجعة. لا يرسل رسائل، ولا يغير طلبات أو أسعارًا، ولا ينفذ أي قرار تلقائيًا.',
                style: TextStyle(color: context.subdued, height: 1.55),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Text(
        'آخر تحديث: ${_time(data.generatedAt)}',
        textAlign: TextAlign.center,
        style: TextStyle(color: context.subdued, fontSize: 11),
      ),
    ],
  );

  Widget _unavailableBanner(BuildContext context, List<String> sections) {
    const labels = {
      'analytics': 'الملخص',
      'orders': 'الطلبات',
      'customers': 'العملاء',
      'products': 'المنتجات',
    };
    final names = sections
        .map((s) => labels[s] ?? s)
        .join('، ');
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.withOpacity(.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.cloud_off_outlined, color: Colors.orange),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'أقسام غير متاحة الآن: $names — الإشارات المتأثرة معروضة كـ«غير متاح»، وباقي التحليل مبني على ما توفر.',
              style: TextStyle(color: context.ink, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  /// ملخص بما لا يظهر في شريط إحصاءات لوحة الإدارة: نسبة التسليم،
  /// العملاء المتكررون، منخفضو المخزون — مع نطاق الطلبات المفحوصة.
  Widget _summary(BuildContext context, AdvisorReport data) => Container(
    padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [context.goldText.withOpacity(.18), context.surfaceCard],
      ),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: context.goldText.withOpacity(.28)),
    ),
    child: Column(
      children: [
        Row(
          children: [
            _metric(
              context,
              'نسبة التسليم',
              '${(data.deliveryRatio * 100).round()}%',
              Icons.local_shipping_outlined,
            ),
            _metric(
              context,
              'عملاء متكررون',
              '${data.repeatCustomers}',
              Icons.people_outline,
            ),
            _metric(
              context,
              'منخفضو المخزون',
              '${data.lowStockCount}'
              '${data.lowStockUnknown > 0 ? ' (+${data.lowStockUnknown} مجهول)' : ''}',
              Icons.inventory_2_outlined,
            ),
          ],
        ),
        if (data.ordersExamined < data.orders) ...[
          const SizedBox(height: 10),
          Text(
            'الإشارات مبنية على أول ${data.ordersExamined} طلب من أصل ${data.orders} — المجاميع من ملخص الخادم.',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.subdued, fontSize: 11),
          ),
        ],
      ],
    ),
  );

  Widget _metric(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) => Expanded(
    child: Column(
      children: [
        Icon(icon, color: context.goldText, size: 22),
        const SizedBox(height: 5),
        Text(
          value,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: context.ink,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(color: context.subdued, fontSize: 10),
        ),
      ],
    ),
  );

  Widget _insightCard(BuildContext context, AdvisorInsight insight) {
    final urgent = insight.priority.isUrgent;
    final accent = insight.priority.color;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: context.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: urgent
              ? Colors.orange.withOpacity(.55)
              : context.goldText.withOpacity(.18),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: (urgent ? Colors.orange : accent).withOpacity(.13),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _icon(insight.icon),
              color: urgent ? Colors.orange : accent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: (urgent ? Colors.orange : accent)
                            .withOpacity(.13),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        insight.priority.label,
                        style: TextStyle(
                          color: urgent ? Colors.orange : accent,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      insight.title,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: context.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  insight.body,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: context.subdued,
                    height: 1.55,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _icon(AdvisorIcon key) => switch (key) {
    AdvisorIcon.payment => Icons.account_balance_wallet_outlined,
    AdvisorIcon.inventory => Icons.inventory_2_outlined,
    AdvisorIcon.customers => Icons.people_outline,
    AdvisorIcon.flow => Icons.timeline_outlined,
    AdvisorIcon.pending => Icons.pending_actions_outlined,
  };

  String _time(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}
