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
  late String _concentration;
  late int _sizeMl;

  @override
  void initState() {
    super.initState();
    favorite = widget.favorite;
    _concentration = widget.product.defaultConcentration;
    _sizeMl = widget.product.defaultSizeMl;
  }

  List<int> get _sizes => widget.product.availableSizes(_concentration);

  double get _unitPrice =>
      widget.product.priceFor(concentration: _concentration, sizeMl: _sizeMl) ??
      widget.product.price;

  void _selectConcentration(String concentration) {
    setState(() {
      _concentration = concentration;
      // النووي مثلاً بلا 30 مل؛ إن لم يتوفر الحجم الحالي نختار أول حجم متاح.
      if (!_sizes.contains(_sizeMl)) {
        _sizeMl = _sizes.isNotEmpty ? _sizes.first : widget.product.defaultSizeMl;
      }
    });
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
    context.read<CartProvider>().add(
      product,
      concentration: _concentration,
      sizeMl: _sizeMl,
    );
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('تمت إضافة ${product.name} — ${product.concentrationLabel(_concentration)} · $_sizeMl مل إلى السلة.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final concentrations = product.availableConcentrations;
    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل العطر'),
        actions: [IconButton(onPressed: _toggleFavorite, tooltip: favorite ? 'إزالة من المفضلة' : 'أضف للمفضلة', icon: Icon(favorite ? Icons.favorite : Icons.favorite_border, color: favorite ? Colors.redAccent : context.goldText))],
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: ListView(children: [
          Stack(alignment: Alignment.bottomRight, children: [
            Image.network(product.image, height: 370, width: double.infinity, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(height: 370, color: const Color(0xFF32261E), child: const Center(child: Icon(Icons.spa_outlined, color: gold, size: 70)))),
            Container(height: 120, decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black87]))),
            Padding(padding: const EdgeInsets.all(22), child: Text(product.categoryLabel.toUpperCase(), style: const TextStyle(color: gold, letterSpacing: 2))),
          ]),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(product.name, textAlign: TextAlign.right, style: TextStyle(color: context.ink, fontSize: 32, fontWeight: FontWeight.w600)),
              if (product.nameEn.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(product.nameEn, textAlign: TextAlign.right, style: TextStyle(color: context.subdued, fontSize: 13, letterSpacing: 1.5)),
                ),
              const SizedBox(height: 10),
              Text(product.description.isEmpty ? 'هيبة الملوك ونفحات القصور الفاخرة، صُمم ليترك أثراً يليق بحضورك.' : product.description, textAlign: TextAlign.right, style: TextStyle(color: context.subdued, height: 1.8)),
              const SizedBox(height: 16),
              if (product.occasion.isNotEmpty || product.lasting.isNotEmpty)
                Wrap(spacing: 8, runSpacing: 8, children: [
                  if (product.occasion.isNotEmpty)
                    _InfoChip(icon: Icons.event_outlined, label: product.occasion),
                  if (product.lasting.isNotEmpty)
                    _InfoChip(icon: Icons.schedule_outlined, label: 'ثبات: ${product.lasting}'),
                ]),
              const SizedBox(height: 20),
              Text('التركيز', textAlign: TextAlign.right, style: TextStyle(color: context.ink, fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: concentrations.map((key) {
                final selected = key == _concentration;
                return ChoiceChip(
                  label: Text(product.concentrationLabel(key)),
                  selected: selected,
                  onSelected: (_) => _selectConcentration(key),
                  selectedColor: gold.withOpacity(.25),
                  labelStyle: TextStyle(color: selected ? context.goldText : context.ink, fontWeight: selected ? FontWeight.w700 : FontWeight.normal),
                );
              }).toList(growable: false)),
              const SizedBox(height: 16),
              Text('الحجم', textAlign: TextAlign.right, style: TextStyle(color: context.ink, fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: _sizes.map((size) {
                final selected = size == _sizeMl;
                final price = product.priceFor(concentration: _concentration, sizeMl: size) ?? 0;
                return ChoiceChip(
                  label: Text('$size مل • ${price.toStringAsFixed(0)} ${product.currency}'),
                  selected: selected,
                  onSelected: (_) => setState(() => _sizeMl = size),
                  selectedColor: gold.withOpacity(.25),
                  labelStyle: TextStyle(color: selected ? context.goldText : context.ink, fontWeight: selected ? FontWeight.w700 : FontWeight.normal),
                );
              }).toList(growable: false)),
              const SizedBox(height: 20),
              Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: context.surfaceCard, borderRadius: BorderRadius.circular(16)), child: Row(children: [
                Text('${_unitPrice.toStringAsFixed(0)} ${product.currency}', style: TextStyle(color: context.goldText, fontSize: 21, fontWeight: FontWeight.bold)),
                const Spacer(),
                Text('$_sizeMl مل · ${product.concentrationLabel(_concentration)}', style: TextStyle(color: context.ink)),
                const SizedBox(width: 7),
                Icon(Icons.water_drop_outlined, color: context.goldText),
              ])),
              const SizedBox(height: 24),
              Text('الهرم العطري', textAlign: TextAlign.right, style: TextStyle(color: context.ink, fontSize: 20, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              NoteCard(title: 'المقدمة', notes: product.topNotes),
              NoteCard(title: 'القلب', notes: product.heartNotes),
              NoteCard(title: 'القاعدة', notes: product.baseNotes),
              const SizedBox(height: 14),
              Row(children: [Icon(Icons.verified_outlined, color: context.goldText, size: 19), const SizedBox(width: 8), Text(product.inStock ? 'متوفر وجاهز للطلب' : 'غير متوفر حالياً', style: TextStyle(color: product.inStock ? context.ink : context.subdued))]),
              const SizedBox(height: 20),
              SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: product.inStock ? _addToCart : null, icon: const Icon(Icons.add_shopping_cart), label: Text(product.inStock ? 'أضف إلى السلة' : 'غير متوفر'))),
              const SizedBox(height: 8),
              Text('رسوم التوصيل 120 ج.م لجميع المحافظات، والدفع مسبقاً عبر إنستاباي أو فودافون كاش.', textAlign: TextAlign.center, style: TextStyle(color: context.subdued, fontSize: 11)),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: context.surfaceCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.hairline),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: context.goldText, size: 15),
          const SizedBox(width: 6),
          Flexible(child: Text(label, style: TextStyle(color: context.ink, fontSize: 12))),
        ]),
      );
}
