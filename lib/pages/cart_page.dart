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
                Icon(Icons.shopping_bag_outlined, color: context.goldText, size: 27),
                const SizedBox(width: 12),
                Expanded(child: Text('سلة زخم', style: TextStyle(color: context.ink, fontSize: 25, fontWeight: FontWeight.w600))),
                Text('${cart.itemCount} قطع', style: TextStyle(color: context.subdued)),
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
                          decoration: BoxDecoration(color: context.surfaceCard, borderRadius: BorderRadius.circular(18), border: Border.all(color: context.hairlineSoft)),
                          child: Row(children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(13),
                              child: Image.network(item.product.image, width: 78, height: 92, fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(width: 78, height: 92, color: const Color(0xFF30271D), child: const Icon(Icons.spa_outlined, color: gold))),
                            ),
                            const SizedBox(width: 13),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(item.product.name, style: TextStyle(color: context.ink, fontSize: 16, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text('${item.sizeMl} مل • ${item.product.concentrationLabel(item.concentration)} • ${item.unitPrice.toStringAsFixed(0)} ${item.product.currency}', style: TextStyle(color: context.subdued, fontSize: 12)),
                              const SizedBox(height: 10),
                              Text('${item.total.toStringAsFixed(0)} ${item.product.currency}', style: TextStyle(color: context.goldText, fontWeight: FontWeight.w600)),
                            ])),
                            Column(children: [
                              IconButton(onPressed: () => cart.remove(item), icon: Icon(Icons.delete_outline, color: context.subdued, size: 20), tooltip: 'إزالة'),
                              Container(decoration: BoxDecoration(border: Border.all(color: context.hairline), borderRadius: BorderRadius.circular(12)), child: Row(mainAxisSize: MainAxisSize.min, children: [
                                IconButton(onPressed: () => cart.decrease(item), icon: Icon(Icons.remove, size: 16, color: context.ink), visualDensity: VisualDensity.compact),
                                Text('${item.quantity}', style: TextStyle(color: context.ink, fontWeight: FontWeight.w600)),
                                IconButton(onPressed: () => cart.add(item.product, concentration: item.concentration, sizeMl: item.sizeMl), icon: Icon(Icons.add, size: 16, color: context.goldText), visualDensity: VisualDensity.compact),
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
                decoration: BoxDecoration(color: context.surfaceCard, border: Border(top: BorderSide(color: context.hairlineSoft))),
                child: SafeArea(top: false, child: Column(children: [
                  Row(children: [Expanded(child: Text('الإجمالي الفرعي', style: TextStyle(color: context.subdued))), Text('${cart.subtotal.toStringAsFixed(0)} EGP', style: TextStyle(color: context.ink, fontSize: 17, fontWeight: FontWeight.w600))]),
                  const SizedBox(height: 5),
                  Align(alignment: Alignment.centerRight, child: Text('رسوم التوصيل 120 ج.م لجميع المحافظات، وتُضاف عند إتمام الطلب.', style: TextStyle(color: context.subdued, fontSize: 11))),
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
      Container(width: 92, height: 92, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: gold.withOpacity(.35))), child: Icon(Icons.shopping_bag_outlined, color: context.goldText, size: 38)),
      const SizedBox(height: 18),
      Text('سلتك بانتظار عطرك', style: TextStyle(color: context.ink, fontSize: 21, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Text('اكتشف التشكيلة واختر العطر الذي يشبه حضورك.', textAlign: TextAlign.center, style: TextStyle(color: context.subdued, height: 1.6)),
    ]),
  ));
}
