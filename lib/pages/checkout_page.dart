import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart' show cream, gold;
import '../providers/cart_provider.dart';
import '../services/order_api.dart';

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
  String payment = 'cash_on_delivery';
  bool submitting = false;

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    address.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!formKey.currentState!.validate()) return;
    setState(() => submitting = true);
    try {
      final cart = context.read<CartProvider>();
      final result = await OrderApi().createOrder(
        customerName: name.text,
        phone: phone.text,
        address: address.text,
        paymentMethod: payment,
        items: cart.items,
      );

      if (!mounted) return;
      cart.clear();
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('تم إنشاء الطلب'),
          content: Text(
            'رقم الطلب: ${result.orderRef}\nالإجمالي: ${result.total.toStringAsFixed(2)} EGP\nطريقة الدفع: ${_paymentLabel(payment)}',
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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('تعذر إنشاء الطلب: $error')));
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  String _paymentLabel(String value) => switch (value) {
    'cash_on_delivery' => 'الدفع عند الاستلام',
    'instapay' => 'إنستاباي / تحويل بنكي',
    'wallet' => 'محفظة إلكترونية',
    _ => value,
  };

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
                'بيانات التوصيل',
                style: TextStyle(
                  color: cream,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 14),
              _field(name, 'الاسم الكامل', Icons.person_outline),
              _field(
                phone,
                'رقم الهاتف',
                Icons.phone_outlined,
                keyboard: TextInputType.phone,
              ),
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
                'cash_on_delivery',
                'الدفع عند الاستلام',
                Icons.local_shipping_outlined,
              ),
              _payment(
                'instapay',
                'إنستاباي / تحويل بنكي',
                Icons.account_balance_outlined,
              ),
              _payment(
                'wallet',
                'محفظة إلكترونية',
                Icons.account_balance_wallet_outlined,
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'الإجمالي',
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

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? keyboard,
    int maxLines = 1,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      keyboardType: keyboard,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      validator: (v) =>
          v == null || v.trim().length < 3 ? 'هذا الحقل مطلوب' : null,
    ),
  );
  Widget _payment(String value, String label, IconData icon) =>
      RadioListTile<String>(
        value: value,
        groupValue: payment,
        onChanged: (v) => setState(() => payment = v!),
        title: Text(label),
        secondary: Icon(icon, color: gold),
        activeColor: gold,
        contentPadding: EdgeInsets.zero,
      );
}
