import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/cart_provider.dart';
import '../services/order_api.dart';
import '../theme/app_theme.dart';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  static const governorates = <String>[
    'القاهرة',
    'الجيزة',
    'الإسكندرية',
    'الدقهلية',
    'الشرقية',
    'القليوبية',
    'البحيرة',
    'المنوفية',
    'الغربية',
    'كفر الشيخ',
    'دمياط',
    'بورسعيد',
    'الإسماعيلية',
    'السويس',
    'شمال سيناء',
    'جنوب سيناء',
    'الفيوم',
    'بني سويف',
    'المنيا',
    'أسيوط',
    'سوهاج',
    'قنا',
    'الأقصر',
    'أسوان',
    'البحر الأحمر',
    'الوادي الجديد',
    'مطروح',
  ];

  final formKey = GlobalKey<FormState>();
  final name = TextEditingController();
  final phone = TextEditingController();
  final city = TextEditingController();
  final address = TextEditingController();
  final receiptReference = TextEditingController();
  final notes = TextEditingController();
  String? governorate;
  String payment = 'InstaPay | إنستاباي';
  bool submitting = false;

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    city.dispose();
    address.dispose();
    receiptReference.dispose();
    notes.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!formKey.currentState!.validate()) return;
    final cart = context.read<CartProvider>();
    if (cart.items.isEmpty) return;
    setState(() => submitting = true);
    try {
      final result = await OrderApi().createOrder(
        customerName: name.text,
        phone: phone.text,
        governorate: governorate!,
        city: city.text,
        address: address.text,
        paymentMethod: payment,
        receiptReference: receiptReference.text,
        notes: notes.text,
        items: cart.items,
      );

      if (!mounted) return;
      cart.clear();
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('تم استلام الطلب'),
          content: Text(
            'رقم الطلب: ${result.orderRef}\n'
            'الإجمالي: ${result.total == null ? 'يؤكده الخادم' : '${result.total!.toStringAsFixed(2)} EGP'}\n'
            'طريقة الدفع: $payment'
            '${result.trackingToken.isEmpty ? '' : '\nرمز التتبع: ${result.trackingToken}'}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('حسنًا'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر إنشاء الطلب: $error')),
      );
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('إتمام الطلب')),
        body: Form(
          key: formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'ملخص اختيارك',
                style: TextStyle(
                  color: cream,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              if (cart.items.isEmpty)
                const Text('السلة فارغة.', style: TextStyle(color: muted))
              else
                ...cart.items.map(
                  (item) => Card(
                    color: card,
                    child: ListTile(
                      title: Text(
                        item.product.name,
                        style: const TextStyle(color: cream),
                      ),
                      subtitle: Text(
                        '${item.sizeMl} مل · ${item.product.concentrationLabel(item.concentration)} · الكمية ${item.quantity}',
                        style: const TextStyle(color: muted),
                      ),
                      trailing: Text(
                        '${item.total.toStringAsFixed(2)} EGP',
                        style: const TextStyle(color: gold),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 14),
              const Text(
                'بيانات التوصيل',
                style: TextStyle(
                  color: cream,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              _field(name, 'الاسم الكامل', Icons.person_outline),
              _field(
                phone,
                'رقم الهاتف',
                Icons.phone_outlined,
                keyboard: TextInputType.phone,
                validator: _validatePhone,
              ),
              DropdownButtonFormField<String>(
                value: governorate,
                dropdownColor: card,
                decoration: const InputDecoration(
                  labelText: 'المحافظة',
                  prefixIcon: Icon(Icons.map_outlined),
                ),
                items: governorates
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(value),
                      ),
                    )
                    .toList(),
                validator: (value) =>
                    value == null ? 'اختر المحافظة' : null,
                onChanged: (value) => setState(() => governorate = value),
              ),
              const SizedBox(height: 12),
              _field(city, 'المدينة / المنطقة', Icons.location_city_outlined),
              _field(
                address,
                'العنوان بالتفصيل',
                Icons.location_on_outlined,
                maxLines: 3,
              ),
              const SizedBox(height: 18),
              const Text(
                'طريقة الدفع',
                style: TextStyle(
                  color: cream,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              _payment(
                'InstaPay | إنستاباي',
                'إنستاباي',
                Icons.account_balance_outlined,
              ),
              _payment(
                'Vodafone Cash | فودافون كاش',
                'فودافون كاش',
                Icons.account_balance_wallet_outlined,
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  payment.startsWith('InstaPay')
                      ? 'يرسل فريق زخم بيانات التحويل عبر واتساب بعد استلام الطلب.'
                      : 'يرسل فريق زخم بيانات فودافون كاش عبر واتساب بعد استلام الطلب.',
                  style: const TextStyle(color: muted, height: 1.5),
                ),
              ),
              _field(
                receiptReference,
                'مرجع التحويل (اختياري)',
                Icons.receipt_long_outlined,
                requiredField: false,
              ),
              _field(
                notes,
                'ملاحظات الطلب (اختياري)',
                Icons.notes_outlined,
                requiredField: false,
                maxLines: 2,
              ),
              const Divider(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'قيمة المنتجات',
                    style: TextStyle(color: cream, fontSize: 18),
                  ),
                  Text(
                    '${cart.subtotal.toStringAsFixed(2)} EGP',
                    style: const TextStyle(
                      color: gold,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'تُحسب رسوم الشحن والإجمالي النهائي عند تأكيد الطلب من الخادم.',
                style: TextStyle(color: muted, fontSize: 13),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: submitting || cart.items.isEmpty ? null : submit,
                icon: submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.lock_outline),
                label: const Text('تأكيد الطلب'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _validatePhone(String? value) {
    final raw = value?.trim() ?? '';
    if (!RegExp(r'^\+?[0-9]{9,15}$').hasMatch(raw)) {
      return 'أدخل رقم هاتف صحيحًا (من 9 إلى 15 رقمًا).';
    }
    return null;
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? keyboard,
    int maxLines = 1,
    String? Function(String?)? validator,
    bool requiredField = true,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      keyboardType: keyboard,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      validator: validator ??
          (value) {
            if (!requiredField && (value == null || value.trim().isEmpty)) {
              return null;
            }
            return value == null || value.trim().length < 3
                ? 'هذا الحقل مطلوب'
                : null;
          },
    ),
  );

  Widget _payment(String value, String label, IconData icon) =>
      RadioListTile<String>(
        value: value,
        groupValue: payment,
        onChanged: submitting ? null : (next) => setState(() => payment = next!),
        title: Text(label),
        secondary: Icon(icon, color: gold),
        activeColor: gold,
        contentPadding: EdgeInsets.zero,
      );
}
