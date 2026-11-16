import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/cart_provider.dart';
import '../theme/app_theme.dart';
import 'checkout_page.dart';

class CartPage extends StatelessWidget {
  const CartPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 12),
              child: Row(children: [
                const Icon(Icons.shopping_bag_outlined, color: gold, size: 27),
                const SizedBox(width: 12),
                const Expanded(child: Text('سلة زخم', style: TextStyle(color: cream, fontSize: 25, fontWeight: FontWeight.w600))),
                Text('${cart.itemCount} قطع', style: const TextStyle(color: muted)),
              ]),
            ),
            Expanded(
              child: cart.items.isEmpty
                  ? const _EmptyCart()
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
                      itemCount: cart.items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final item = cart.items[index];
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white10)),
                          child: Row(children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(13),
                              child: Image.network(item.product.image, width: 78, height: 92, fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(width: 78, height: 92, color: const Color(0xFF30271D), child: const Icon(Icons.spa_outlined, color: gold))),
                            ),
                            const SizedBox(width: 13),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(item.product.name, style: const TextStyle(color: cream, fontSize: 16, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text('${item.product.size} • ${item.product.price.toStringAsFixed(0)} ${item.product.currency}', style: const TextStyle(color: muted, fontSize: 12)),
                              const SizedBox(height: 10),
                              Text('${item.total.toStringAsFixed(0)} ${item.product.currency}', style: const TextStyle(color: gold, fontWeight: FontWeight.w600)),
                            ])),
                            Column(children: [
                              IconButton(onPressed: () => cart.remove(item.product), icon: const Icon(Icons.delete_outline, color: muted, size: 20), tooltip: 'إزالة'),
                              Container(decoration: BoxDecoration(border: Border.all(color: Colors.white12), borderRadius: BorderRadius.circular(12)), child: Row(mainAxisSize: MainAxisSize.min, children: [
                                IconButton(onPressed: () => cart.decrease(item.product), icon: const Icon(Icons.remove, size: 16, color: cream), visualDensity: VisualDensity.compact),
                                Text('${item.quantity}', style: const TextStyle(color: cream, fontWeight: FontWeight.w600)),
                                IconButton(onPressed: () => cart.add(item.product), icon: const Icon(Icons.add, size: 16, color: gold), visualDensity: VisualDensity.compact),
                              ])),
                            ]),
                          ]),
                        );
                      },
                    ),
            ),
            if (cart.items.isNotEmpty)
              Container(
                padding: const EdgeInsets.fromLTRB(22, 16, 22, 18),
                decoration: const BoxDecoration(color: card, border: Border(top: BorderSide(color: Colors.white10))),
                child: SafeArea(top: false, child: Column(children: [
                  Row(children: [const Expanded(child: Text('الإجمالي الفرعي', style: TextStyle(color: muted))), Text('${cart.subtotal.toStringAsFixed(0)} EGP', style: const TextStyle(color: cream, fontSize: 17, fontWeight: FontWeight.w600))]),
                  const SizedBox(height: 5),
                  const Align(alignment: Alignment.centerRight, child: Text('رسوم التوصيل غير محسوبة بعد؛ تأكد منها مع المتجر قبل الإرسال.', style: TextStyle(color: muted, fontSize: 11))),
                  const SizedBox(height: 14),
                  SizedBox(width: double.infinity, child: FilledButton.icon(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CheckoutPage())),
                    icon: const Icon(Icons.arrow_back), label: const Text('متابعة إلى إتمام الطلب'),
                  )),
                ])),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();
  @override
  Widget build(BuildContext context) => Center(child: Padding(
    padding: const EdgeInsets.all(32),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 92, height: 92, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: gold.withOpacity(.35))), child: const Icon(Icons.shopping_bag_outlined, color: gold, size: 38)),
      const SizedBox(height: 18),
      const Text('سلتك بانتظار عطرك', style: TextStyle(color: cream, fontSize: 21, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      const Text('اكتشف التشكيلة واختر العطر الذي يشبه حضورك.', textAlign: TextAlign.center, style: TextStyle(color: muted, height: 1.6)),
    ]),
  ));
}
