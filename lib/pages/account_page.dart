import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/customer_provider.dart';
import '../providers/theme_provider.dart';
import '../services/customer_auth.dart';
import '../services/favorites_offer_service.dart';
import '../services/reminder_service.dart';
import '../theme/app_theme.dart';
import 'admin_page.dart';
import 'auth_page.dart';
import 'cart_page.dart';
import 'contact_page.dart';
import 'notifications_page.dart';

String _statusLabel(String status) {
  switch (status) {
    case 'pending_transfer':
      return 'بانتظار التحويل';
    case 'paid':
      return 'تم الدفع';
    case 'processing':
      return 'قيد التجهيز';
    case 'shipped':
      return 'تم الشحن';
    case 'delivered':
      return 'تم التوصيل';
    case 'cancelled':
      return 'ملغي';
    default:
      return status.isEmpty ? '—' : status;
  }
}

class AccountPage extends StatefulWidget {
  const AccountPage({super.key, required this.onOpenSections});

  /// يفتح صفحة «الأقسام».
  final VoidCallback onOpenSections;
  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  bool _loadingOrders = false;
  String? _ordersError;
  String? _ordersLoadedFor;
  bool? _remindersEnabled;
  bool? _favOffersEnabled;

  @override
  void initState() {
    super.initState();
    _loadReminderPrefs();
  }

  Future<void> _loadReminderPrefs() async {
    final reminders = await ReminderService.instance.isEnabled();
    final favOffers = await FavoritesOfferService().isEnabled();
    if (mounted) {
      setState(() {
        _remindersEnabled = reminders;
        _favOffersEnabled = favOffers;
      });
    }
  }

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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.read<CustomerProvider>();
    final customer = provider.customer;
    if (customer == null) {
      _ordersLoadedFor = null;
    } else if (_ordersLoadedFor != customer.openId && !_loadingOrders) {
      _ordersLoadedFor = customer.openId;
      _loadOrders();
    }
  }

  Future<void> _loadOrders() async {
    final provider = context.read<CustomerProvider>();
    if (provider.customer == null || _loadingOrders) return;
    setState(() {
      _loadingOrders = true;
      _ordersError = null;
    });
    try {
      await provider.refreshOrders();
    } catch (error) {
      if (mounted) {
        setState(
          () => _ordersError =
              error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingOrders = false);
    }
  }

  Future<void> _openLogin() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const CustomerLoginPage()),
    );
  }

  Future<void> _openRegister() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const CustomerRegisterPage()),
    );
  }

  Future<void> _verifyPhone() async {
    try {
      await context.read<CustomerProvider>().beginPhoneVerification();
      if (!mounted) return;
      await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const OtpVerifyPage()),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error.toString().replaceFirst('Exception: ', ''),
            ),
          ),
        );
      }
    }
  }

  Future<void> _logout() async {
    await context.read<CustomerProvider>().logout();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تسجيل الخروج.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CustomerProvider>();
    final customer = provider.customer;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(22, 34, 22, 12),
            child: Text(
              'حسابي',
              style: TextStyle(
                color: context.ink,
                fontSize: 30,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 22),
            child: Text(
              'كل ما تحتاجه لتجربة تسوّق مريحة مع دار زخم.',
              style: TextStyle(color: context.subdued, height: 1.6),
            ),
          ),
          const SizedBox(height: 22),
          if (customer == null) _guestCard() else _memberCard(customer),
          const SizedBox(height: 20),
          _themeRow(context),
          const SizedBox(height: 8),
          _remindersRow(context),
          const SizedBox(height: 8),
          _favOffersRow(context),
          const SizedBox(height: 8),
          _item(
            context,
            Icons.grid_view_rounded,
            'أقسام زخم',
            'التشكيلة، طقس زخم، الإهداء، التغليف، باقات التوفير',
            widget.onOpenSections,
          ),
          if (customer == null) ...[
            _item(
              context,
              Icons.login,
              'تسجيل الدخول',
              'ادخل بحسابك لإتمام الطلب ومتابعة طلباتك',
              _openLogin,
            ),
            _item(
              context,
              Icons.person_add_outlined,
              'إنشاء حساب جديد',
              'حساب زخم لطلباتك وعروضك',
              _openRegister,
            ),
          ] else ...[
            _ordersSection(provider),
          ],
          _item(
            context,
            Icons.shopping_bag_outlined,
            'سلة المشتريات',
            'راجع اختياراتك وأكمل طلبك',
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => Scaffold(
                  appBar: AppBar(title: const Text('سلة المشتريات')),
                  body: const CartPage(),
                ),
              ),
            ),
          ),
          _item(
            context,
            Icons.notifications_outlined,
            'الإشعارات',
            'تحديثات الطلبات والعروض والوصلات الجديدة',
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationsPage()),
            ),
          ),
          _item(
            context,
            Icons.support_agent,
            'تواصل مع زخم',
            'يسعدنا مساعدتك',
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ContactPage()),
            ),
          ),
          _item(
            context,
            Icons.admin_panel_settings_outlined,
            'دخول الإدارة',
            'للموظفين المصرح لهم فقط',
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminLoginPage()),
            ),
          ),
          if (customer != null)
            _item(
              context,
              Icons.logout,
              'تسجيل الخروج',
              'اخرج من حسابك على هذا الجهاز',
              _logout,
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(22, 24, 22, 20),
            child: Text(
              'دار زخم للعطور • مصر',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.subdued, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  /// مبدّل الواجهة الفاتحة/الداكنة — يحفظ الاختيار على الجهاز.
  Widget _themeRow(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    return Card(
      color: context.surfaceCard,
      margin: const EdgeInsets.fromLTRB(20, 6, 20, 6),
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        secondary: Icon(
          theme.isLight ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
          color: context.goldText,
        ),
        title: Text(
          'الواجهة الفاتحة',
          style: TextStyle(color: context.ink, fontSize: 15),
        ),
        subtitle: Text(
          theme.isLight ? 'خلفية عاجية فاتحة' : 'خلفية داكنة سوداء',
          style: TextStyle(color: context.subdued, fontSize: 11),
        ),
        value: theme.isLight,
        activeColor: context.goldText,
        onChanged: theme.setLight,
      ),
    );
  }

  /// مبدّل التذكيرات المحلية (تذكير السلة وإعادة الشراء و«السلة الفارغة»).
  Widget _remindersRow(BuildContext context) {
    return Card(
      color: context.surfaceCard,
      margin: const EdgeInsets.fromLTRB(20, 6, 20, 6),
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        secondary: Icon(
          (_remindersEnabled ?? true)
              ? Icons.notifications_active_outlined
              : Icons.notifications_off_outlined,
          color: context.goldText,
        ),
        title: Text(
          'تذكيرات السلة والطلبات',
          style: TextStyle(color: context.ink, fontSize: 15),
        ),
        subtitle: Text(
          'تذكير لطيف عند ترك السلة، وإعادة الشراء بعد فترة',
          style: TextStyle(color: context.subdued, fontSize: 11),
        ),
        value: _remindersEnabled ?? true,
        activeColor: context.goldText,
        onChanged: _toggleReminders,
      ),
    );
  }

  /// مبدّل تنبيهات عروض العطور المفضلة.
  Widget _favOffersRow(BuildContext context) {
    return Card(
      color: context.surfaceCard,
      margin: const EdgeInsets.fromLTRB(20, 6, 20, 6),
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        secondary: Icon(
          Icons.local_offer_outlined,
          color: context.goldText,
        ),
        title: Text(
          'تنبيهات عروض المفضلة',
          style: TextStyle(color: context.ink, fontSize: 15),
        ),
        subtitle: Text(
          'إشعار عند نزول عرض أو انخفاض سعر عطر محفوظ',
          style: TextStyle(color: context.subdued, fontSize: 11),
        ),
        value: _favOffersEnabled ?? true,
        activeColor: context.goldText,
        onChanged: _toggleFavOffers,
      ),
    );
  }

  Widget _guestCard() => Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
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
            Icon(Icons.spa_outlined, color: context.goldText, size: 34),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'أهلاً بك في زخم',
                    style: TextStyle(
                      color: context.ink,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'عطور مختارة لتترك أثراً يليق بك.',
                    style: TextStyle(color: context.subdued, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _memberCard(Customer customer) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [gold.withOpacity(.18), context.surfaceCard],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: gold.withOpacity(.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: gold,
                  child: Icon(Icons.person, color: Colors.black),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customer.displayName,
                        style: TextStyle(
                          color: context.ink,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        customer.email,
                        style: TextStyle(color: context.subdued, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                _verifiedChip(customer.phoneVerified),
              ],
            ),
            if (customer.phone.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.phone_outlined, color: context.goldText, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    customer.phone,
                    style: TextStyle(color: context.ink, fontSize: 13),
                  ),
                ],
              ),
            ],
            if (!customer.phoneVerified) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _verifyPhone,
                  icon: const Icon(Icons.sms_outlined, size: 17),
                  label: const Text('تأكيد رقم الهاتف برمز SMS'),
                ),
              ),
            ],
          ],
        ),
      );

  Widget _verifiedChip(bool verified) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: verified ? gold.withOpacity(.16) : context.hairlineSoft,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: verified ? gold.withOpacity(.4) : context.hairline,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              verified ? Icons.verified : Icons.warning_amber_outlined,
              color: verified ? context.goldText : context.subdued,
              size: 14,
            ),
            const SizedBox(width: 4),
            Text(
              verified ? 'موثّق' : 'غير موثّق',
              style: TextStyle(
                color: verified ? context.goldText : context.subdued,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );

  Widget _ordersSection(CustomerProvider provider) {
    final orders = provider.orders;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 4, 14, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'طلباتي',
                  style: TextStyle(
                    color: context.ink,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                onPressed: _loadingOrders ? null : _loadOrders,
                icon: Icon(Icons.refresh, color: context.goldText),
                tooltip: 'تحديث الطلبات',
              ),
            ],
          ),
        ),
        if (_loadingOrders)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Center(child: CircularProgressIndicator(color: context.goldText)),
          )
        else if (_ordersError != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Text(
              _ordersError!,
              style: TextStyle(color: context.subdued, height: 1.6),
            ),
          )
        else if (orders.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 22, vertical: 6),
            child: Text(
              'لا توجد طلبات بعد — طلبك الأول بانتظارك في التشكيلة.',
              style: TextStyle(color: context.subdued, height: 1.6),
            ),
          )
        else
          ...orders.map(
            (order) => Card(
              color: context.surfaceCard,
              margin: const EdgeInsets.fromLTRB(20, 6, 20, 6),
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                leading:
                    Icon(Icons.receipt_long_outlined, color: context.goldText),
                title: Text(
                  order.orderRef,
                  style: TextStyle(
                    color: context.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  '${order.createdAt.length >= 10 ? order.createdAt.substring(0, 10) : order.createdAt} • ${_statusLabel(order.status)}',
                  style: TextStyle(color: context.subdued, fontSize: 11),
                ),
                trailing: Text(
                  '${order.total.toStringAsFixed(2)} EGP',
                  style: TextStyle(
                    color: context.goldText,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 14),
      ],
    );
  }

  Widget _item(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) =>
      Card(
        color: context.surfaceCard,
        margin: const EdgeInsets.fromLTRB(20, 6, 20, 6),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          leading: Icon(icon, color: context.goldText),
          title: Text(
            title,
            style: TextStyle(color: context.ink, fontSize: 15),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(color: context.subdued, fontSize: 11),
          ),
          trailing: Icon(
            Icons.arrow_back_ios_new,
            color: context.goldText,
            size: 15,
          ),
          onTap: onTap,
        ),
      );
}
