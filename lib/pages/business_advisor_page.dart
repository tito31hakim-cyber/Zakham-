import 'package:flutter/material.dart';

import '../services/admin_api.dart';
import '../services/business_advisor.dart';
import '../theme/app_theme.dart';

/// مركز ذكاء دار زخم — قراءة وتحليل فقط (ملفات المستخدم v2 بعد ضبط).
///
/// تُفتح مدفوعة من بطاقة دخول أعلى لوحة الإدارة؛ فتُبنى عند فتحها فقط
/// (تحميل كسول) ولا يُستدعى [BusinessAdvisorService.analyze] عند فتح
/// الإدارة نفسها.

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

  /// يُنتظر حتى اكتمال التحليل الجديد حتى لا يختفي مؤشر السحب مبكراً.
  Future<void> _refresh() async {
    final future = BusinessAdvisorService(widget.api).analyze();
    setState(() => report = future);
    try {
      await future;
    } catch (_) {
      // يلتقطها FutureBuilder ويعرض حالة الخطأ الودودة.
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
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'تحديث التحليل',
              ),
            ],
          ),
          body: FutureBuilder<AdvisorReport>(
            future: report,
            builder: (context, snapshot) {
              if (snapshot.hasError) return _errorState(context);
              if (!snapshot.hasData) return _loadingState(context);
              return RefreshIndicator(
                color: context.goldText,
                onRefresh: _refresh,
                child: _content(context, snapshot.data!),
              );
            },
          ),
        ),
      );

  Widget _loadingState(BuildContext context) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(22),
        children: [
          const SizedBox(height: 110),
          Icon(Icons.auto_awesome, color: context.goldText, size: 56),
          const SizedBox(height: 18),
          Text('يقرأ المستشار بيانات المتجر…', textAlign: TextAlign.center, style: TextStyle(color: context.ink, fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Text('يجمع الطلبات والعملاء والمنتجات لبناء صورة عملية عن وضع دار زخم.', textAlign: TextAlign.center, style: TextStyle(color: context.subdued, height: 1.5)),
          const SizedBox(height: 22),
          const Center(child: CircularProgressIndicator()),
        ],
      );

  /// رسالة عربية واضحة بلا نص استثناء خام، مع زر إعادة المحاولة.
  Widget _errorState(BuildContext context) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(22),
        children: [
          const SizedBox(height: 80),
          Icon(Icons.cloud_off_outlined, color: context.goldText, size: 58),
          const SizedBox(height: 18),
          Text('تعذر بناء التحليل', textAlign: TextAlign.center, style: TextStyle(color: context.ink, fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Text('تحقق من الاتصال بالإنترنت ومن جلسة الإدارة، ثم حاول مجدداً.', textAlign: TextAlign.center, style: TextStyle(color: context.subdued, height: 1.5)),
          const SizedBox(height: 22),
          FilledButton.icon(onPressed: _refresh, icon: const Icon(Icons.refresh), label: const Text('إعادة المحاولة')),
        ],
      );

  Widget _content(BuildContext context, AdvisorReport data) {
    final risks = data.insights
        .where((item) =>
            item.priority.isUrgent ||
            item.priority == AdvisorPriority.diagnosis)
        .toList();
    final opportunities = data.insights
        .where((item) => item.priority == AdvisorPriority.opportunity)
        .toList();
    final observations = data.insights
        .where((item) => !risks.contains(item) && !opportunities.contains(item))
        .toList();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
      children: [
        _header(context),
        const SizedBox(height: 16),
        _executiveSummary(context, data),
        const SizedBox(height: 14),
        _businessContext(context, data),
        const SizedBox(height: 14),
        _derivedMetrics(context, data),
        if (data.unavailable.isNotEmpty) ...[
          const SizedBox(height: 14),
          _unavailableBanner(context, data.unavailable),
        ],
        const SizedBox(height: 26),
        if (risks.isNotEmpty) ...[
          _sectionHeader(context, 'إشارات الخطر', 'ما يحتاج انتباهك أولًا', Icons.warning_amber_rounded, Colors.orange),
          const SizedBox(height: 10),
          ...risks.map((item) => _insightCard(context, item, kind: _InsightKind.risk)),
          const SizedBox(height: 18),
        ],
        if (opportunities.isNotEmpty) ...[
          _sectionHeader(context, 'الفرص', 'أين يمكن أن يتحرك المتجر', Icons.trending_up_rounded, const Color(0xFF62C69A)),
          const SizedBox(height: 10),
          ...opportunities.map((item) => _insightCard(context, item, kind: _InsightKind.opportunity)),
          const SizedBox(height: 18),
        ],
        if (observations.isNotEmpty) ...[
          _sectionHeader(context, 'قراءة المشهد', 'ملاحظات تساعد على اتخاذ القرار', Icons.insights_outlined, context.goldText),
          const SizedBox(height: 10),
          ...observations.map((item) => _insightCard(context, item, kind: _InsightKind.observation)),
          const SizedBox(height: 18),
        ],
        _methodology(context, data),
        const SizedBox(height: 14),
        _continuousImprovement(context, data),
      ],
    );
  }

  /// شريط الهوية داخل المحتوى — العنوان وزر التحديث في AppBar أعلاه.
  Widget _header(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [context.goldText.withOpacity(.35), context.goldText.withOpacity(.08)]),
              shape: BoxShape.circle,
              border: Border.all(color: context.goldText.withOpacity(.4)),
            ),
            child: Icon(Icons.auto_awesome, color: context.goldText, size: 27),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('قراءة تجارية هادئة قبل القرار', style: TextStyle(color: context.subdued, fontSize: 12)),
                const SizedBox(height: 4),
                Text('قراءة وتحليل فقط — لا ينفذ أي إجراء', style: TextStyle(color: context.ink, fontSize: 12, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _badge(context, 'قراءة فقط', context.goldText),
        ],
      );

  Widget _executiveSummary(BuildContext context, AdvisorReport data) {
    final pending = data.pendingPayments;
    final summary = pending > 0
        ? 'المشهد الحالي يحتاج تركيزًا على الدفع قبل التوسع: هناك $pending طلبًا ينتظر المراجعة.'
        : 'المشهد الحالي مستقر مبدئيًا. الخطوة الأذكى الآن هي قراءة سلوك العملاء والمخزون قبل إطلاق حملة.';
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [const Color(0xFF3B2D1E).withOpacity(.95), context.surfaceCard]),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: context.goldText.withOpacity(.38)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.18), blurRadius: 18, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(children: [Icon(Icons.radar_outlined, color: context.goldText, size: 20), const SizedBox(width: 8), Text('الملخص التنفيذي', style: TextStyle(color: context.goldText, fontSize: 13, fontWeight: FontWeight.w800)), const Spacer(), _badge(context, 'قراءة فقط', context.goldText)]),
          const SizedBox(height: 15),
          Text(summary, textAlign: TextAlign.right, style: TextStyle(color: context.ink, fontSize: 18, height: 1.55, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Text('هذه قراءة للبيانات المتاحة وليست قرارًا تلقائيًا. راجع الإشارات التالية قبل أي تحرك.', textAlign: TextAlign.right, style: TextStyle(color: context.ink.withOpacity(.68), fontSize: 12, height: 1.5)),
        ],
      ),
    );
  }

  /// ما لا يظهر في شريط إحصاءات الإدارة أعلاه (الطلبات/الإيرادات/
  /// بانتظار الدفع/تم التوصيل) — نسبة التسليم والعملاء المتكررون
  /// ومنخفضو المخزون — مع سطر نطاق الإشارات عند الحاجة.
  Widget _derivedMetrics(BuildContext context, AdvisorReport data) {
    final lowStockValue = data.lowStockUnknown > 0
        ? '${data.lowStockCount} (مجهول ${data.lowStockUnknown})'
        : '${data.lowStockCount}';
    final scopeNote = data.ordersExamined < data.orders
        ? 'مبني على أول ${data.ordersExamined} طلب من أصل ${data.orders}'
        : null;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 5),
      decoration: BoxDecoration(color: context.surfaceCard, borderRadius: BorderRadius.circular(18), border: Border.all(color: context.hairline)),
      child: Column(
        children: [
          Row(children: [
            _metric(context, 'نسبة التسليم', '${(data.deliveryRatio * 100).round()}٪', Icons.local_shipping_outlined),
            _metric(context, 'عملاء متكررون', '${data.repeatCustomers}', Icons.people_outline),
            _metric(context, 'مخزون منخفض', lowStockValue, Icons.inventory_2_outlined),
          ]),
          if (scopeNote != null) ...[
            const SizedBox(height: 10),
            Text(scopeNote, textAlign: TextAlign.center, style: TextStyle(color: context.subdued, fontSize: 11)),
          ],
        ],
      ),
    );
  }

  /// بانر الأقسام التي تعذّر جلبها — التحليل جزئي لا فاشل كاملاً.
  Widget _unavailableBanner(BuildContext context, List<String> sections) {
    const labels = {
      'analytics': 'ملخص الطلبات',
      'orders': 'قائمة الطلبات',
      'customers': 'قائمة العملاء',
      'products': 'المنتجات',
    };
    final names =
        sections.map((s) => labels[s] ?? s).join('، ');
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.withOpacity(.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'أقسام غير متاحة حالياً: $names — الإشارات المعتمدة عليها مبنية على ما توفر.',
              textAlign: TextAlign.right,
              style: TextStyle(color: context.ink, fontSize: 12, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _businessContext(BuildContext context, AdvisorReport data) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.surfaceCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: context.goldText.withOpacity(.22)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.storefront_outlined, color: context.goldText, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('ذاكرة العمل', style: TextStyle(color: context.ink, fontSize: 16, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text(data.businessContext, textAlign: TextAlign.right, style: TextStyle(color: context.subdued, height: 1.55, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _metric(BuildContext context, String label, String value, IconData icon) => Expanded(child: Column(children: [Icon(icon, color: context.goldText, size: 21), const SizedBox(height: 7), Text(value, textAlign: TextAlign.center, style: TextStyle(color: context.ink, fontSize: 14, fontWeight: FontWeight.w900)), const SizedBox(height: 3), Text(label, textAlign: TextAlign.center, style: TextStyle(color: context.subdued, fontSize: 10))]));

  Widget _sectionHeader(BuildContext context, String title, String subtitle, IconData icon, Color color) => Row(children: [Icon(icon, color: color, size: 22), const SizedBox(width: 8), Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(title, style: TextStyle(color: context.ink, fontSize: 19, fontWeight: FontWeight.w900)), Text(subtitle, style: TextStyle(color: context.subdued, fontSize: 11))]), const Spacer(), Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle))]);

  Widget _insightCard(BuildContext context, AdvisorInsight insight, {required _InsightKind kind}) {
    final color = switch (kind) { _InsightKind.risk => Colors.orange, _InsightKind.opportunity => const Color(0xFF62C69A), _InsightKind.observation => context.goldText };
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: context.surfaceCard, borderRadius: BorderRadius.circular(17), border: Border.all(color: color.withOpacity(.27)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(.08), blurRadius: 8, offset: const Offset(0, 4))]),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 43, height: 43, decoration: BoxDecoration(color: color.withOpacity(.12), borderRadius: BorderRadius.circular(13)), child: Icon(_icon(insight.icon), color: color, size: 22)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Row(children: [_badge(context, insight.priority.label, color), const Spacer(), Flexible(child: Text(insight.title, textAlign: TextAlign.right, style: TextStyle(color: context.ink, fontSize: 15, fontWeight: FontWeight.w900)))]), const SizedBox(height: 8), Text(insight.body, textAlign: TextAlign.right, style: TextStyle(color: context.subdued, fontSize: 13, height: 1.55))])),
      ]),
    );
  }

  Widget _badge(BuildContext context, String label, Color color) => Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4), decoration: BoxDecoration(color: color.withOpacity(.13), borderRadius: BorderRadius.circular(20)), child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800)));

  Widget _methodology(BuildContext context, AdvisorReport data) => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: context.surfaceCard.withOpacity(.72), borderRadius: BorderRadius.circular(16), border: Border.all(color: context.hairlineSoft)), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.shield_outlined, color: context.goldText, size: 20), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text('كيف بُني هذا التحليل؟', style: TextStyle(color: context.ink, fontWeight: FontWeight.w800)), const SizedBox(height: 5), Text('تمت قراءة أول ${data.ordersExamined} طلب من أصل ${data.orders} و${data.customers} عميلًا و${data.products} منتجًا من جلسة الإدارة الحالية. لا يتم إرسال بيانات العملاء إلى نموذج خارجي في هذه النسخة.', textAlign: TextAlign.right, style: TextStyle(color: context.subdued, fontSize: 12, height: 1.55))]))]));

  Widget _continuousImprovement(BuildContext context, AdvisorReport data) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [const Color(0xFF18342B).withOpacity(.55), context.surfaceCard]),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF62C69A).withOpacity(.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(children: [Icon(Icons.autorenew_rounded, color: const Color(0xFF62C69A)), const SizedBox(width: 8), Text('دورة التطوير المستمر', style: TextStyle(color: context.ink, fontSize: 16, fontWeight: FontWeight.w900))]),
            const SizedBox(height: 8),
            Text('المستشار لا يكتفي بإصدار حكم؛ يسجل ما ينقصه ليصبح تحليله أدق في الدورة التالية.', textAlign: TextAlign.right, style: TextStyle(color: context.subdued, fontSize: 12, height: 1.5)),
            const SizedBox(height: 12),
            ...data.nextFocus.map((item) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.arrow_back_rounded, color: const Color(0xFF62C69A), size: 16), const SizedBox(width: 8), Expanded(child: Text(item, textAlign: TextAlign.right, style: TextStyle(color: context.ink, fontSize: 12, height: 1.45)))]))),
          ],
        ),
      );

  IconData _icon(AdvisorIcon icon) => switch (icon) {
        AdvisorIcon.payment => Icons.account_balance_wallet_outlined,
        AdvisorIcon.inventory => Icons.inventory_2_outlined,
        AdvisorIcon.customers => Icons.people_outline,
        AdvisorIcon.flow => Icons.timeline_outlined,
        AdvisorIcon.pending => Icons.pending_actions_outlined,
      };
}

enum _InsightKind { risk, opportunity, observation }
