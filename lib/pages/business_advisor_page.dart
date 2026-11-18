import 'package:flutter/material.dart';

import '../services/admin_api.dart';
import '../services/business_advisor.dart';
import '../theme/app_theme.dart';

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

  void _refresh() =>
      setState(() => report = BusinessAdvisorService(widget.api).analyze());

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: RefreshIndicator(
      onRefresh: () async => _refresh(),
      child: FutureBuilder<AdvisorReport>(
        future: report,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return ListView(
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
                  '${snapshot.error}'.replaceFirst('Exception: ', ''),
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
          }
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          return _content(context, snapshot.data!);
        },
      ),
    ),
  );

  Widget _content(BuildContext context, AdvisorReport data) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
    children: [
      Row(
        children: [
          IconButton(
            onPressed: _refresh,
            icon: Icon(Icons.refresh, color: context.goldText),
            tooltip: 'تحديث التحليل',
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'مركز ذكاء دار زخم',
                style: TextStyle(
                  color: context.ink,
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                'قراءة وتحليل فقط — لا ينفذ أي إجراء',
                style: TextStyle(color: context.subdued, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: context.goldText.withOpacity(.14),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.psychology_outlined,
              color: context.goldText,
              size: 28,
            ),
          ),
        ],
      ),
      const SizedBox(height: 18),
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

  Widget _summary(BuildContext context, AdvisorReport data) => Container(
    padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [context.goldText.withOpacity(.18), context.surfaceCard],
      ),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: context.goldText.withOpacity(.28)),
    ),
    child: Row(
      children: [
        _metric(
          context,
          'الطلبات',
          '${data.orders}',
          Icons.receipt_long_outlined,
        ),
        _metric(context, 'العملاء', '${data.customers}', Icons.people_outline),
        _metric(
          context,
          'الإيرادات',
          '${data.revenue.toStringAsFixed(0)} ج.م',
          Icons.payments_outlined,
        ),
        _metric(
          context,
          'بانتظار الدفع',
          '${data.pendingPayments}',
          Icons.pending_actions_outlined,
        ),
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
    final urgent = insight.priority == 'عاجل' || insight.priority == 'مرتفع';
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
              color: (urgent ? Colors.orange : context.goldText).withOpacity(
                .13,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _icon(insight.icon),
              color: urgent ? Colors.orange : context.goldText,
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
                        color: (urgent ? Colors.orange : context.goldText)
                            .withOpacity(.13),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        insight.priority,
                        style: TextStyle(
                          color: urgent ? Colors.orange : context.goldText,
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

  IconData _icon(String key) => switch (key) {
    'payment' => Icons.account_balance_wallet_outlined,
    'inventory' => Icons.inventory_2_outlined,
    'customers' => Icons.people_outline,
    'flow' => Icons.timeline_outlined,
    _ => Icons.auto_awesome_outlined,
  };
  String _time(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}
