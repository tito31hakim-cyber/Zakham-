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
            const Text(
              'نحن هنا لخدمتك',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: cream,
                fontSize: 30,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'للاستفسار عن العطور أو الطلبات أو الهدايا، تواصل معنا عبر القنوات الرسمية.',
              textAlign: TextAlign.right,
              style: TextStyle(color: muted, height: 1.7),
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
              'https://www.facebook.com/share/1FP4f85g4c/',
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
      color: card,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: gold),
        title: Text(
          title,
          textAlign: TextAlign.right,
          style: const TextStyle(color: cream),
        ),
        subtitle: Text(
          subtitle,
          textAlign: TextAlign.right,
          style: const TextStyle(color: muted),
        ),
        trailing: const Icon(Icons.open_in_new, color: gold),
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
