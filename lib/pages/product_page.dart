import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../providers/cart_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class ProductPage extends StatelessWidget {
  const ProductPage({
    super.key,
    required this.product,
    required this.favorite,
    required this.onFavorite,
  });

  final Product product;
  final bool favorite;
  final VoidCallback onFavorite;

  void _addToCart(BuildContext context) {
    if (!product.inStock) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('هذا المنتج غير متوفر حالياً.')));
      return;
    }
    context.read<CartProvider>().add(product);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت إضافة المنتج إلى السلة.')));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          actions: [
            IconButton(
              onPressed: onFavorite,
              icon: Icon(favorite ? Icons.favorite : Icons.favorite_border, color: gold),
            ),
          ],
        ),
        body: Directionality(
          textDirection: TextDirection.rtl,
          child: ListView(
            children: [
              Image.network(
                product.image,
                height: 330,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(height: 330, color: const Color(0xFF32261E)),
              ),
              Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(product.category.toUpperCase(), style: const TextStyle(color: gold, letterSpacing: 2)),
                    Text(product.name, style: const TextStyle(color: cream, fontSize: 32, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    Text(
                      product.description.isEmpty
                          ? 'هيبة الملوك ونفحات القصور الفاخرة، صُمم لليالي الشتوية والمناسبات الرسمية الكبرى.'
                          : product.description,
                      style: const TextStyle(color: muted, height: 1.8),
                    ),
                    const SizedBox(height: 24),
                    Text('${product.price.toStringAsFixed(2)} ${product.currency}', style: const TextStyle(color: gold, fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 24),
                    const Text('الهرم العطري', style: TextStyle(color: cream, fontSize: 20, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    NoteCard(title: 'المقدمة', notes: product.topNotes),
                    NoteCard(title: 'القلب', notes: product.heartNotes),
                    NoteCard(title: 'القاعدة', notes: product.baseNotes),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: product.inStock ? () => _addToCart(context) : null,
                        icon: const Icon(Icons.add_shopping_cart),
                        label: Text(product.inStock ? 'أضف إلى السلة' : 'غير متوفر'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}
