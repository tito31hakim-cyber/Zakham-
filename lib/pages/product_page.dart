import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../providers/cart_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class ProductPage extends StatefulWidget {
  const ProductPage({super.key, required this.product, required this.favorite, required this.onFavorite});
  final Product product;
  final bool favorite;
  final VoidCallback onFavorite;
  @override
  State<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  late bool favorite;
  @override
  void initState() {
    super.initState();
    favorite = widget.favorite;
  }

  void _toggleFavorite() {
    widget.onFavorite();
    setState(() => favorite = !favorite);
  }

  void _addToCart() {
    final product = widget.product;
    if (!product.inStock) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('هذا المنتج غير متوفر حالياً.')));
      return;
    }
    context.read<CartProvider>().add(product);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تمت إضافة ${product.name} إلى السلة.')));
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل العطر'),
        actions: [IconButton(onPressed: _toggleFavorite, tooltip: favorite ? 'إزالة من المفضلة' : 'أضف للمفضلة', icon: Icon(favorite ? Icons.favorite : Icons.favorite_border, color: favorite ? Colors.redAccent : gold))],
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: ListView(children: [
          Stack(alignment: Alignment.bottomRight, children: [
            Image.network(product.image, height: 370, width: double.infinity, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(height: 370, color: const Color(0xFF32261E), child: const Center(child: Icon(Icons.spa_outlined, color: gold, size: 70)))),
            Container(height: 120, decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black87]))),
            Padding(padding: const EdgeInsets.all(22), child: Text(product.category.toUpperCase(), style: const TextStyle(color: gold, letterSpacing: 2))),
          ]),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(product.name, textAlign: TextAlign.right, style: const TextStyle(color: cream, fontSize: 32, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Text(product.description.isEmpty ? 'هيبة الملوك ونفحات القصور الفاخرة، صُمم ليترك أثراً يليق بحضورك.' : product.description, textAlign: TextAlign.right, style: const TextStyle(color: muted, height: 1.8)),
              const SizedBox(height: 20),
              Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(16)), child: Row(children: [
                Text('${product.price.toStringAsFixed(0)} ${product.currency}', style: const TextStyle(color: gold, fontSize: 21, fontWeight: FontWeight.bold)),
                const Spacer(),
                Text(product.size, style: const TextStyle(color: cream)),
                const SizedBox(width: 7),
                const Icon(Icons.water_drop_outlined, color: gold),
              ])),
              const SizedBox(height: 24),
              const Text('الهرم العطري', textAlign: TextAlign.right, style: TextStyle(color: cream, fontSize: 20, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              NoteCard(title: 'المقدمة', notes: product.topNotes),
              NoteCard(title: 'القلب', notes: product.heartNotes),
              NoteCard(title: 'القاعدة', notes: product.baseNotes),
              const SizedBox(height: 14),
              Row(children: [const Icon(Icons.verified_outlined, color: gold, size: 19), const SizedBox(width: 8), Text(product.inStock ? 'متوفر وجاهز للطلب' : 'غير متوفر حالياً', style: TextStyle(color: product.inStock ? cream : muted))]),
              const SizedBox(height: 20),
              SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: product.inStock ? _addToCart : null, icon: const Icon(Icons.add_shopping_cart), label: Text(product.inStock ? 'أضف إلى السلة' : 'غير متوفر'))),
              const SizedBox(height: 8),
              const Text('يُرجى مراجعة تفاصيل الطلب قبل التأكيد. رسوم التوصيل تُحتسب عند إتمام الطلب.', textAlign: TextAlign.center, style: TextStyle(color: muted, fontSize: 11)),
            ]),
          ),
        ]),
      ),
    );
  }
}
