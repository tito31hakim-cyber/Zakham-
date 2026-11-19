import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_version.dart';
import '../providers/customer_provider.dart';
import '../providers/theme_provider.dart';
import '../services/birthday.dart';
import '../services/consultation.dart';
import '../services/customer_auth.dart';
import '../services/favorites_offer_service.dart';
import '../services/invoice_pdf.dart';
import '../services/occasions.dart';
import '../services/reminder_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'addresses_page.dart';
import 'admin_page.dart';
import 'auth_page.dart';
import 'cart_page.dart';
import 'consultation_page.dart';
import 'contact_page.dart';
import 'notifications_page.dart';

/// الهامش الموحّد لبطاقات الحساب (العناصر والمبدّلات والأقسام).
const _cardMargin = EdgeInsets.fromLTRB(20, 6, 20, 6);

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
  const AccountPage({super.key, required this.onOpenSections, this.onDailyPerfumeEnabled});

  /// يفتح صفحة «الأقسام».
  final VoidCallback onOpenSections;

  /// يُستدعى عند تفعيل مبدّل «عطر اليوم» ليعيد الغلاف جدولة إشعاره
  /// (الغلاف وحده يعرف عطر اليوم الحالي).
  final VoidCallback? onDailyPerfumeEnabled;
  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  bool _loadingOrders = false;
  String? _ordersError;

  /// انتهت الجلسة أثناء تحميل الطلبات (401) — تُعرض رسالة واضحة مع
  /// زر دخول بدل نص الخطأ الخام.
  bool _sessionExpired = false;
  String? _ordersLoadedFor;
  String? _birthdayLoadedFor;
  bool _savingBirthday = false;

  /// أرقام الطلبات الجاري توليد فاتورتها الآن (لمنع الضغط المزدوج).
  final Set<String> _generatingInvoices = <String>{};

  /// أرقام الطلبات الجاري إعادة رفع إثبات دفعها الآن.
  final Set<String> _resubmittingReceipts = <String>{};
  bool? _remindersEnabled;
  bool? _favOffersEnabled;
  bool? _dailyPerfumeEnabled;

  @override
  void initState() {
    super.initState();
    _loadReminderPrefs();
  }

  Future<void> _loadReminderPrefs() async {
    final reminders = await ReminderService.instance.isEnabled();
    final favOffers = await FavoritesOfferService().isEnabled();
    final dailyPerfume =
        await ReminderService.instance.isDailyPerfumeEnabled();
    if (mounted) {
      setState(() {
        _remindersEnabled = reminders;
        _favOffersEnabled = favOffers;
        _dailyPerfumeEnabled = dailyPerfume;
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

  Future<void> _toggleDailyPerfume(bool value) async {
    setState(() => _dailyPerfumeEnabled = value);
    await ReminderService.instance.setDailyPerfumeEnabled(value);
    if (value) widget.onDailyPerfumeEnabled?.call();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value
              ? 'سيصلك إشعار «عطر اليوم» كل يوم الساعة 6 مساءً.'
              : 'أُوقف إشعار «عطر اليوم» اليومي.'),
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
      _birthdayLoadedFor = null;
    } else if (_ordersLoadedFor != customer.openId && !_loadingOrders) {
      _ordersLoadedFor = customer.openId;
      _loadOrders();
    }
    if (customer != null && _birthdayLoadedFor != customer.openId) {
      _birthdayLoadedFor = customer.openId;
      unawaited(provider.refreshBirthday());
    }
  }

  Future<void> _loadOrders() async {
    final provider = context.read<CustomerProvider>();
    if (provider.customer == null || _loadingOrders) return;
    setState(() {
      _loadingOrders = true;
      _ordersError = null;
      _sessionExpired = false;
    });
    try {
      await provider.refreshOrders();
    } on AuthRequiredException {
      // الجلسة انتهت: المزوّد أسقطها محلياً أصلاً، فتُعرض رسالة
      // واضحة مع زر دخول بدل نص خطأ خام.
      if (mounted) setState(() => _sessionExpired = true);
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

  /// تنزيل فاتورة طلب مدفوع PDF ومشاركتها — تُجلب تفاصيل الفاتورة
  /// من الخادم أولاً (أصناف الطلب وحالة الدفع). الزر نفسه لا يظهر
  /// إلا للطلبات المدفوعة، وأي فشل هنا يظهر رسالة ولا يعطّل الصفحة.
  Future<void> _downloadInvoice(CustomerOrder order) async {
    if (_generatingInvoices.contains(order.orderRef)) return;
    setState(() => _generatingInvoices.add(order.orderRef));
    try {
      final provider = context.read<CustomerProvider>();
      final invoice = await provider.fetchInvoice(order.orderRef);
      if (!mounted) return;
      if (invoice == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر تحميل تفاصيل الطلب.')),
        );
        return;
      }
      if (!invoice.isPaid) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('الفاتورة متاحة بعد تأكيد الدفع.'),
          ),
        );
        return;
      }
      await InvoicePdfService.sharePdf(invoice, context);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تعذر توليد الفاتورة. ${error.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _generatingInvoices.remove(order.orderRef));
    }
  }

  /// إعادة رفع إثبات دفع لطلب رُفض إثباته — يختار العميل ملفاً
  /// (صورة أو PDF حتى 5MB كما يقبل الخادم) فيُرفع إلى نقطة إعادة
  /// الإرسال، وتتحدث حالة الدفع في القائمة إلى «أُرسل الإثبات».
  Future<void> _resubmitReceipt(CustomerOrder order) async {
    if (_resubmittingReceipts.contains(order.orderRef)) return;
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
    );
    if (file == null) return;
    List<int>? bytes;
    try {
      bytes = await file.readAsBytes();
    } catch (_) {
      bytes = null;
    }
    if (bytes == null || bytes.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذّر قراءة الملف المختار.')),
        );
      }
      return;
    }
    if (bytes.length > 5 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('حجم الملف يتجاوز 5MB — اختر ملفاً أصغر.'),
          ),
        );
      }
      return;
    }
    setState(() => _resubmittingReceipts.add(order.orderRef));
    try {
      final provider = context.read<CustomerProvider>();
      await provider.resubmitReceipt(order.orderRef, bytes, file.name);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إرسال إثبات الدفع الجديد — سيُراجعه فريق زخم.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _resubmittingReceipts.remove(order.orderRef));
      }
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

  /// الخروج من كل الأجهزة — بتأكيد أولاً لأنه يشمل هذا الجهاز.
  /// نقطة الخادم جديدة؛ إن لم تُنشر بعد تُظهر الواجهة رسالة واضحة
  /// ويبقى العميل مسجَّلاً هنا.
  Future<void> _logoutFromAllDevices() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تسجيل الخروج من كل الأجهزة؟'),
        content: const Text(
          'سيتم تسجيل خروج حسابك من جميع أجهزتك، بما فيها هذا الجهاز، وستحتاج إلى تسجيل الدخول مجدداً.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('تأكيد الخروج'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await context.read<CustomerProvider>().logoutFromAllDevices();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تسجيل الخروج من كل الأجهزة.')),
      );
    } on LogoutAllUnavailableException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
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
          const SizedBox(height: 8),
          // عنوان الصفحة «حسابي» هو نفسه عنوان المجموعة الأولى.
          if (customer == null) _guestCard() else _memberCard(customer),
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
            _item(
              context,
              Icons.location_on_outlined,
              'عناويني المحفوظة',
              'أضف عناوينك لاختيارها بضغطة واحدة عند إتمام الطلب',
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddressesPage(
                    addressBook: provider.addressBook,
                    ownerKey: provider.addressOwnerKey,
                  ),
                ),
              ),
            ),
          ],
          _ConsultationsSection(
            consultations: provider.consultations,
            ownerKey: provider.addressOwnerKey,
          ),
          if (customer != null) ...[
            const AccountGroupHeader(title: 'الولاء والمكافآت'),
            _loyaltyCard(customer),
            const SizedBox(height: 12),
            _birthdaySection(provider),
          ],
          const AccountGroupHeader(title: 'التذكيرات'),
          _remindersRow(context),
          _favOffersRow(context),
          _dailyPerfumeRow(context),
          const AccountGroupHeader(title: 'روابط سريعة'),
          _item(
            context,
            Icons.grid_view_rounded,
            'أقسام زخم',
            'التشكيلة، طقس زخم، الإهداء، التغليف، باقات التوفير',
            widget.onOpenSections,
          ),
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
          const AccountGroupHeader(title: 'الإعدادات'),
          _themeRow(context),
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
          if (customer != null)
            _item(
              context,
              Icons.devices_outlined,
              'تسجيل الخروج من كل الأجهزة',
              'اخرج من حسابك على جميع أجهزتك',
              _logoutFromAllDevices,
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(22, 24, 22, 20),
            child: Column(
              children: [
                Text(
                  'دار زخم للعطور • مصر',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.subdued, fontSize: 11),
                ),
                const SizedBox(height: 4),
                // هوية النسخة للعميل — الإصدار فقط؛ التفاصيل (رقم البناء
                // والـ Commit) للتشخيص وتظهر بضغطة مطولة.
                GestureDetector(
                  onLongPress: () => showDialog<void>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('تفاصيل النسخة'),
                      content: Text(AppVersion.display),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('إغلاق'),
                        ),
                      ],
                    ),
                  ),
                  child: Text(
                    AppVersion.customerDisplay,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.subdued, fontSize: 11),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '© 2026 دار زخم للعطور — جميع الحقوق محفوظة',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.subdued, fontSize: 11),
                ),
              ],
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
      margin: _cardMargin,
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
      margin: _cardMargin,
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
      margin: _cardMargin,
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

  /// بطاقة رصيد نقاط الولاء — في مجموعة «الولاء والمكافآت» لا داخل
  /// بطاقة العضو، لتبقى المكافآت في مكان واحد مع هدية عيد الميلاد.
  /// غياب الرصيد (null) يعني أن نقطة الولاء لم تُنشر بعد فيُعرض
  /// «قريباً» لا صفراً.
  Widget _loyaltyCard(Customer customer) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.surfaceCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.stars_outlined, color: context.goldText, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'نقاط الولاء',
                    style: TextStyle(
                      color: context.ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: gold.withOpacity(.16),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    customer.pointsBalance == null
                        ? 'قريباً'
                        : '${customer.pointsBalance} نقطة',
                    style: TextStyle(
                      color: context.goldText,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              customer.pointsBalance == null
                  ? 'نقاط الولاء — قريباً'
                  : 'نقاط الولاء: ${customer.pointsBalance} نقطة — تساوي ${customer.pointsBalance} جنيه خصم',
              style: TextStyle(color: context.subdued, fontSize: 12, height: 1.7),
            ),
            if (customer.pointsBalance != null) ...[
              const SizedBox(height: 4),
              Text(
                'تُضاف النقاط بعد توصيل طلبك (5 نقاط لكل 100 جنيه من سعر العطور).',
                style: TextStyle(color: context.subdued, fontSize: 11, height: 1.5),
              ),
            ],
          ],
        ),
      );

  /// قسم تاريخ الميلاد — يُسجَّل مرة واحدة فقط: الحقل يصبح للقراءة
  /// فقط بعد أول حفظ (التغيير فقط عن طريق الدار)، وفي أسبوع عيد
  /// الميلاد يظهر بانر الهدية الذهبي (الخصم يُطبَّق من الخادم).
  Widget _birthdaySection(CustomerProvider provider) {
    final birthday = provider.birthday;
    final now = DateTime.now();
    final inWeek = birthday != null && isInBirthdayWeek(birthday, now);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: inWeek ? gold.withOpacity(.14) : context.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: inWeek ? gold.withOpacity(.5) : context.hairline,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cake_outlined, color: context.goldText, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'هدية عيد ميلادك',
                  style: TextStyle(
                    color: context.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (birthday != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: gold.withOpacity(.16),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'مسجَّل',
                    style: TextStyle(
                      color: context.goldText,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (birthday == null) ...[
            Text(
              'في أسبوع عيد ميلادك من كل عام، تهديك الدار خصماً على طلب واحد — يُطبَّق تلقائياً عند إتمام الطلب. سجّل تاريخ ميلادك مرة واحدة، فهو ثابت ولا يُغيَّر بعد التسجيل.',
              style: TextStyle(color: context.subdued, fontSize: 12, height: 1.7),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _savingBirthday ? null : _pickAndSaveBirthday,
                icon: const Icon(Icons.calendar_today_outlined, size: 17),
                label: Text(
                  _savingBirthday ? 'جارٍ الحفظ…' : 'سجّل تاريخ ميلادك',
                ),
              ),
            ),
          ] else ...[
            Text(
              formatBirthdayAr(formatBirthday(birthday)),
              style: TextStyle(
                color: context.ink,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'مسجَّل ولا يمكن تغييره — للتغيير تواصل مع الدار.',
              style: TextStyle(color: context.subdued, fontSize: 11, height: 1.6),
            ),
            if (inWeek) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: gold.withOpacity(.18),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: gold.withOpacity(.4)),
                ),
                child: Text(
                  'عيد ميلاد سعيد — هديتك من الدار: خصم على طلب واحد خلال هذا الأسبوع، يُطبَّق تلقائياً عند إتمام الطلب.',
                  style: TextStyle(
                    color: context.goldText,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.7,
                  ),
                ),
              ),
            ] else ...[
              const SizedBox(height: 6),
              Text(
                'عيد ميلادك بعد ${daysUntilBirthday(birthday, now)} يوم — هديتك بانتظارك.',
                style: TextStyle(color: context.subdued, fontSize: 12),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Future<void> _pickAndSaveBirthday() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(1995, 1, 1),
      firstDate: DateTime(1926, 1, 1),
      lastDate: DateTime.now(),
      helpText: 'اختر تاريخ ميلادك',
      cancelText: 'إلغاء',
      confirmText: 'تأكيد',
    );
    if (picked == null || !mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد تاريخ الميلاد'),
        content: Text(
          '${formatBirthdayAr(formatBirthday(picked))}\n\nبعد الحفظ لا يمكن تغييره إطلاقاً — هل أنت متأكد؟',
          style: const TextStyle(height: 1.8),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('تأكيد الحفظ'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _savingBirthday = true);
    try {
      final provider = context.read<CustomerProvider>();
      await provider.birthdayService.save(
        ownerKey: provider.addressOwnerKey,
        birthday: picked,
      );
      await provider.refreshBirthday();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تسجيل تاريخ ميلادك — هديتك السنوية بانتظارك.'),
          ),
        );
      }
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
    } finally {
      if (mounted) setState(() => _savingBirthday = false);
    }
  }

  /// مبدّل إشعار «عطر اليوم» اليومي (الساعة 6 مساءً).
  Widget _dailyPerfumeRow(BuildContext context) {
    return Card(
      color: context.surfaceCard,
      margin: _cardMargin,
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        secondary: Icon(
          Icons.calendar_today_outlined,
          color: context.goldText,
        ),
        title: Text(
          'عطر اليوم',
          style: TextStyle(color: context.ink, fontSize: 15),
        ),
        subtitle: Text(
          'إشعار يومي الساعة 6 مساءً بعطر مختلف كل يوم',
          style: TextStyle(color: context.subdued, fontSize: 11),
        ),
        value: _dailyPerfumeEnabled ?? true,
        activeColor: context.goldText,
        onChanged: _toggleDailyPerfume,
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
        else if (_sessionExpired)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'انتهت جلستك — سجّل الدخول مجدداً لمتابعة طلباتك.',
                  style: TextStyle(color: context.subdued, height: 1.6),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: _openLogin,
                    child: const Text('تسجيل الدخول'),
                  ),
                ),
              ],
            ),
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
              margin: _cardMargin,
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
                // زر الفاتورة يظهر فقط للطلبات المدفوعة (paymentStatus
                // verified/paid) — غير المدفوعة بلا زر أصلاً.
                trailing: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${order.total.toStringAsFixed(2)} EGP',
                      style: TextStyle(
                        color: context.goldText,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (InvoicePdfService.canDownloadForPaymentStatus(
                      order.paymentStatus,
                    ))
                      TextButton(
                        onPressed: _generatingInvoices.contains(order.orderRef)
                            ? null
                            : () => _downloadInvoice(order),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          _generatingInvoices.contains(order.orderRef)
                              ? 'جارٍ التجهيز…'
                              : 'تنزيل الفاتورة PDF',
                          style: TextStyle(
                            color: context.goldText,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    // إعادة رفع إثبات الدفع — فقط للطلبات التي رفض
                    // فريق زخم إثباتها (الخادم نفسه يرفض غيرها 409).
                    if (order.paymentStatus == 'rejected' &&
                        order.status != 'cancelled')
                      TextButton(
                        onPressed: _resubmittingReceipts.contains(order.orderRef)
                            ? null
                            : () => _resubmitReceipt(order),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          _resubmittingReceipts.contains(order.orderRef)
                              ? 'جارٍ الرفع…'
                              : 'إعادة رفع إثبات الدفع',
                          style: TextStyle(
                            color: context.goldText,
                            fontSize: 11,
                          ),
                        ),
                      ),
                  ],
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
        margin: _cardMargin,
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

/// قسم «استشاراتي» — طلبات الاستشارة العطرية المحفوظة محلياً
/// (التاريخ والوقت والنوع والحالة) مع زر لحجز استشارة جديدة.
/// يظهر لكل المستخدمين (حساب أو ضيف) بمفتاح حسابه.
class _ConsultationsSection extends StatefulWidget {
  const _ConsultationsSection({
    required this.consultations,
    required this.ownerKey,
  });

  final ConsultationService consultations;
  final String ownerKey;

  @override
  State<_ConsultationsSection> createState() => _ConsultationsSectionState();
}

class _ConsultationsSectionState extends State<_ConsultationsSection> {
  List<ConsultationRequest> _requests = const <ConsultationRequest>[];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final requests =
        await widget.consultations.load(ownerKey: widget.ownerKey);
    if (mounted) {
      setState(() {
        _requests = requests;
        _loaded = true;
      });
    }
  }

  Future<void> _openBooking() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ConsultationPage(
          consultations: widget.consultations,
          ownerKey: widget.ownerKey,
        ),
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: context.surfaceCard,
      margin: _cardMargin,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.support_agent, color: context.goldText, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'استشاراتي',
                    style: TextStyle(
                      color: context.ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _openBooking,
                  child: const Text('احجز استشارة'),
                ),
              ],
            ),
            if (!_loaded)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(),
              )
            else if (_requests.isEmpty)
              Text(
                'لم تحجز أي استشارة بعد — اختر يومك ووقتك المفضلين وسيتواصل معك فريق الدار.',
                style: TextStyle(color: context.subdued, fontSize: 12, height: 1.7),
              )
            else
              ..._requests.map((request) {
                final date = DateTime.tryParse(request.date);
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Icon(Icons.event_outlined,
                          color: context.goldText, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${date == null ? request.date : formatArabicDate(date)} • ${request.timeLabel} • ${request.typeLabel}',
                          style: TextStyle(color: context.ink, fontSize: 13),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: gold.withOpacity(.14),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          request.statusLabel,
                          style: TextStyle(
                            color: context.goldText,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
