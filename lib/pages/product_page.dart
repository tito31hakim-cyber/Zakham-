import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../providers/cart_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class ProductPage extends StatefulWidget {
  const ProductPage({
    super.key,
    required this.product,
    required this.favorite,
    required this.onFavorite,
  });

  final Product product;
  final bool favorite;
  final VoidCallback onFavorite;

  @override
  State<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  late String concentration;
  late int sizeMl;

  Product get product => widget.product;
  List<String> get concentrations {
    final values = product.concentrationOptions;
    if (values.isNotEmpty) return values;
    return [product.defaultConcentration];
  }

  List<int> get sizes => product.sizesFor(concentration);

  @override
  void initState() {
    super.initState();
    final options = product.concentrationOptions;
    concentration = options.contains(product.defaultConcentration)
        ? product.defaultConcentration
        : options.isNotEmpty
        ? options.first
        : product.defaultConcentration;
    final availableSizes = product.sizesFor(concentration);
    sizeMl = availableSizes.contains(100)
        ? 100
        : availableSizes.isNotEmpty
        ? availableSizes.first
        : 100;
  }

  void _addToCart() {
    if (!product.inStock) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('هذا المنتج غير متوفر حالياً.')),
      );
      return;
    }
    context.read<CartProvider>().add(
      product,
      sizeMl: sizeMl,
      concentration: concentration,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تمت إضافة المنتج إلى السلة.')),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      actions: [
        IconButton(
          onPressed: widget.onFavorite,
          icon: Icon(
            widget.favorite ? Icons.favorite : Icons.favorite_border,
            color: gold,
          ),
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
            errorBuilder: (_, __, ___) =>
                Container(height: 330, color: const Color(0xFF32261E)),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  product.category.toUpperCase(),
                  style: const TextStyle(color: gold, letterSpacing: 2),
                ),
                Text(
                  product.name,
                  style: const TextStyle(
                    color: cream,
                    fontSize: 32,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  product.description.isEmpty
                      ? 'هيبة الملوك ونفحات القصور الفاخرة، صُمم لليالي الشتوية والمناسبات الرسمية الكبرى.'
                      : product.description,
                  style: const TextStyle(color: muted, height: 1.8),
                ),
                const SizedBox(height: 20),
                if (product.concentrationOptions.isNotEmpty) ...[
                  const Text('التركيز', style: TextStyle(color: cream)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: concentration,
                    dropdownColor: card,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.opacity_outlined),
                    ),
                    items: concentrations
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(product.concentrationLabel(value)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        concentration = value;
                        final availableSizes = sizes;
                        if (!availableSizes.contains(sizeMl)) {
                          sizeMl = availableSizes.isNotEmpty
                              ? availableSizes.first
                              : 100;
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 14),
                ],
                const Text('الحجم', style: TextStyle(color: cream)),
                const SizedBox(height: 6),
                DropdownButtonFormField<int>(
                  value: sizes.contains(sizeMl) ? sizeMl : sizes.first,
                  dropdownColor: card,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.local_drink_outlined),
                  ),
                  items: sizes
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text('$value مل'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => sizeMl = value);
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  '${product.priceFor(concentration, sizeMl).toStringAsFixed(2)} ${product.currency}',
                  style: const TextStyle(
                    color: gold,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'الهرم العطري',
                  style: TextStyle(
                    color: cream,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                NoteCard(title: 'المقدمة', notes: product.topNotes),
                NoteCard(title: 'القلب', notes: product.heartNotes),
                NoteCard(title: 'القاعدة', notes: product.baseNotes),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: product.inStock ? _addToCart : null,
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
