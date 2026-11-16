import 'package:flutter/material.dart';
import '../data/featured_product.dart';
import '../models/product.dart';
import '../services/product_api.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class CollectionPage extends StatefulWidget {
  const CollectionPage({super.key, required this.onProduct, required this.favorite, required this.onFavorite});
  final ValueChanged<Product> onProduct;
  final bool favorite;
  final VoidCallback onFavorite;
  @override
  State<CollectionPage> createState() => _CollectionPageState();
}

class _CollectionPageState extends State<CollectionPage> {
  late Future<List<Product>> productsFuture;
  final TextEditingController searchController = TextEditingController();
  bool availableOnly = false;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void _loadProducts() => productsFuture = ProductApi().fetchProducts();

  Future<void> _refresh() async {
    setState(_loadProducts);
    await productsFuture;
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              const Header(),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 15, 20, 16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('التشكيلة', style: TextStyle(color: cream, fontSize: 30, fontWeight: FontWeight.w600)),
                  SizedBox(height: 6),
                  Text('اختر أثرك من عطور زخم الرسمية', style: TextStyle(color: muted)),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'ابحث عن عطر...',
                    prefixIcon: const Icon(Icons.search, color: gold),
                    suffixIcon: searchController.text.isEmpty ? null : IconButton(onPressed: () { searchController.clear(); setState(() {}); }, icon: const Icon(Icons.close)),
                    filled: true,
                    fillColor: card,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                child: Wrap(spacing: 8, children: [
                  ChoiceChip(label: const Text('كل العطور'), selected: !availableOnly, onSelected: (_) => setState(() => availableOnly = false)),
                  ChoiceChip(label: const Text('المتوفر فقط'), selected: availableOnly, onSelected: (_) => setState(() => availableOnly = true)),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ProductTile(product: featuredProduct, onTap: () => widget.onProduct(featuredProduct), favorite: widget.favorite, onFavorite: widget.onFavorite),
              ),
              const Padding(padding: EdgeInsets.fromLTRB(20, 24, 20, 12), child: Text('كل العطور', textAlign: TextAlign.right, style: TextStyle(color: cream, fontSize: 20, fontWeight: FontWeight.w600))),
              FutureBuilder<List<Product>>(
                future: productsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) return const Padding(padding: EdgeInsets.all(28), child: Center(child: CircularProgressIndicator(color: gold)));
                  if (snapshot.hasError) return Padding(padding: const EdgeInsets.all(20), child: Column(children: [const Text('تعذر تحميل المنتجات حالياً.', textAlign: TextAlign.center, style: TextStyle(color: muted)), const SizedBox(height: 10), OutlinedButton(onPressed: _refresh, child: const Text('إعادة المحاولة'))]));
                  final query = searchController.text.trim().toLowerCase();
                  final products = (snapshot.data ?? const <Product>[]).where((product) {
                    final matchesSearch = query.isEmpty || product.name.toLowerCase().contains(query) || product.category.toLowerCase().contains(query);
                    return matchesSearch && (!availableOnly || product.inStock);
                  }).toList(growable: false);
                  if (products.isEmpty) return const Padding(padding: EdgeInsets.all(24), child: Text('لا توجد عطور تطابق البحث حالياً.', textAlign: TextAlign.center, style: TextStyle(color: muted)));
                  return Column(children: products.map((product) => ApiProductCard(product: product, onTap: () => widget.onProduct(product))).toList());
                },
              ),
              const SizedBox(height: 28),
            ],
          ),
        ),
      );
}
