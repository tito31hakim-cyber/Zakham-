import 'package:flutter/material.dart';

import '../services/push_service.dart';
import '../theme/app_theme.dart';

/// Notification settings: FCM status, topic subscriptions and a test
/// notification. When Firebase is not configured yet (no
/// google-services.json), the page explains what is missing instead of
/// failing — the choices are still saved and applied once activated.
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});
  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final push = PushService.instance;
  Map<String, bool> topics = {};
  List<PushHistoryEntry> history = [];
  String? pendingOrderRef;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final values = <String, bool>{};
    for (final topic in PushService.topicTitles.keys) {
      values[topic] = await push.isTopicEnabled(topic);
    }
    final loadedHistory = await push.fetchHistory();
    final pending = await push.takePendingOrderRef();
    if (mounted) {
      setState(() {
        topics = values;
        history = loadedHistory;
        pendingOrderRef = pending;
        loading = false;
      });
    }
  }

  Future<void> _toggle(String topic, bool value) async {
    setState(() => topics[topic] = value);
    await push.setTopicEnabled(topic, value);
  }

  Future<void> _clearHistory() async {
    await push.clearHistory();
    if (mounted) {
      setState(() => history = []);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم مسح سجل الإشعارات.')),
      );
    }
  }

  String _fmtTime(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('الإشعارات')),
        body: loading
            ? Center(child: CircularProgressIndicator(color: context.goldText))
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [gold.withOpacity(.18), context.surfaceCard],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: gold.withOpacity(.25)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          push.available
                              ? Icons.notifications_active_outlined
                              : Icons.notifications_off_outlined,
                          color: context.goldText,
                          size: 34,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                push.available
                                    ? 'الإشعارات الفورية مفعّلة'
                                    : 'الإشعارات غير مفعّلة بعد',
                                style: TextStyle(
                                  color: context.ink,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                push.available
                                    ? 'سيصلك جديد الدار وتحديثات طلباتك فور صدورها.'
                                    : push.unavailableReason,
                                style: TextStyle(
                                  color: context.subdued,
                                  fontSize: 12,
                                  height: 1.6,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'ماذا تريد أن يصلك؟',
                    style: TextStyle(
                      color: context.ink,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...PushService.topicTitles.entries.map(
                    (entry) => Card(
                      color: context.surfaceCard,
                      margin: const EdgeInsets.only(bottom: 6),
                      child: SwitchListTile(
                        title: Text(
                          entry.value,
                          style: TextStyle(color: context.ink),
                        ),
                        value: topics[entry.key] ?? false,
                        activeColor: gold,
                        onChanged: (value) => _toggle(entry.key, value),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: push.available
                        ? () async {
                            await push.sendTestNotification();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('تم إرسال إشعار اختبار.'),
                                ),
                              );
                            }
                          }
                        : null,
                    icon: const Icon(Icons.send_outlined),
                    label: const Text('إرسال إشعار اختبار'),
                  ),
                  if (push.token != null) ...[
                    const SizedBox(height: 20),
                    // رمز الجهاز لا يُعرض ولا يُنسخ: معرف الجهاز للإشعارات
                    // ولا حاجة لظهوره للمستخدم (أُزيل زر النسخ في 2026-11-17
                    // ضمن مراجعة الأمان).
                    Text(
                      'هذا الجهاز مسجّل لاستقبال الإشعارات.',
                      style: TextStyle(color: context.subdued, fontSize: 12),
                    ),
                  ],
                  // فتح التطبيق من إشعار طلب: زر يعيد إلى «طلباتي».
                  if (pendingOrderRef != null) ...[
                    const SizedBox(height: 20),
                    Card(
                      color: context.surfaceCard,
                      child: ListTile(
                        leading: Icon(
                          Icons.local_shipping_outlined,
                          color: context.goldText,
                        ),
                        title: Text(
                          'تحديث للطلب $pendingOrderRef',
                          style: TextStyle(color: context.ink),
                        ),
                        subtitle: Text(
                          'اضغط لعرض طلباتك.',
                          style: TextStyle(color: context.subdued),
                        ),
                        trailing: const Icon(Icons.arrow_back_ios, size: 16),
                        onTap: () => Navigator.pop(context),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'سجل الإشعارات',
                          style: TextStyle(
                            color: context.ink,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (history.isNotEmpty)
                        TextButton(
                          onPressed: _clearHistory,
                          child: const Text('مسح السجل'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (history.isEmpty)
                    Text(
                      'لا توجد إشعارات بعد — تصل هنا تحديثات طلباتك وأخبار الدار.',
                      style: TextStyle(color: context.subdued, fontSize: 12),
                    )
                  else
                    ...history.map(
                      (entry) => Card(
                        color: context.surfaceCard,
                        margin: const EdgeInsets.only(bottom: 6),
                        child: ListTile(
                          title: Text(
                            entry.title,
                            style: TextStyle(color: context.ink),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (entry.body.isNotEmpty)
                                Text(
                                  entry.body,
                                  style: TextStyle(color: context.subdued),
                                ),
                              const SizedBox(height: 4),
                              Text(
                                '${_fmtTime(entry.receivedAt)}${entry.orderRef.isNotEmpty ? ' · الطلب ${entry.orderRef}' : ''}',
                                style: TextStyle(
                                  color: context.subdued,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          trailing: entry.orderRef.isNotEmpty
                              ? const Icon(Icons.arrow_back_ios, size: 14)
                              : null,
                          // إشعار طلب يفتح «طلباتي» (صفحة الحساب).
                          onTap: entry.orderRef.isNotEmpty
                              ? () => Navigator.pop(context)
                              : null,
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
