import 'package:flutter/material.dart';

import '../services/admin_api.dart';
import '../services/intelligence_center.dart';
import '../theme/app_theme.dart';

/// مركز ذكاء دار زخم — النسخة الأولى: قراءة وتحليل فقط.
///
/// شاشة للإدارة فقط تُفتح من لوحة الإدارة: إحاطة اليوم، وكيل فرز
/// الطلبات، المستشار بأسئلة جاهزة، وسجل قرارات المركز. لا ترسل ولا
/// تغيّر أي بيانات — كل الاقتراحات مسودات نصية.

class IntelligenceCenterPage extends StatefulWidget {
  const IntelligenceCenterPage({super.key, required this.api});

  final AdminApi api;

  @override
  State<IntelligenceCenterPage> createState() =>
      _IntelligenceCenterPageState();
}

class _Loaded {
  const _Loaded({
    required this.data,
    required this.briefing,
    required this.flags,
    required this.week,
    required this.topCustomers,
    required this.restock,
    required this.draft,
    required this.log,
  });

  final BriefingData data;
  final DailyBriefing briefing;
  final List<TriageFlag> flags;
  final WeekComparison week;
  final List<TopCustomer> topCustomers;
  final List<RestockSuggestion> restock;
  final CampaignDraft? draft;
  final List<DecisionLogEntry> log;
}

class _IntelligenceCenterPageState extends State<IntelligenceCenterPage> {
  late Future<_Loaded> _future;
  Future<List<DecisionLogEntry>>? _logFuture;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  String _ymd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _money(double v) => '${v.toStringAsFixed(0)} ج.م';

  Future<_Loaded> _load() async {
    final repo = IntelligenceRepository(widget.api);
    final data = await repo.fetchBriefing();
    final briefing = IntelligenceAnalysis.computeBriefing(data);
    final flags = IntelligenceAnalysis.triageOrders(data);

    // آخر 7 أيام من قائمة آخر 30 يوماً (مقارنة نصية بصيغة ISO).
    final weekStart = _ymd(data.now.subtract(const Duration(days: 7)));
    final thisWeek = data.recentOrders
        .where((o) => (o['created_at'] ?? '').toString().compareTo(weekStart) >= 0)
        .toList();
    final week = IntelligenceAnalysis.compareWeeks(
      thisWeek,
      data.lastWeekOrders,
    );
    final topCustomers = IntelligenceAnalysis.topCustomers(data.customers);
    final sold = IntelligenceAnalysis.soldByProduct(data.orderDetails.values);
    final restock = IntelligenceAnalysis.restockSuggestions(
      data.products,
      sold,
    );

    // العطر الأعلى مبيعاً خلال 30 يوماً لمسودة الحملة.
    final qtyByName = <String, int>{};
    final ordersByName = <String, Set<String>>{};
    for (final detail in data.orderDetails.values) {
      if (detail['status'] == 'cancelled') continue;
      final items = (detail['items'] as List?) ?? const [];
      for (final raw in items) {
        if (raw is! Map) continue;
        final name = (raw['nameAr'] ?? raw['productId'] ?? '').toString().trim();
        if (name.isEmpty) continue;
        qtyByName[name] =
            (qtyByName[name] ?? 0) + ((raw['quantity'] as num?)?.toInt() ?? 1);
        (ordersByName[name] ??= <String>{})
            .add((detail['orderRef'] ?? '').toString());
      }
    }
    CampaignDraft? draft;
    if (qtyByName.isNotEmpty) {
      final top = qtyByName.entries.reduce(
        (a, b) => a.value >= b.value ? a : b,
      );
      draft = IntelligenceAnalysis.campaignDraft(
        perfumeName: top.key,
        buyersOrders: ordersByName[top.key]?.length ?? 0,
        busiestTime:
            IntelligenceAnalysis.busiestOrderTime(data.recentOrders),
      );
    }

    // سجل القرارات: إدخال واحد لكل تحديث ناجح للإحاطة.
    await IntelligenceLog.add(DecisionLogEntry(
      time: DateTime.now(),
      kind: 'briefing',
      summary:
          'حُللت إحاطة اليوم: ${briefing.todayCount} طلباً بإيراد ${_money(briefing.todayRevenue)}، '
          '${briefing.awaitingPaymentCount} بلا تأكيد دفع، و${flags.length} علم فرز.',
      basis:
          'طلبات اليوم + قوائم الدفع + ${data.orderDetails.length} تفصيل طلب + '
          '${data.products.length} منتجاً + ${data.customers.length} عميلاً.',
      reason: 'قواعد المركز: تجميع الإحاطة، فرز الطلبات، مقارنة الأسبوع.',
    ));
    final log = await IntelligenceLog.load();
    return _Loaded(
      data: data,
      briefing: briefing,
      flags: flags,
      week: week,
      topCustomers: topCustomers,
      restock: restock,
      draft: draft,
      log: log,
    );
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  Future<void> _clearLog() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('مسح سجل القرارات؟'),
          content: const Text('سيُمسح سجل قرارات المركز المحلي بالكامل.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('مسح'),
            ),
          ],
        ),
      ),
    );
    if (confirm != true) return;
    await IntelligenceLog.clear();
    if (mounted) setState(() => _logFuture = IntelligenceLog.load());
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
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
        body: FutureBuilder<_Loaded>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'تعذر تحميل تحليل المركز: ${snapshot.error.toString().replaceFirst('Exception: ', '')}',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: context.subdued),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _refresh,
                        child: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                ),
              );
            }
            if (!snapshot.hasData) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: context.goldText),
                    const SizedBox(height: 12),
                    Text(
                      'يقرأ المركز بيانات المتجر ويحللها…',
                      style: TextStyle(color: context.subdued),
                    ),
                  ],
                ),
              );
            }
            final loaded = snapshot.data!;
            final briefing = loaded.briefing;
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _readonlyBadge(loaded),
                  const SizedBox(height: 12),
                  _sectionTitle('إحاطة اليوم'),
                  _briefingGrid(briefing),
                  const SizedBox(height: 8),
                  _topPerfumeCard(briefing),
                  const SizedBox(height: 8),
                  _lowStockCard(briefing),
                  const SizedBox(height: 8),
                  _unavailableNote(),
                  const SizedBox(height: 20),
                  _sectionTitle('وكيل فرز الطلبات'),
                  _triageList(loaded.flags),
                  const SizedBox(height: 20),
                  _sectionTitle('المستشار'),
                  _advisorCard(
                    question: 'لماذا انخفضت المبيعات هذا الأسبوع؟',
                    child: Text(
                      loaded.week.verdict,
                      style: TextStyle(color: context.ink, height: 1.6),
                    ),
                  ),
                  _advisorCard(
                    question: 'من أفضل 20 عميلاً لإطلاق عطر جديد؟',
                    child: loaded.topCustomers.isEmpty
                        ? Text('لا يوجد عملاء بعد.',
                            style: TextStyle(color: context.subdued))
                        : Column(
                            children: loaded.topCustomers
                                .take(10)
                                .map((c) => _kv(
                                      c.displayName.isEmpty
                                          ? (c.email.isEmpty
                                              ? 'عميل بلا اسم'
                                              : c.email)
                                          : c.displayName,
                                      '${c.ordersCount} طلبات · ${_money(c.ordersValue)}',
                                    ))
                                .toList(),
                          ),
                  ),
                  _advisorCard(
                    question: 'ما المنتج الذي أزيد مخزونه؟',
                    child: loaded.restock.isEmpty
                        ? Text(
                            'لا اقتراحات الآن — لا منتج بِيع خلال 30 يوماً '
                            'ومخزونه منخفض.',
                            style: TextStyle(color: context.subdued),
                          )
                        : Column(
                            children: loaded.restock
                                .map((s) => _kv(s.productName, s.reason))
                                .toList(),
                          ),
                  ),
                  _advisorCard(
                    question: 'اقترح حملة بلا خصم مباشر',
                    child: loaded.draft == null
                        ? Text(
                            'لا توجد مبيعات خلال 30 يوماً لاقتراح حملة.',
                            style: TextStyle(color: context.subdued),
                          )
                        : _campaignDraft(loaded.draft!),
                  ),
                  const SizedBox(height: 20),
                  _sectionTitle('سجل قرارات المركز'),
                  _decisionLog(loaded.log),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _readonlyBadge(_Loaded loaded) {
    return Card(
      color: context.surfaceCard,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.psychology_outlined, color: context.goldText),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'قراءة وتحليل فقط — لا يرسل ولا يغيّر شيئاً',
                    style: TextStyle(
                      color: context.ink,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'كل الاقتراحات مسودات نصية تعرض عليك أولاً. '
              'آخر تحديث: ${_ymd(loaded.data.now)}'
              '${loaded.data.detailsSkipped > 0 ? ' · تعذّر جلب تفاصيل ${loaded.data.detailsSkipped} طلباً.' : ''}',
              style: TextStyle(color: context.subdued, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          title,
          style: TextStyle(
            color: context.ink,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      );

  Widget _briefingGrid(DailyBriefing b) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.4,
      children: [
        _statCard('طلبات اليوم', '${b.todayCount}'),
        _statCard('إيراد اليوم', _money(b.todayRevenue)),
        _statCard(
          'بلا تأكيد دفع',
          '${b.awaitingPaymentCount} طلباً',
          sub: '${b.unpaidCount} غير مدفوع · ${b.proofSubmittedCount} بإثبات '
              '· ${_money(b.awaitingPaymentTotal)}',
        ),
        _statCard('تم التوصيل اليوم', '${b.todayDelivered}'),
      ],
    );
  }

  Widget _statCard(String label, String value, {String? sub}) {
    return Card(
      color: context.surfaceCard,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              style: TextStyle(
                color: context.goldText,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(label, style: TextStyle(color: context.subdued, fontSize: 12)),
            if (sub != null)
              Text(sub, style: TextStyle(color: context.subdued, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _topPerfumeCard(DailyBriefing b) {
    return Card(
      color: context.surfaceCard,
      child: ListTile(
        leading: Icon(Icons.local_fire_department_outlined,
            color: context.goldText),
        title: Text(
          b.topPerfumeName.isEmpty
              ? 'لا مبيعات اليوم بعد'
              : 'الأعلى طلباً اليوم: ${b.topPerfumeName}',
          style: TextStyle(color: context.ink),
        ),
        subtitle: b.topPerfumeName.isEmpty
            ? null
            : Text(
                '${b.topPerfumeQty} زجاجة في ${b.topPerfumeOrders} طلباً',
                style: TextStyle(color: context.subdued),
              ),
      ),
    );
  }

  Widget _lowStockCard(DailyBriefing b) {
    return Card(
      color: context.surfaceCard,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'متغيرات قاربت على النفاد (5 أو أقل)',
              style: TextStyle(
                color: context.ink,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            if (b.lowStock.isEmpty)
              Text('لا متغيرات قاربة على النفاد.',
                  style: TextStyle(color: context.subdued))
            else
              ...b.lowStock.map((v) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_outlined,
                            size: 16, color: context.goldText),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${v.label} — المتبقي ${v.stockQty}',
                            style: TextStyle(color: context.ink),
                          ),
                        ),
                      ],
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  Widget _unavailableNote() {
    return Card(
      color: context.surfaceCard,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'غير متاح من البيانات الحالية',
              style: TextStyle(
                color: context.ink,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            ...IntelligenceAnalysis.unavailableRules.map((r) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    '• $r',
                    style: TextStyle(color: context.subdued, fontSize: 12),
                  ),
                )),
            Text(
              'هذه البنود تحتاج نقطة خادم جديدة — تُنفذ بأمر صريح منك لاحقاً.',
              style: TextStyle(color: context.subdued, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _triageList(List<TriageFlag> flags) {
    if (flags.isEmpty) {
      return Card(
        color: context.surfaceCard,
        child: ListTile(
          leading: Icon(Icons.check_circle_outline, color: context.goldText),
          title: Text('لا طلبات تحتاج تدخلاً الآن.',
              style: TextStyle(color: context.ink)),
        ),
      );
    }
    return Column(
      children: flags.map((f) {
        final color = switch (f.severity) {
          TriageSeverity.high => Colors.red,
          TriageSeverity.medium => Colors.amber.shade700,
          TriageSeverity.low => Colors.grey,
        };
        return Card(
          color: context.surfaceCard,
          child: ListTile(
            leading: Icon(Icons.flag_outlined, color: color),
            title: Text(
              '${f.orderRef} — ${f.title}',
              style: TextStyle(color: context.ink),
            ),
            subtitle: Text(
              '${f.detail}\nالأولوية: ${f.severityLabel} · ${f.createdAt}',
              style: TextStyle(color: context.subdued),
            ),
            isThreeLine: true,
          ),
        );
      }).toList(),
    );
  }

  Widget _advisorCard({required String question, required Widget child}) {
    return Card(
      color: context.surfaceCard,
      child: ExpansionTile(
        title: Text(
          question,
          style: TextStyle(color: context.ink, fontWeight: FontWeight.bold),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _campaignDraft(CampaignDraft d) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _kv('الجمهور', d.audienceText),
        _kv('العرض المقترح', d.offerText),
        _kv('أفضل توقيت', d.suggestedTime),
        const SizedBox(height: 8),
        Text('نص الرسالة:',
            style: TextStyle(
                color: context.ink, fontWeight: FontWeight.bold)),
        Text(d.message, style: TextStyle(color: context.ink, height: 1.6)),
        const SizedBox(height: 8),
        Text('نسخة واتساب:',
            style: TextStyle(
                color: context.ink, fontWeight: FontWeight.bold)),
        Text(d.whatsappText,
            style: TextStyle(color: context.ink, height: 1.6)),
        const SizedBox(height: 8),
        Text('نسخة إشعار:',
            style: TextStyle(
                color: context.ink, fontWeight: FontWeight.bold)),
        Text(d.notificationText,
            style: TextStyle(color: context.ink, height: 1.6)),
        const SizedBox(height: 8),
        Text(
          'مسودة نصية فقط — لا إرسال من هنا.',
          style: TextStyle(color: context.subdued, fontSize: 12),
        ),
      ],
    );
  }

  Widget _kv(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: TextStyle(
                    color: context.subdued, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(color: context.ink, height: 1.5)),
          ),
        ],
      ),
    );
  }

  Widget _decisionLog(List<DecisionLogEntry> initial) {
    return FutureBuilder<List<DecisionLogEntry>>(
      future: _logFuture ?? Future.value(initial),
      builder: (context, snapshot) {
        final entries = snapshot.data ?? initial;
        return Card(
          color: context.surfaceCard,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'ماذا حلّل المركز وعلى أي بيانات ولماذا اقترح',
                        style: TextStyle(
                          color: context.ink,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: entries.isEmpty ? null : _clearLog,
                      child: const Text('مسح السجل'),
                    ),
                  ],
                ),
                if (entries.isEmpty)
                  Text('لا إدخالات بعد — يظهر أول إدخال بعد أول تحديث.',
                      style: TextStyle(color: context.subdued))
                else
                  ...entries.take(10).map((e) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              e.summary,
                              style: TextStyle(color: context.ink),
                            ),
                            Text(
                              'البيانات: ${e.basis}',
                              style: TextStyle(
                                  color: context.subdued, fontSize: 12),
                            ),
                            Text(
                              'السبب: ${e.reason} · ${_ymd(e.time)}',
                              style: TextStyle(
                                  color: context.subdued, fontSize: 12),
                            ),
                          ],
                        ),
                      )),
              ],
            ),
          ),
        );
      },
    );
  }
}
