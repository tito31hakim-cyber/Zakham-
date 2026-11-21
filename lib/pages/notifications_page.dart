import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import '../services/app_update_api.dart';
import '../services/favorites_offer_service.dart';
import '../services/push_service.dart';
import '../services/reminder_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

/// صفحة «الإشعارات» المتكاملة: حالة الإشعارات الفورية، ومواضيع
/// الإشعارات، و«التذكيرات» (تذكيرات السلة وعروض المفضلة وعطر
/// اليوم)، وزر الاختبار، وسجل الإشعارات. التذكيرات انتقلت إلى هنا
/// من «حسابي» لتكون كل إعدادات الإشعارات في صفحة واحدة.
/// When Firebase is not configured yet (no
/// google-services.json), the page explains what is missing instead of
/// failing — the choices are still saved and applied once activated.
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key, this.onDailyPerfumeEnabled});

  /// يُستدعى عند تفعيل إشعار «عطر اليوم» لجدولة إشعاره اليومي.
  final VoidCallback? onDailyPerfumeEnabled;

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final push = PushService.instance;
  Map<String, bool> topics = {};
  List<PushHistoryEntry> history = [];
  String? pendingOrderRef;
  bool loading = true;

  /// حالات «التذكيرات» — تُحفظ محلياً عبر خدمات التذكير.
  bool? _remindersEnabled;
  bool? _favOffersEnabled;
  bool? _dailyPerfumeEnabled;

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
    final reminders = await ReminderService.instance.isEnabled();
    final favOffers = await FavoritesOfferService().isEnabled();
    final dailyPerfume =
        await ReminderService.instance.isDailyPerfumeEnabled();
    if (mounted) {
      setState(() {
        topics = values;
        history = loadedHistory;
        pendingOrderRef = pending;
        _remindersEnabled = reminders;
        _favOffersEnabled = favOffers;
        _dailyPerfumeEnabled = dailyPerfume;
        loading = false;
      });
    }
  }

  Future<void> _toggle(String topic, bool value) async {
    setState(() => topics[topic] = value);
    await push.setTopicEnabled(topic, value);
  }

  /// مبدّلات «التذكيرات» — نُقلت من «حسابي» إلى هنا (صفحة واحدة
  /// متكاملة لكل إعدادات الإشعارات) بنفس السلوك والرسائل.
  Future<void> _toggleReminders(bool value) async {
    setState(() => _remindersEnabled = value);
    await ReminderService.instance.setEnabled(value);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value
              ? 'التذكيرات مفعّلة — سنذكّرك بلطف بسلة متروكة وإعادة الشراء.'
              : 'أُوقفت التذكيرات — لن تصلك تذكيرات السلة أو إعادة الشراء.'),
        ),
      );
    }
  }

  Future<void> _toggleFavOffers(bool value) async {
    setState(() => _favOffersEnabled = value);
    await FavoritesOfferService().setEnabled(value);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value
              ? 'ستصلك تنبيهات عروض عطورك المفضلة.'
              : 'أُوقفت تنبيهات عروض المفضلة.'),
        ),
      );
    }
  }

  Future<void> _toggleDailyPerfume(bool value) async {
    setState(() => _dailyPerfumeEnabled = value);
    await ReminderService.instance.setDailyPerfumeEnabled(value);
    if (value) widget.onDailyPerfumeEnabled?.call();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value
              ? 'سيصلك إشعار «عطر اليوم» كل يوم الساعة 6 مساءً.'
              : 'أُوقف إشعار «عطر اليوم» اليومي.'),
        ),
      );
    }
  }

  /// صف مبدّل تذكير واحد — بنفس شكل مفاتيح «حسابي»: أيقونة ذهبية
  /// وعنوان وجملة موجزة، والمفتاح بثيم التطبيق (تشغيل ذهبي وإيقاف
  /// رمادي بإطار).
  Widget _reminderRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool? value,
    required ValueChanged<bool> onChanged,
  }) =>
      Card(
        color: context.surfaceCard,
        margin: const EdgeInsets.only(bottom: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: context.hairline),
        ),
        child: SwitchListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          secondary: Icon(icon, color: context.goldText),
          title: Text(
            title,
            style: TextStyle(color: context.ink, fontSize: 15),
          ),
          subtitle: Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: context.subdued, fontSize: 11),
          ),
          value: value ?? true,
          onChanged: onChanged,
        ),
      );

  Future<void> _clearHistory() async {
    await push.clearHistory();
    if (mounted) {
      setState(() => history = []);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم مسح سجل الإشعارات.')),
      );
    }
  }

  /// زر «تحديث الآن» في بطاقات التحديث: يفتح رابط التحميل المعلن
  /// حالياً في نقطة /api/app/latest، أو صفحة المتجر عند تعذّر
  /// الجلب. توجيه يدوي فقط — بلا تحديث تلقائي وبلا تثبيت صامت.
  Future<void> _openUpdateLink() async {
    var url = AppConfig.apiBaseUrl;
    try {
      final latest = await AppUpdateApi().fetchLatest();
      if (latest != null) url = latest.downloadUrl;
    } catch (_) {}
    final launched = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذّر فتح رابط التحديث على هذا الجهاز.'),
        ),
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
                  const AccountGroupHeader(
                    title: 'ماذا تريد أن يصلك؟',
                    horizontal: 0,
                  ),
                  ...PushService.topicTitles.entries.map(
                    (entry) => Card(
                      color: context.surfaceCard,
                      margin: const EdgeInsets.only(bottom: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(color: context.hairline),
                      ),
                      child: SwitchListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 5),
                        title: Text(
                          entry.value,
                          style: TextStyle(color: context.ink),
                        ),
                        value: topics[entry.key] ?? false,
                        onChanged: (value) => _toggle(entry.key, value),
                      ),
                    ),
                  ),
                  const AccountGroupHeader(
                    title: 'التذكيرات',
                    horizontal: 0,
                  ),
                  _reminderRow(
                    icon: Icons.notifications_active_outlined,
                    title: 'تذكيرات السلة والطلبات',
                    subtitle: 'تذكير عند ترك السلة وإعادة الشراء',
                    value: _remindersEnabled,
                    onChanged: _toggleReminders,
                  ),
                  _reminderRow(
                    icon: Icons.local_offer_outlined,
                    title: 'تنبيهات عروض المفضلة',
                    subtitle: 'عند عرض أو انخفاض سعر عطر محفوظ',
                    value: _favOffersEnabled,
                    onChanged: _toggleFavOffers,
                  ),
                  _reminderRow(
                    icon: Icons.calendar_today_outlined,
                    title: 'عطر اليوم',
                    subtitle: 'إشعار يومي 6 مساءً بعطر مختلف',
                    value: _dailyPerfumeEnabled,
                    onChanged: _toggleDailyPerfume,
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
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(color: context.hairline),
                      ),
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
                        trailing: const Icon(
                          Icons.arrow_back_ios_new,
                          size: 15,
                          color: gold,
                        ),
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
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
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
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(color: context.hairline),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ListTile(
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
                                      style:
                                          TextStyle(color: context.subdued),
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
                                  ? Icon(
                                      Icons.arrow_back_ios_new,
                                      size: 15,
                                      color: context.goldText,
                                    )
                                  : null,
                              // إشعار طلب يفتح «طلباتي» (صفحة الحساب).
                              onTap: entry.orderRef.isNotEmpty
                                  ? () => Navigator.pop(context)
                                  : null,
                            ),
                            // بطاقة تحديث تطبيق: زر مباشر يفتح رابط
                            // التحديث/المتجر — بلا تحديث تلقائي.
                            if (entry.isAppUpdate)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: FilledButton.icon(
                                    onPressed: _openUpdateLink,
                                    icon: const Icon(
                                      Icons.system_update_outlined,
                                      size: 18,
                                    ),
                                    label: const Text('تحديث الآن'),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
