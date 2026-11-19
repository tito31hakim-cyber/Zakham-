import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/app_update_api.dart';

/// حوار «يوجد تحديث جديد» — يظهر عند فتح التطبيق مرة في اليوم إن
/// وُجد إصدار أحدث على المتجر.
///
/// زر «تثبيت التحديث» يفتح رابط التحميل في المتصفح؛ و«لاحقاً» يغلق
/// الحوار ويعاد التنبيه في اليوم التالي حتى التحديث. بلا تحديث
/// تلقائي وبلا تثبيت صامت — التوجيه يدوي فقط.
Future<void> showAppUpdateDialog(
  BuildContext context,
  AppUpdateInfo info, {
  Future<bool> Function(Uri uri)? launch,
}) async {
  final launchInstall = launch ??
      (Uri uri) => launchUrl(uri, mode: LaunchMode.externalApplication);
  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) => AlertDialog(
      title: const Text('يوجد تحديث جديد'),
      content: Text(
        'الإصدار ${info.versionName} من تطبيق دار زخم متاح الآن — '
        'حدّث التطبيق من المتجر لتحصل على آخر المزايا والإصلاحات.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('لاحقاً'),
        ),
        FilledButton(
          onPressed: () async {
            Navigator.of(dialogContext).pop();
            final launched = await launchInstall(Uri.parse(info.downloadUrl));
            if (!launched && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تعذّر فتح رابط التحميل على هذا الجهاز.'),
                ),
              );
            }
          },
          child: const Text('تثبيت التحديث'),
        ),
      ],
    ),
  );
}
