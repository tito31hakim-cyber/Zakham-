import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'admin_page.dart';
import 'cart_page.dart';
import 'contact_page.dart';
import 'notifications_page.dart';

class AccountPage extends StatelessWidget {
  const AccountPage({super.key});
  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const Padding(padding: EdgeInsets.fromLTRB(22, 34, 22, 12), child: Text('حسابي', style: TextStyle(color: cream, fontSize: 30, fontWeight: FontWeight.w600))),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 22), child: Text('كل ما تحتاجه لتجربة تسوّق مريحة مع دار زخم.', style: TextStyle(color: muted, height: 1.6))),
            const SizedBox(height: 22),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(gradient: LinearGradient(colors: [gold.withOpacity(.18), card]), borderRadius: BorderRadius.circular(20), border: Border.all(color: gold.withOpacity(.25))),
              child: const Row(children: [Icon(Icons.spa_outlined, color: gold, size: 34), SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('أهلاً بك في زخم', style: TextStyle(color: cream, fontSize: 17, fontWeight: FontWeight.w600)), SizedBox(height: 5), Text('عطور مختارة لتترك أثراً يليق بك.', style: TextStyle(color: muted, fontSize: 12))]))]),
            ),
            const SizedBox(height: 20),
            _item(context, Icons.shopping_bag_outlined, 'سلة المشتريات', 'راجع اختياراتك وأكمل طلبك', Scaffold(appBar: AppBar(title: Text('سلة المشتريات')), body: const CartPage())),
            _item(context, Icons.notifications_outlined, 'الإشعارات', 'تحديثات الطلبات والعروض والوصلات الجديدة', const NotificationsPage()),
            _item(context, Icons.support_agent, 'تواصل مع زخم', 'يسعدنا مساعدتك', const ContactPage()),
            _item(context, Icons.admin_panel_settings_outlined, 'دخول الإدارة', 'للموظفين المصرح لهم فقط', const AdminLoginPage()),
            const Padding(padding: EdgeInsets.fromLTRB(22, 24, 22, 20), child: Text('دار زخم للعطور • مصر', textAlign: TextAlign.center, style: TextStyle(color: muted, fontSize: 11))),
          ],
        ),
      );

  Widget _item(BuildContext context, IconData icon, String title, String subtitle, Widget page) => Card(
        color: card,
        margin: const EdgeInsets.fromLTRB(20, 6, 20, 6),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          leading: Icon(icon, color: gold),
          title: Text(title, style: const TextStyle(color: cream, fontSize: 15)),
          subtitle: Text(subtitle, style: const TextStyle(color: muted, fontSize: 11)),
          trailing: const Icon(Icons.arrow_back_ios_new, color: gold, size: 15),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
        ),
      );
}
