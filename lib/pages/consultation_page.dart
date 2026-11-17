import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/consultation.dart';
import '../services/occasions.dart';
import '../theme/app_theme.dart';

/// حجز استشارة عطرية — يختار العميل اليوم (من الغد فصاعداً) والوقت
/// المفضل (12 ظهراً – 10 مساءً) ونوع الاستشارة (مكالمة/واتساب)،
/// وتُرسل برسالة واتساب جاهزة للدار بكل التفاصيل، ويُحفظ الطلب
/// محلياً ليعرضه في «استشاراتي» بحسابه. بلا خادم.
class ConsultationPage extends StatefulWidget {
  const ConsultationPage({
    super.key,
    required this.consultations,
    required this.ownerKey,
  });

  final ConsultationService consultations;

  /// مفتاح حساب العميل — يفصل التخزين المحلي بين الحسابات.
  final String ownerKey;

  @override
  State<ConsultationPage> createState() => _ConsultationPageState();
}

class _ConsultationPageState extends State<ConsultationPage> {
  DateTime? _date;
  String _timeSlot = '18:00';
  String _type = 'whatsapp';
  final TextEditingController _notesController = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  DateTime get _tomorrow {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day + 1);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? _tomorrow,
      firstDate: _tomorrow,
      lastDate: DateTime.now().add(const Duration(days: 60)),
      helpText: 'اختر اليوم المفضل للاستشارة',
      cancelText: 'إلغاء',
      confirmText: 'تأكيد',
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  /// يحفظ الطلب محلياً ثم يفتح واتساب بالرسالة الجاهزة؛ وإن تعذر
  /// فتح واتساب يعرض نص الرسالة للنسخ. best-effort ولا يعطّل الصفحة.
  Future<void> _submit() async {
    if (_date == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر اليوم المفضل للاستشارة أولاً.')),
      );
      return;
    }
    if (_sending) return;
    setState(() => _sending = true);
    try {
      final request = await widget.consultations.save(
        ownerKey: widget.ownerKey,
        date:
            '${_date!.year.toString().padLeft(4, '0')}-${_date!.month.toString().padLeft(2, '0')}-${_date!.day.toString().padLeft(2, '0')}',
        timeSlot: _timeSlot,
        type: _type,
        notes: _notesController.text,
      );
      final uri = Uri.parse(consultationWhatsAppUrl(request));
      final launched =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!mounted) return;
      if (launched) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حفظ طلب الاستشارة — أكمل الإرسال في واتساب.'),
          ),
        );
        Navigator.pop(context);
      } else {
        await _showCopyFallback(request);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر إرسال الطلب الآن — حاول لاحقاً.')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _showCopyFallback(ConsultationRequest request) async {
    final message = buildConsultationMessage(request);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('انسخ رسالة الحجز'),
        content: SingleChildScrollView(
          child: SelectableText(message, style: const TextStyle(height: 1.8)),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: message));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم نسخ الرسالة.')),
                );
                Navigator.pop(context);
              }
            },
            child: const Text('نسخ الرسالة'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('حجز استشارة عطرية')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            Text(
              'استشارتك مع الدار',
              style: TextStyle(
                color: context.ink,
                fontSize: 26,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'اختر اليوم والوقت المفضلين، وسنتواصل معك في الموعد لمساعدتك في اختيار عطرك المناسب.',
              style: TextStyle(color: context.subdued, height: 1.7),
            ),
            const SizedBox(height: 22),
            Text(
              'اليوم المفضل',
              style: TextStyle(
                color: context.ink,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _pickDate,
                icon: Icon(Icons.calendar_today_outlined,
                    color: context.goldText, size: 18),
                label: Text(
                  _date == null
                      ? 'اختر اليوم (من الغد فصاعداً)'
                      : formatArabicDate(_date!),
                  style: TextStyle(color: context.ink),
                ),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'الوقت المفضل',
              style: TextStyle(
                color: context.ink,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: consultationTimeSlots
                  .map(
                    (slot) => ChoiceChip(
                      label: Text(formatTimeSlotAr(slot)),
                      selected: _timeSlot == slot,
                      onSelected: (_) => setState(() => _timeSlot = slot),
                    ),
                  )
                  .toList(growable: false),
            ),
            const SizedBox(height: 22),
            Text(
              'نوع الاستشارة',
              style: TextStyle(
                color: context.ink,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Text('مكالمة هاتفية'),
                    selected: _type == 'call',
                    onSelected: (_) => setState(() => _type = 'call'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ChoiceChip(
                    label: const Text('واتساب'),
                    selected: _type == 'whatsapp',
                    onSelected: (_) => setState(() => _type = 'whatsapp'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Text(
              'ملاحظات (اختياري)',
              style: TextStyle(
                color: context.ink,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              maxLines: 3,
              maxLength: 300,
              decoration: const InputDecoration(
                hintText: 'مثال: أبحث عن عطر رسمي للاجتماعات، وأفضل العود.',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _sending ? null : _submit,
                icon: const Icon(Icons.chat_outlined, size: 18),
                label: Text(_sending ? 'جارٍ الإرسال…' : 'إرسال الحجز عبر واتساب'),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'سيصلك تأكيد الموعد من الدار على واتساب. طلبك محفوظ في «استشاراتي» بحسابك.',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.subdued, fontSize: 12, height: 1.7),
            ),
          ],
        ),
      ),
    );
  }
}
