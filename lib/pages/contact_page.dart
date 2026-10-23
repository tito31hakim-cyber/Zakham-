import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../main.dart' show card, cream, gold, muted;

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
              'https://wa.me/201042881176',
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
              'https://www.instagram.com/zakham_house/',
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
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
      ),
    );
  }
}
