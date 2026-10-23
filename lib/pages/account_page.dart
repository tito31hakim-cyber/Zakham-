import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'admin_page.dart';
import 'checkout_page.dart';
import 'contact_page.dart';

class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context) => ListView(
        padding: EdgeInsets.zero,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 30, 20, 20),
            child: Text('حسابي', style: TextStyle(color: cream, fontSize: 30, fontWeight: FontWeight.w600)),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text('سجّل دخولك لمتابعة طلباتك ومفضلاتك.', style: TextStyle(color: muted)),
          ),
          const SizedBox(height: 30),
          _item(context, Icons.shopping_bag_outlined, 'سلة المشتريات', const CheckoutPage()),
          _item(context, Icons.admin_panel_settings_outlined, 'لوحة الإدارة', const AdminLoginPage()),
          _item(context, Icons.forum_outlined, 'تواصل مع زخم', const ContactPage()),
        ],
      );

  Widget _item(BuildContext context, IconData icon, String title, Widget page) => ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20),
        leading: Icon(icon, color: gold),
        title: Text(title, style: const TextStyle(color: cream, fontSize: 16)),
        trailing: const Icon(Icons.arrow_back_ios_new, color: gold, size: 16),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
      );
}
