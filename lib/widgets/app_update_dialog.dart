import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';

/// رابط الرسالة المثبّتة في قناة تليجرام الرسمية لدار زخم — وجهة
/// زر «تحديث الآن» في حوار التحديث (بناء 41): يفتح الرسالة
/// المثبّتة نفسها (وفيها رابط تحميل الـ APK من المتجر)، لا القناة
/// عموماً. ملف الـ APK نفسه لا يُرفع على تليجرام أبداً، بل يبقى
/// على الموقع ويُستبدل بكل بناء جديد على نفس العنوان.
const kZakhamUpdatePinnedLink = 'https://t.me/zakhamapp/2';

/// حوار «تحديث جديد» — على نموذج حوار تحديث Truecaller (بناء 41):
/// حوار كبير بخلفية داكنة قريبة من السواد بهوية زخم (أسود وذهبي
/// سينمائي — بلا بنفسجي/أزرق Truecaller إطلاقاً)، فيه الشعار
/// وعنوان كبير ورقم الإصدار الجديد وقسم «ما الجديد» وتحذير أن
/// المثبَّت أقدم، وزر ذهبي كبير «تحديث الآن» بعرض الحوار.
///
/// يظهر عند فتح التطبيق كلما أعلنت نقطة /api/app/latest عن
/// versionCode أحدث من المثبَّت.
///
/// زر «تحديث الآن» يفتح رابط الرسالة المثبّتة في تليجرام؛
/// و«لاحقاً» يغلق الحوار فقط، ويظهر الحوار مجدداً عند الفتح
/// التالي طالما التحديث معلّق — الرفض لا يُحفظ أبداً. بلا تحديث
/// تلقائي وبلا تثبيت صامت — التوجيه يدوي فقط.
Future<void> showAppUpdateDialog(
  BuildContext context, {
  required String versionName,
  List<String>? notes,
  Future<bool> Function(Uri uri)? launch,
}) async {
  final launchPinnedLink = launch ??
      (Uri uri) => launchUrl(uri, mode: LaunchMode.externalApplication);
  final shownNotes = (notes ?? []).where((note) => note.isNotEmpty).toList();
  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) => Dialog(
      backgroundColor: card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: gold.withOpacity(.45)),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // الشعار.
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.asset(
                  'assets/brand/zakham-app-icon.png',
                  width: 72,
                  height: 72,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: const Color(0xFF17130B),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: gold),
                    ),
                    child: const Icon(
                      Icons.system_update_alt,
                      color: gold,
                      size: 36,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // العنوان.
            const Text(
              'تحديث جديد!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: cream,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'دار زخم',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: muted),
            ),
            const SizedBox(height: 12),
            // رقم الإصدار الجديد.
            Text(
              'الإصدار $versionName متوفر',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: cream,
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: gold),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'إصدار جديد',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: gold,
                  ),
                ),
              ),
            ),
            // قسم «ما الجديد» — يظهر فقط عند وجود ملاحظات فعلية.
            if (shownNotes.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text(
                '✨ ما الجديد',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: gold,
                ),
              ),
              const SizedBox(height: 8),
              ...shownNotes.map(
                (note) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '•  ',
                        style: TextStyle(fontSize: 15, color: gold),
                      ),
                      Expanded(
                        child: Text(
                          note,
                          style: const TextStyle(
                            fontSize: 15,
                            color: cream,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            // التحذير.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('⚠️  ', style: TextStyle(fontSize: 15)),
                Expanded(
                  child: Text(
                    'أنت تستخدم إصداراً أقدم. حدّث إلى أحدث إصدار '
                    'للاستمتاع بالمزايا الجديدة.',
                    style: TextStyle(fontSize: 14, color: muted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // زر التحديث — ذهبي كبير بعرض الحوار.
            FilledButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                final launched = await launchPinnedLink(
                  Uri.parse(kZakhamUpdatePinnedLink),
                );
                if (!launched && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content:
                          Text('تعذّر فتح رابط التحديث على هذا الجهاز.'),
                    ),
                  );
                }
              },
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
                textStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              child: const Text('تحديث الآن'),
            ),
            const SizedBox(height: 4),
            // «لاحقاً» — إغلاق فقط.
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text(
                'لاحقاً',
                style: TextStyle(fontSize: 15, color: muted),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
