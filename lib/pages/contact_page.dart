import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';

class ContactPage extends StatelessWidget {
  const ContactPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('تواصل مع زخم')),
        body: ListView(
          padding: const EdgeInsets.all(22),
          children: [
            Text(
              'نحن هنا لخدمتك',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: context.ink,
                fontSize: 30,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'اختر القناة الأنسب لك: واتساب للمحادثة السريعة، أو البريد '
              'للطلبات والاستفسارات المكتوبة.',
              textAlign: TextAlign.right,
              style: TextStyle(color: context.subdued, height: 1.7),
            ),
            const SizedBox(height: 24),
            _contact(
              context,
              Icons.chat_outlined,
              'واتساب زخم',
              'راسل فريق خدمة العملاء',
              'https://wa.me/201042881176?text=%D9%85%D8%B1%D8%AD%D8%A8%D9%8B%D8%A7%D8%8C%20%D8%A3%D8%B1%D9%8A%D8%AF%20%D8%A7%D9%84%D8%A7%D8%B3%D8%AA%D9%81%D8%B3%D8%A7%D8%B1%20%D8%B9%D9%86%20%D8%B9%D8%B7%D9%88%D8%B1%20%D8%B2%D8%AE%D9%85',
            ),
            _contact(
              context,
              Icons.mail_outlined,
              'البريد الإلكتروني',
              'zakhamperfum@gmail.com',
              'mailto:zakhamperfum@gmail.com',
            ),
            _contact(
              context,
              Icons.language,
              'الموقع الإلكتروني',
              'zakhamhouse.shop',
              'https://zakhamhouse.shop',
            ),
            _contact(
              context,
              Icons.camera_alt_outlined,
              'Instagram',
              '@zakham_house',
              'https://instagram.com/zakham_house',
            ),
            _contact(
              context,
              Icons.facebook,
              'Facebook',
              'House of Zakham',
              'https://www.facebook.com/share/1E6gv4f2bK/',
            ),
            _contact(
              context,
              Icons.location_on_outlined,
              'العنوان',
              'كفر الشيخ، جمهورية مصر العربية',
              'https://www.google.com/maps/search/?api=1&query=%D9%83%D9%81%D8%B1%20%D8%A7%D9%84%D8%B4%D9%8A%D8%AE%D8%8C%20%D9%85%D8%B5%D8%B1',
            ),
          ],
        ),
      ),
    );
  }

  Widget _contact(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    String url,
  ) {
    return Card(
      color: context.surfaceCard,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: context.goldText),
        title: Text(
          title,
          textAlign: TextAlign.right,
          style: TextStyle(color: context.ink),
        ),
        subtitle: Text(
          subtitle,
          textAlign: TextAlign.right,
          style: TextStyle(color: context.subdued),
        ),
        trailing: Icon(Icons.open_in_new, color: context.goldText),
        onTap: () async {
          final uri = Uri.parse(url);
          final launched = await launchUrl(
            uri,
            mode: LaunchMode.externalApplication,
          );
          if (!launched && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('تعذر فتح الرابط على هذا الجهاز.')),
            );
          }
        },
      ),
    );
  }
}
