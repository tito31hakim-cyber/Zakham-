import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// رابط قناة تليجرام الرسمية لدار زخم — وجهة زر «تحديث الآن» في
/// حوار التحديث: المنشور المثبّت فيها فيه رابط تحميل الـ APK من
/// المتجر (ملف الـ APK نفسه لا يُرفع على تليجرام أبداً، بل يبقى
/// على الموقع ويُستبدل بكل بناء جديد على نفس العنوان).
const zakhamTelegramChannelUrl = 'https://t.me/zakhamapp';

/// حوار «تحديث جديد» — يظهر عند فتح التطبيق كلما أعلنت نقطة
/// /api/app/latest عن versionCode أحدث من المثبَّت.
///
/// زر «تحديث الآن» يفتح قناة تليجرام؛ و«لاحقاً» يغلق الحوار
/// فقط، ويظهر الحوار مجدداً عند الفتح التالي طالما التحديث
/// معلّق — الرفض لا يُحفظ أبداً. بلا تحديث تلقائي وبلا تثبيت
/// صامت — التوجيه يدوي فقط.
Future<void> showAppUpdateDialog(
  BuildContext context, {
  Future<bool> Function(Uri uri)? launch,
}) async {
  final launchTelegram = launch ??
      (Uri uri) => launchUrl(uri, mode: LaunchMode.externalApplication);
  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) => AlertDialog(
      title: const Text('تحديث جديد'),
      content: const Text(
        'يوجد تحديث جديد لتطبيق دار زخم — حدّث التطبيق للحصول على '
        'جميع المزايا الحديثة لدار زخم.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('لاحقاً'),
        ),
        FilledButton(
          onPressed: () async {
            Navigator.of(dialogContext).pop();
            final launched =
                await launchTelegram(Uri.parse(zakhamTelegramChannelUrl));
            if (!launched && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تعذّر فتح قناة تليجرام على هذا الجهاز.'),
                ),
              );
            }
          },
          child: const Text('تحديث الآن'),
        ),
      ],
    ),
  );
}
