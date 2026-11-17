import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/cart_item.dart';
import '../providers/cart_provider.dart';
import '../providers/customer_provider.dart';
import '../services/loyalty.dart';
import '../services/order_api.dart';
import '../services/reminder_service.dart';
import '../theme/app_theme.dart';
import 'auth_page.dart';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final formKey = GlobalKey<FormState>();
  final name = TextEditingController();
  final phone = TextEditingController();
  final address = TextEditingController();
  String? selectedGovernorate;
  String payment = 'InstaPay | إنستاباي';
  bool _prefilled = false;
  // نقاط الولاء: تُقرأ من الخادم (best-effort) وتُستبدل كخصم جنيه
  // بجنيه — الخادم يعيد التحقق والخصم بنفسه، والتطبيق لا يمنح
  // ولا يخصم محلياً أبداً.
  bool _usePoints = false;
  int _pointsToUse = 0;
  // معرّف الحساب الذي حُدّث رصيد نقاطه آخر مرة — يتغير عند تسجيل
  // الدخول بعد فتح الصفحة كضيف فيُحدَّث الرصيد حينها.
  String? _pointsRefreshedFor;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Prefill the delivery form from the signed-in member profile.
    if (!_prefilled) {
      final customer = context.read<CustomerProvider>().customer;
      if (customer != null) {
        _prefilled = true;
        if (name.text.isEmpty) name.text = customer.displayName;
        if (phone.text.isEmpty) phone.text = customer.phone;
      }
    }
    // رصيد النقاط من الخادم (مرة لكل حساب) — غيابه يعني أن نقطة
    // الولاء لم تُنشر بعد فيُخفى الاستبدال بهدوء.
    final provider = context.read<CustomerProvider>();
    final openId = provider.customer?.openId;
    if (provider.isAuthenticated &&
        openId != null &&
        openId.isNotEmpty &&
        _pointsRefreshedFor != openId) {
      _pointsRefreshedFor = openId;
      unawaited(provider.refreshPoints());
    }
  }

  /// رسوم الشحن الموحّدة في المتجر الحي لجميع المحافظات (جنيه).
  /// الخادم يعيد حساب الشحن والإجمالي بنفسه من المحافظة، وهذه القيمة
  /// للعرض فقط ويجب أن تطابق تعرفة المتجر.
  static const double shippingFee = 120;
  static const String shippingLabel = 'شحن لجميع المحافظات — 120 ج.م';
  bool submitting = false;

  static const governorates = <String>[
    'القاهرة', 'الجيزة', 'الإسكندرية', 'القليوبية', 'الدقهلية', 'البحر الأحمر',
    'البحيرة', 'الفيوم', 'الغربية', 'الإسماعيلية', 'المنوفية', 'المنيا',
    'أسيوط', 'الوادي الجديد', 'بني سويف', 'بورسعيد', 'دمياط',
    'جنوب سيناء', 'كفر الشيخ', 'مطروح', 'الأقصر', 'قنا', 'شمال سيناء',
    'سوهاج', 'السويس', 'أسوان', 'الشرقية',
  ];

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    address.dispose();
    super.dispose();
  }

  String _normalizeDigits(String value) {
    const arabic = '٠١٢٣٤٥٦٧٨٩';
    const persian = '۰۱۲۳۴۵۶۷۸۹';
    final output = StringBuffer();
    for (final rune in value.runes) {
      final character = String.fromCharCode(rune);
      final arabicIndex = arabic.indexOf(character);
      final persianIndex = persian.indexOf(character);
      if (arabicIndex >= 0) {
        output.write(arabicIndex);
      } else if (persianIndex >= 0) {
        output.write(persianIndex);
      } else if (RegExp(r'[0-9]').hasMatch(character)) {
        output.write(character);
      }
    }
    return output.toString();
  }

  /// الخصم بالنقاط لهذا الطلب (جنيه) كما اختاره العميل: 0 إن لم يفعّل
  /// الاستبدال، وإلا العدد المختار مقصوصاً إلى المسموح (الرصيد
  /// والحد الأدنى 50 والسقف = مجموع المنتجات).
  int _pointsDiscount(double subtotal) {
    if (!_usePoints) return 0;
    final balance = context.read<CustomerProvider>().pointsBalance;
    if (balance == null) return 0;
    return clampPointsUsed(
      balance: balance,
      productsSubtotal: subtotal,
      requested: _pointsToUse,
    );
  }

  Future<void> submit() async {
    if (submitting) return;
    if (!formKey.currentState!.validate()) return;
    final customerProvider = context.read<CustomerProvider>();
    // The server refuses guest checkout (401 login_required_for_checkout):
    // a signed-in member session is required before the order is sent.
    if (!customerProvider.isAuthenticated) {
      final signedIn = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const CustomerLoginPage()),
      );
      if (!mounted) return;
      if (signedIn != true || !customerProvider.isAuthenticated) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('سجّل الدخول إلى حسابك أولاً لإتمام الطلب.'),
          ),
        );
        return;
      }
      final customer = customerProvider.customer;
      if (customer != null) {
        if (name.text.isEmpty) name.text = customer.displayName;
        if (phone.text.isEmpty) phone.text = customer.phone;
      }
    }
    final cart = context.read<CartProvider>();
    if (cart.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('السلة فارغة. أضف عطراً قبل إرسال الطلب.')),
      );
      return;
    }

    setState(() => submitting = true);
    try {
      // الخصم بالنقاط كما يراه العميل؛ الخادم يعيد التحقق من الرصيد
      // والحد الأدنى والسقف قبل الخصم، وأي رفض منه يُظهر رسالته.
      final pointsDiscount = _pointsDiscount(cart.subtotal);
      final result = await OrderApi(
        credentials: customerProvider.credentials,
      ).createOrder(
        customerName: name.text.trim(),
        phone: _normalizeDigits(phone.text),
        governorate: selectedGovernorate!,
        address: address.text.trim(),
        paymentMethod: payment,
        items: cart.items,
        // الشحن موحّد 120 ج.م لجميع المحافظات في المتجر الحي؛
        // الخادم يعيد حسابه والإجمالي من المحافظة قبل الحفظ.
        shippingFee: shippingFee,
        shippingLabel: shippingLabel,
        pointsUsed: pointsDiscount,
      );

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          icon: Icon(Icons.check_circle_outline, color: context.goldText, size: 42),
          title: const Text('تم استلام طلبك'),
          content: Text(
            'رقم الطلب: ${result.orderRef}\n'
            'الإجمالي شامل الشحن: ${result.total.toStringAsFixed(2)} EGP\n'
            'الدفع مسبقاً عبر ${payment.split('|').first.trim()}؛ سيتواصل معك فريق زخم عبر واتساب بتعليمات التحويل.',
            textAlign: TextAlign.right,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('حسنًا'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      // تذكير إعادة الشراء بعد 60 يوماً (best-effort — لا يعطّل الطلب).
      // يُلتقط محتوى السلة قبل إفراغها، وتذكير السلة يُلغى ضمناً.
      final orderedItems = cart.items;
      unawaited(ReminderService.instance.onOrderCompleted(
        orderRef: result.orderRef,
        items: orderedItems,
      ));
      // الرصيد تغيّر عند الاستبدال (الخادم خصمه) — يُحدَّث بهدوء.
      // النقاط المكتسبة من هذا الطلب نفسها لا تظهر إلا بعد التوصيل.
      unawaited(context.read<CustomerProvider>().refreshPoints());
      cart.clear();
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      final message = error.toString().replaceFirst('Exception: ', '');
      // A dead session reports "سجّل الدخول" — forget it locally so the
      // next attempt asks for sign-in instead of failing the same way.
      final needsLogin = message.contains('سجّل الدخول');
      if (needsLogin) {
        await context.read<CustomerProvider>().dropSession();
        if (!mounted) return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر إرسال الطلب. بقيت السلة محفوظة.\n$message'),
          action: needsLogin
              ? SnackBarAction(
                  label: 'تسجيل الدخول',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CustomerLoginPage(),
                      ),
                    );
                  },
                )
              : SnackBarAction(label: 'حسنًا', onPressed: () {}),
          duration: const Duration(seconds: 6),
        ),
      );
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final pointsBalance = context.watch<CustomerProvider>().pointsBalance;
    final maxRedeem = pointsBalance == null
        ? 0
        : maxRedeemablePoints(
            balance: pointsBalance,
            productsSubtotal: cart.subtotal,
          );
    final pointsDiscount = _usePoints
        ? clampPointsUsed(
            balance: pointsBalance ?? 0,
            productsSubtotal: cart.subtotal,
            requested: _pointsToUse,
          )
        : 0;
    final total = cart.subtotal - pointsDiscount + shippingFee;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('إتمام الطلب')),
        body: Form(
          key: formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
            children: [
              const _ProgressHeader(),
              const SizedBox(height: 22),
              _sectionTitle('١. بيانات التوصيل', 'أدخل معلومات استلام الطلب'),
              const SizedBox(height: 14),
              _textField(
                controller: name,
                label: 'الاسم الكامل',
                hint: 'كما تحب أن نناديك',
                icon: Icons.person_outline,
                textInputAction: TextInputAction.next,
                validator: (value) => (value?.trim().length ?? 0) < 3
                    ? 'اكتب الاسم الكامل'
                    : null,
              ),
              _textField(
                controller: phone,
                label: 'رقم الهاتف',
                hint: 'مثال: 01xxxxxxxxx',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                validator: (value) {
                  final digits = _normalizeDigits(value ?? '');
                  if (digits.length < 10 || digits.length > 14) {
                    return 'أدخل رقم هاتف صحيحاً مع رمز الدولة عند الحاجة';
                  }
                  return null;
                },
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: DropdownButtonFormField<String>(
                  value: selectedGovernorate,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'المحافظة',
                    hintText: 'اختر محافظة التوصيل',
                    prefixIcon: Icon(Icons.map_outlined),
                  ),
                  items: governorates
                      .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                      .toList(growable: false),
                  onChanged: (value) => setState(() => selectedGovernorate = value),
                  validator: (value) => value == null ? 'اختر المحافظة' : null,
                ),
              ),
              _textField(
                controller: address,
                label: 'العنوان بالتفصيل',
                hint: 'المنطقة، الشارع، رقم المبنى، وعلامة مميزة',
                icon: Icons.location_on_outlined,
                maxLines: 3,
                textInputAction: TextInputAction.newline,
                validator: (value) => (value?.trim().length ?? 0) < 8
                    ? 'أضف تفاصيل كافية للوصول إليك'
                    : null,
              ),
              const SizedBox(height: 12),
              _sectionTitle('٢. طريقة الدفع', 'الدفع مسبقاً — اختر الطريقة المناسبة لك'),
              const SizedBox(height: 10),
              _paymentCard(
                value: 'InstaPay | إنستاباي',
                title: 'إنستاباي',
                subtitle: 'تحويل فوري مسبق. لا تُجرِ التحويل قبل أن يؤكد المتجر قيمة الطلب وتعليمات الدفع عبر واتساب.',
                icon: Icons.account_balance_outlined,
              ),
              _paymentCard(
                value: 'Vodafone Cash | فودافون كاش',
                title: 'فودافون كاش',
                subtitle: 'محفظة إلكترونية مسبقة الدفع. لا تُجرِ التحويل قبل أن يؤكد المتجر قيمة الطلب وتعليمات الدفع عبر واتساب.',
                icon: Icons.account_balance_wallet_outlined,
              ),
              const SizedBox(height: 22),
              if (pointsBalance != null)
                _loyaltyCard(pointsBalance, maxRedeem, pointsDiscount, cart.subtotal),
              if (pointsBalance != null) const SizedBox(height: 14),
              _orderSummary(cart.items, cart.subtotal, pointsDiscount),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: gold.withOpacity(.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: gold.withOpacity(.24)),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.info_outline, color: context.goldText, size: 19),
                  SizedBox(width: 9),
                  Expanded(child: Text(
                    'رسوم التوصيل 120 ج.م لجميع المحافظات ومضافة إلى الإجمالي أدناه. الدفع مسبقاً عبر إنستاباي أو فودافون كاش بعد تأكيد المتجر لتعليمات التحويل.',
                    style: TextStyle(color: context.subdued, fontSize: 12, height: 1.55),
                  )),
                ]),
              ),
            ],
          ),
        ),
        bottomNavigationBar: cart.items.isEmpty
            ? null
            : SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
                  decoration: BoxDecoration(
                    color: context.surfaceCard,
                    border: Border(top: BorderSide(color: context.hairline)),
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Row(children: [
                      Expanded(child: Text('إجمالي المنتجات', style: TextStyle(color: context.subdued, fontSize: 12))),
                      Text('${cart.subtotal.toStringAsFixed(2)} EGP', style: TextStyle(color: context.ink, fontSize: 15, fontWeight: FontWeight.w600)),
                    ]),
                    const SizedBox(height: 4),
                    if (pointsDiscount > 0)
                      Row(children: [
                        Expanded(child: Text('خصم نقاط الولاء', style: TextStyle(color: context.subdued, fontSize: 12))),
                        Text('-${pointsDiscount.toStringAsFixed(2)} EGP', style: TextStyle(color: context.goldText, fontSize: 15, fontWeight: FontWeight.w600)),
                      ]),
                    if (pointsDiscount > 0) const SizedBox(height: 4),
                    Row(children: [
                      Expanded(child: Text('التوصيل (جميع المحافظات)', style: TextStyle(color: context.subdued, fontSize: 12))),
                      Text('120.00 EGP', style: TextStyle(color: context.ink, fontSize: 15, fontWeight: FontWeight.w600)),
                    ]),
                    const SizedBox(height: 6),
                    Row(children: [
                      Expanded(child: Text('الإجمالي شامل الشحن', style: TextStyle(color: context.ink, fontSize: 14, fontWeight: FontWeight.w700))),
                      Text('${total.toStringAsFixed(2)} EGP', style: TextStyle(color: context.goldText, fontSize: 18, fontWeight: FontWeight.w700)),
                    ]),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: submitting ? null : submit,
                        icon: submitting
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                            : const Icon(Icons.lock_outline),
                        label: Text(submitting ? 'جارٍ إرسال الطلب...' : 'إرسال الطلب للمراجعة'),
                      ),
                    ),
                  ]),
                ),
              ),
      ),
    );
  }

  Widget _sectionTitle(String title, String subtitle) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: context.ink, fontSize: 19, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(color: context.subdued, fontSize: 12)),
        ],
      );

  Widget _textField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required String? Function(String?) validator,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    int maxLines = 1,
  }) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          maxLines: maxLines,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: label, hintText: hint, prefixIcon: Icon(icon)),
          validator: validator,
        ),
      );

  Widget _paymentCard({
    required String value,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = payment == value;
    return Card(
      color: isSelected ? gold.withOpacity(.10) : context.surfaceCard,
      margin: const EdgeInsets.only(bottom: 9),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: isSelected ? gold : context.hairline),
      ),
      child: RadioListTile<String>(
        value: value,
        groupValue: payment,
        onChanged: submitting ? null : (next) => setState(() => payment = next!),
        activeColor: gold,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        secondary: Icon(icon, color: context.goldText),
        title: Text(title, style: TextStyle(color: context.ink, fontWeight: FontWeight.w600)),
        subtitle: Padding(padding: const EdgeInsets.only(top: 5), child: Text(subtitle, style: TextStyle(color: context.subdued, fontSize: 11, height: 1.45))),
      ),
    );
  }

  /// بطاقة استبدال نقاط الولاء — تظهر فقط عندما يعيد الخادم رصيداً
  /// (غيابه يعني أن نقطة الولاء لم تُنشر بعد فيُخفى الاستبدال).
  /// الاستبدال من 50 نقطة، والخصم جنيه بجنيه بحد أقصى مجموع المنتجات.
  Widget _loyaltyCard(
    int balance,
    int maxRedeem,
    int pointsDiscount,
    double subtotal,
  ) {
    final canRedeem = canRedeemPoints(balance) && maxRedeem >= minRedeemPoints;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: gold.withOpacity(.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: gold.withOpacity(.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.stars_outlined, color: context.goldText, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'نقاط الولاء',
              style: TextStyle(
                color: context.ink,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            '$balance نقطة',
            style: TextStyle(
              color: context.goldText,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ]),
        const SizedBox(height: 6),
        Text(
          canRedeem
              ? 'رصيدك يساوي $balance جنيه خصم. فعّل الاستبدال واختر عدد النقاط.'
              : 'اجمع ${minRedeemPoints - balance} نقطة أخرى لتبدأ الاستبدال (من 50 نقطة). النقاط تُضاف بعد توصيل طلبك.',
          style: TextStyle(color: context.subdued, fontSize: 12, height: 1.6),
        ),
        if (canRedeem) ...[
          const SizedBox(height: 6),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'استخدم نقاطي في هذا الطلب',
              style: TextStyle(color: context.ink, fontSize: 14),
            ),
            subtitle: Text(
              'الخصم: $pointsDiscount جنيه من الإجمالي',
              style: TextStyle(color: context.subdued, fontSize: 11),
            ),
            value: _usePoints,
            activeColor: context.goldText,
            onChanged: submitting
                ? null
                : (value) => setState(() {
                      _usePoints = value;
                      if (value) _pointsToUse = maxRedeem;
                    }),
          ),
          if (_usePoints && maxRedeem > minRedeemPoints)
            Row(children: [
              Expanded(
                child: Slider(
                  value: _pointsToUse
                      .toDouble()
                      .clamp(minRedeemPoints.toDouble(), maxRedeem.toDouble()),
                  min: minRedeemPoints.toDouble(),
                  max: maxRedeem.toDouble(),
                  divisions: maxRedeem - minRedeemPoints,
                  activeColor: context.goldText,
                  onChanged: submitting
                      ? null
                      : (value) => setState(() => _pointsToUse = value.round()),
                ),
              ),
              SizedBox(
                width: 52,
                child: Text(
                  '$_pointsToUse',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: context.goldText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ]),
          if (_usePoints)
            Text(
              'الإجمالي بعد الخصم: ${(subtotal - pointsDiscount + shippingFee).toStringAsFixed(2)} EGP (الشحن 120 جنيه ثابت).',
              style: TextStyle(color: context.subdued, fontSize: 11, height: 1.5),
            ),
        ],
      ]),
    );
  }

  Widget _orderSummary(List<CartItem> items, double subtotal, int pointsDiscount) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: context.surfaceCard, borderRadius: BorderRadius.circular(18), border: Border.all(color: context.hairlineSoft)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('٣. مراجعة الطلب', style: TextStyle(color: context.ink, fontSize: 19, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: Image.network(
                      item.product.image,
                      width: 48,
                      height: 56,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(width: 48, height: 56, color: const Color(0xFF30271D), child: const Icon(Icons.spa_outlined, color: gold, size: 20)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(item.product.name, style: TextStyle(color: context.ink, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 3),
                    Text('${item.sizeMl} مل • ${item.product.concentrationLabel(item.concentration)} • الكمية: ${item.quantity}', style: TextStyle(color: context.subdued, fontSize: 11)),
                  ])),
                  const SizedBox(width: 8),
                  Text('${item.total.toStringAsFixed(2)} ${item.product.currency}', style: TextStyle(color: context.goldText, fontSize: 12, fontWeight: FontWeight.w600)),
                ]),
              )),
          Divider(color: context.hairline),
          _summaryLine('مجموع المنتجات', '${subtotal.toStringAsFixed(2)} EGP'),
          const SizedBox(height: 8),
          if (pointsDiscount > 0)
            _summaryLine(
              'خصم نقاط الولاء',
              '-${pointsDiscount.toStringAsFixed(2)} EGP',
              valueColor: context.goldText,
            ),
          if (pointsDiscount > 0) const SizedBox(height: 8),
          _summaryLine('التوصيل (جميع المحافظات)', '120.00 EGP'),
          const SizedBox(height: 8),
          _summaryLine('الإجمالي شامل الشحن', '${(subtotal - pointsDiscount + shippingFee).toStringAsFixed(2)} EGP'),
          const SizedBox(height: 10),
          Text('الدفع مسبقاً عبر إنستاباي أو فودافون كاش بعد تأكيد المتجر لتعليمات التحويل.', style: TextStyle(color: context.subdued, fontSize: 11, height: 1.5)),
        ]),
      );

  Widget _summaryLine(String label, String value, {Color? valueColor}) => Row(children: [
        Expanded(child: Text(label, style: TextStyle(color: context.subdued, fontSize: 13))),
        Text(value, style: TextStyle(color: valueColor ?? context.ink, fontSize: 13, fontWeight: FontWeight.w600)),
      ]);
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: context.surfaceCard, borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          Icon(Icons.verified_user_outlined, color: context.goldText, size: 20),
          SizedBox(width: 9),
          Expanded(child: Text('خطوة أخيرة لإتمام طلبك', style: TextStyle(color: context.ink, fontWeight: FontWeight.w600))),
          Text('الدفع الآمن', style: TextStyle(color: context.subdued, fontSize: 11)),
        ]),
      );
}
