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
    if (mounted) {
      setState(() {
        topics = values;
        loading = false;
      });
    }
  }

  Future<void> _toggle(String topic, bool value) async {
    setState(() => topics[topic] = value);
    await push.setTopicEnabled(topic, value);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('الإشعارات')),
        body: loading
            ? const Center(child: CircularProgressIndicator(color: gold))
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [gold.withOpacity(.18), card],
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
                          color: gold,
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
                                style: const TextStyle(
                                  color: cream,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                push.available
                                    ? 'سيصلك جديد الدار وتحديثات طلباتك فور صدورها.'
                                    : push.unavailableReason,
                                style: const TextStyle(
                                  color: muted,
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
                  const Text(
                    'ماذا تريد أن يصلك؟',
                    style: TextStyle(
                      color: cream,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...PushService.topicTitles.entries.map(
                    (entry) => Card(
                      color: card,
                      margin: const EdgeInsets.only(bottom: 6),
                      child: SwitchListTile(
                        title: Text(
                          entry.value,
                          style: const TextStyle(color: cream),
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
                    const Text(
                      'هذا الجهاز مسجّل لاستقبال الإشعارات.',
                      style: TextStyle(color: muted, fontSize: 12),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}
