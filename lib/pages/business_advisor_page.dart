import 'package:flutter/material.dart';

import '../services/admin_api.dart';
import '../services/business_advisor.dart';
import '../services/research_repository.dart';
import '../services/zakat_service.dart';
import '../theme/app_theme.dart';
import 'advisor_chat_page.dart';

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

  /// خلاصة «بحث وابتكار» — من API البحث الحي فوق جلسة الإدارة
  /// (ApiResearchRepository فوق ResearchSyncApi)؛ قراءة فقط، والمسودات
  /// موسومة «مسودة تجريبية غير معتمدة» حتى مراجعتها بشرياً.
  late Future<ResearchDigest> researchDigest;

  @override
  void initState() {
    super.initState();
    report = BusinessAdvisorService(widget.api).analyze();
    researchDigest =
        ApiResearchRepository(widget.api.researchSyncApi).latestDigest();
  }

  /// يُنتظر حتى اكتمال التحليل الجديد حتى لا يختفي مؤشر السحب مبكراً.
  Future<void> _refresh() async {
    final future = BusinessAdvisorService(widget.api).analyze();
    final researchFuture =
        ApiResearchRepository(widget.api.researchSyncApi).latestDigest();
    setState(() {
      report = future;
      researchDigest = researchFuture;
    });
    try {
      await Future.wait([future, researchFuture]);
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
        const SizedBox(height: 14),
        _chatEntryCard(context),
        const SizedBox(height: 26),
        _sectionHeader(context, 'بحث وابتكار', 'وكيل بحث أسبوعي — مسودات للمراجعة فقط', Icons.science_outlined, const Color(0xFF62C69A)),
        const SizedBox(height: 10),
        _researchSection(context),
        const SizedBox(height: 26),
        _sectionHeader(context, 'زكاة التجارة', 'حساب تقديري — يراجعه المالك بنفسه', Icons.handshake_outlined, context.goldText),
        const SizedBox(height: 10),
        const _ZakatCard(),
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

  /// بطاقة دخول المحادثة الحرة مع المستشار — حوار عن العطور
  /// والتركيبات والميكسات وأسماء العطور، من بيانات الدار فقط.
  /// تعمل فوراً بلا مفتاح؛ والردود مسودات للمراجعة فقط.
  Widget _chatEntryCard(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              context.goldText.withOpacity(.16),
              context.surfaceCard
            ],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: context.goldText.withOpacity(.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: context.goldText.withOpacity(.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.forum_outlined,
                  color: context.goldText, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'ناقش المستشار',
                    style: TextStyle(
                        color: context.ink,
                        fontSize: 17,
                        fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'حوار حر عن العطور والتركيبات والميكسات وأسماء العطور — من بيانات دار زخم فقط، والردود مسودات للمراجعة.',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        color: context.subdued, fontSize: 12, height: 1.55),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              AdvisorChatPage(api: widget.api),
                        ),
                      ),
                      icon: const Icon(Icons.chat_bubble_outline, size: 18),
                      label: const Text('ابدأ المحادثة'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  /// قسم «بحث وابتكار»: ملخص آخر دورة + مسودات الميكسات.
  ///
  /// البيانات حية من API البحث فوق جلسة الإدارة. كل مسودة تحمل وسم
  /// «مسودة تجريبية غير معتمدة»، ولا تظهر هنا نسب كاملة ولا موردون
  /// ولا تكاليف — تلك للمالك ومسؤول التركيبات فقط عبر لوحة الإدارة.
  Widget _researchSection(BuildContext context) =>
      FutureBuilder<ResearchDigest>(
        future: researchDigest,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _researchNote(
              context,
              'تعذّر تحميل خلاصة البحث حالياً — ستظهر مع الدورة التالية.',
              Icons.cloud_off_outlined,
            );
          }
          if (!snapshot.hasData) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final digest = snapshot.data!;
          return Column(
            children: [
              _runSummaryCard(context, digest.run),
              const SizedBox(height: 10),
              if (digest.drafts.isEmpty)
                _researchNote(
                  context,
                  'لا توجد مسودات ميكسات في آخر دورة.',
                  Icons.science_outlined,
                )
              else
                ...digest.drafts.map((draft) => _draftCard(context, draft)),
              const SizedBox(height: 6),
              Text(
                'بيانات حية من دورات البحث — المسودات غير معتمدة حتى مراجعتها بشرياً. لا نسب كاملة ولا موردون ولا تكاليف تظهر هنا.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: context.subdued, fontSize: 11, height: 1.5),
              ),
            ],
          );
        },
      );

  Widget _runSummaryCard(BuildContext context, ResearchRunSummary run) =>
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.goldText.withOpacity(.22)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(children: [
              Icon(Icons.calendar_month_outlined,
                  color: context.goldText, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'آخر دورة بحث — ${_date(run.startedAt)}',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      color: context.ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 8),
              _badge(context, _runStatusLabel(run.status),
                  _runStatusColor(run.status)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              _metric(context, 'مصادر وُجدت', '${run.sourcesFound}',
                  Icons.search_outlined),
              _metric(context, 'مصادر قُبلت', '${run.sourcesAccepted}',
                  Icons.verified_outlined),
              _metric(context, 'مواد جديدة', '${run.newMaterials}',
                  Icons.science_outlined),
              _metric(context, 'ميكسات جديدة', '${run.newMixes}',
                  Icons.auto_awesome),
            ]),
            const SizedBox(height: 10),
            Text(
              // الخادم الحي لا يرد إصدار مكتبة المعرفة في ملخص آخر دورة،
              // فيُخفى الجزء كاملاً بدل عرض تسمية بلا قيمة.
              'الوكيل ${run.agentVersion}${run.knowledgeVersion.isEmpty ? '' : ' • مكتبة المعرفة ${run.knowledgeVersion}'}',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.subdued, fontSize: 11),
            ),
          ],
        ),
      );

  String _runStatusLabel(String status) => switch (status) {
        'completed' => 'مكتملة',
        'review' => 'بانتظار المراجعة',
        'running' => 'جارية',
        'partial' => 'جزئية',
        'failed' => 'فاشلة',
        _ => 'جارية',
      };

  Color _runStatusColor(String status) => switch (status) {
        'completed' => const Color(0xFF62C69A),
        'review' => Colors.orange,
        'running' => context.goldText,
        'partial' => Colors.orange,
        'failed' => Colors.redAccent,
        _ => context.goldText,
      };

  Widget _draftCard(BuildContext context, ResearchDraftMix draft) =>
      Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: context.surfaceCard,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: Colors.orange.withOpacity(.45)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(children: [
              _badge(context, ResearchDraftMix.unapprovedTag, Colors.orange),
              const Spacer(),
              Text(
                '${draft.code} • إصدار ${draft.version}',
                style: TextStyle(color: context.subdued, fontSize: 11),
              ),
            ]),
            const SizedBox(height: 10),
            Text(
              draft.nameAr,
              textAlign: TextAlign.right,
              style: TextStyle(
                  color: context.ink,
                  fontSize: 17,
                  fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            _pyramidRow(context, 'افتتاحية', draft.topNotes),
            _pyramidRow(context, 'قلب', draft.heartNotes),
            _pyramidRow(context, 'قاعدة', draft.baseNotes),
            const SizedBox(height: 10),
            Text(
              draft.evidenceSummary,
              textAlign: TextAlign.right,
              style: TextStyle(
                  color: context.subdued, fontSize: 12, height: 1.55),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: draft.warnings
                  .map((w) => _badge(context, w, Colors.orange))
                  .toList(),
            ),
            const SizedBox(height: 8),
            Text(
              'درجة الثقة: ${draft.confidence}',
              style: TextStyle(color: context.subdued, fontSize: 11),
            ),
          ],
        ),
      );

  Widget _pyramidRow(
          BuildContext context, String label, List<String> notes) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                notes.join('، '),
                textAlign: TextAlign.right,
                style: TextStyle(color: context.ink, fontSize: 13),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 64,
              child: Text(
                label,
                textAlign: TextAlign.left,
                style: TextStyle(
                    color: context.goldText,
                    fontSize: 11,
                    fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      );

  Widget _researchNote(BuildContext context, String text, IconData icon) =>
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.surfaceCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.hairline),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: context.goldText, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                textAlign: TextAlign.right,
                style: TextStyle(
                    color: context.subdued, fontSize: 12, height: 1.5),
              ),
            ),
          ],
        ),
      );

  String _date(DateTime value) =>
      '${value.day}/${value.month}/${value.year}';

  IconData _icon(AdvisorIcon icon) => switch (icon) {
        AdvisorIcon.payment => Icons.account_balance_wallet_outlined,
        AdvisorIcon.inventory => Icons.inventory_2_outlined,
        AdvisorIcon.customers => Icons.people_outline,
        AdvisorIcon.flow => Icons.timeline_outlined,
        AdvisorIcon.pending => Icons.pending_actions_outlined,
      };
}

enum _InsightKind { risk, opportunity, observation }

/// بطاقة زكاة التجارة — حساب تقديري محلي فقط.
///
/// يدخل المالك: نقدية + قيمة مخزون بسعر السوق + مستحقات للدار
/// − ديون عليها + تاريخ بداية الحول + قيمة نصاب يحددها هو.
/// الزكاة 2.5% من الصافي عند بلوغ النصاب وتمام الحول (سنة هجرية).
/// تُحفظ المدخلات على الجهاز فقط (SharedPreferences)؛ والزكاة
/// ليست على الإيرادات فلا تُحسب من المبيعات.
class _ZakatCard extends StatefulWidget {
  const _ZakatCard();

  @override
  State<_ZakatCard> createState() => _ZakatCardState();
}

class _ZakatCardState extends State<_ZakatCard> {
  final _service = ZakatService();
  final _cash = TextEditingController();
  final _inventory = TextEditingController();
  final _receivables = TextEditingController();
  final _debts = TextEditingController();
  final _nisab = TextEditingController();
  DateTime _hawlStart = DateTime.now();
  bool _loaded = false;
  ZakatResult? _result;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final saved = await _service.load();
    if (!mounted) return;
    if (saved != null) {
      _cash.text = _plain(saved.cash);
      _inventory.text = _plain(saved.inventoryValue);
      _receivables.text = _plain(saved.receivables);
      _debts.text = _plain(saved.debts);
      _nisab.text = _plain(saved.nisab);
      _hawlStart = saved.hawlStart;
    }
    setState(() => _loaded = true);
  }

  @override
  void dispose() {
    _cash.dispose();
    _inventory.dispose();
    _receivables.dispose();
    _debts.dispose();
    _nisab.dispose();
    super.dispose();
  }

  /// رقم بلا فواصل لإعادة ملء الحقول المحفوظة.
  static String _plain(double value) =>
      value == value.truncateToDouble() ? '${value.toInt()}' : '$value';

  /// رقم بفواصل آلاف للعرض (160000 ← 160,000).
  static String _money(double value) {
    final negative = value < 0;
    final digits = value.abs().toStringAsFixed(0);
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
      buf.write(digits[i]);
    }
    return '${negative ? '-' : ''}$buf';
  }

  static String _date(DateTime value) =>
      '${value.day}/${value.month}/${value.year}';

  double? _parse(TextEditingController controller, {required bool required}) {
    final text = controller.text.trim().replaceAll(',', '.');
    if (text.isEmpty) return required ? null : 0;
    return double.tryParse(text);
  }

  Future<void> _calculateAndSave() async {
    final cash = _parse(_cash, required: false);
    final inventory = _parse(_inventory, required: false);
    final receivables = _parse(_receivables, required: false);
    final debts = _parse(_debts, required: false);
    final nisab = _parse(_nisab, required: true);
    if (cash == null ||
        inventory == null ||
        receivables == null ||
        debts == null ||
        nisab == null) {
      setState(() => _error =
          'أدخل الأرقام بالأرقام الإنجليزية، وقيمة النصاب إلزامية.');
      return;
    }
    try {
      final inputs = ZakatInputs(
        cash: cash,
        inventoryValue: inventory,
        receivables: receivables,
        debts: debts,
        hawlStart: _hawlStart,
        nisab: nisab,
      );
      final result = ZakatCalculator.calculate(inputs);
      await _service.save(inputs);
      setState(() {
        _result = result;
        _error = null;
      });
    } on ArgumentError catch (e) {
      setState(() => _error = e.message.toString());
    }
  }

  Future<void> _pickHawlStart() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _hawlStart,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _hawlStart = picked);
  }

  Future<void> _clear() async {
    await _service.clear();
    setState(() {
      _cash.clear();
      _inventory.clear();
      _receivables.clear();
      _debts.clear();
      _nisab.clear();
      _hawlStart = DateTime.now();
      _result = null;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.goldText.withOpacity(.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withOpacity(.35)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, color: Colors.orange, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'حساب تقديري يراجعه المالك بنفسه. الزكاة ليست على الإيرادات ولا تُحسب من المبيعات — بل على صافي أموال التجارة (نقدية + مخزون بسعر السوق + مستحقات − ديون) عند بلوغ النصاب وتمام الحول. تُحفظ المدخلات على هذا الجهاز فقط.',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        color: context.ink, fontSize: 12, height: 1.6),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _moneyField(context,
              controller: _cash,
              label: 'النقدية',
              hint: 'نقدية التجارة المتوفرة'),
          _moneyField(context,
              controller: _inventory,
              label: 'قيمة المخزون بسعر السوق',
              hint: 'قيمة بضاعة المتجر اليوم'),
          _moneyField(context,
              controller: _receivables,
              label: 'مستحقات للدار',
              hint: 'ديون الغير للدار'),
          _moneyField(context,
              controller: _debts,
              label: 'ديون على الدار',
              hint: 'ما على الدار للغير'),
          _moneyField(context,
              controller: _nisab,
              label: 'قيمة النصاب (جنيه)',
              hint: 'يحددها المالك'),
          InkWell(
            onTap: _pickHawlStart,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.hairline),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_month_outlined,
                      color: context.goldText, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'تاريخ بداية الحول',
                      style: TextStyle(
                          color: context.ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    _date(_hawlStart),
                    style:
                        TextStyle(color: context.subdued, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _calculateAndSave,
              icon: const Icon(Icons.calculate_outlined),
              label: const Text('احسب الزكاة واحفظ'),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              textAlign: TextAlign.right,
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
          ],
          if (_result != null) _resultBlock(context, _result!),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.center,
            child: TextButton(
              onPressed: _clear,
              child: const Text('مسح البيانات المحفوظة'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _moneyField(BuildContext context,
          {required TextEditingController controller,
          required String label,
          required String hint}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: controller,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          textAlign: TextAlign.right,
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            suffixText: 'جنيه',
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      );

  Widget _resultBlock(BuildContext context, ZakatResult result) => Container(
        margin: const EdgeInsets.only(top: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.goldText.withOpacity(.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.goldText.withOpacity(.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _resultRow(context, 'صافي الأموال الخاضعة',
                '${_money(result.base)} جنيه'),
            _resultRow(
                context,
                'النصاب',
                result.nisabReached
                    ? 'بلغه الصافي'
                    : 'لم يبلغه الصافي بعد'),
            _resultRow(context, 'الحول',
                result.hawlComplete ? 'تم' : 'ينتهي ${_date(result.hawlEnd)}'),
            const SizedBox(height: 10),
            Text(
              result.isDue
                  ? 'الزكاة المستحقة: ${_money(result.due)} جنيه'
                  : 'لا زكاة مستحقة بعد',
              textAlign: TextAlign.right,
              style: TextStyle(
                  color: context.ink,
                  fontSize: 17,
                  fontWeight: FontWeight.w900),
            ),
          ],
        ),
      );

  Widget _resultRow(BuildContext context, String label, String value) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.left,
                style: TextStyle(
                    color: context.ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(color: context.subdued, fontSize: 13),
            ),
          ],
        ),
      );
}
