import 'package:flutter/material.dart';

import '../models/product.dart';
import '../services/product_api.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class CollectionPage extends StatefulWidget {
  const CollectionPage({
    super.key,
    required this.onProduct,
  });

  final ValueChanged<Product> onProduct;

  @override
  State<CollectionPage> createState() => _CollectionPageState();
}

class _CollectionPageState extends State<CollectionPage> {
  late Future<List<Product>> productsFuture;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  void _loadProducts() {
    productsFuture = ProductApi().fetchProducts();
  }

  Future<void> _refresh() async {
    setState(_loadProducts);
    await productsFuture;
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const Header(),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 15, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('التشكيلة', style: TextStyle(color: cream, fontSize: 30, fontWeight: FontWeight.w600)),
                  Text('اختر أثرك من عطور زخم الرسمية', style: TextStyle(color: muted)),
                ],
              ),
            ),
            FutureBuilder<List<Product>>(
              future: productsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(padding: EdgeInsets.all(28), child: Center(child: CircularProgressIndicator(color: gold)));
                }
                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const Text('تعذر تحميل المنتجات حالياً.', textAlign: TextAlign.center, style: TextStyle(color: muted)),
                        const SizedBox(height: 10),
                        OutlinedButton(onPressed: _refresh, child: const Text('إعادة المحاولة')),
                      ],
                    ),
                  );
                }
                final products = snapshot.data ?? const <Product>[];
                if (products.isEmpty) {
                  return const Padding(padding: EdgeInsets.all(20), child: Text('لا توجد منتجات في استجابة API.', textAlign: TextAlign.center, style: TextStyle(color: muted)));
                }
                return Column(children: products.map((product) => ApiProductCard(product: product, onTap: () => widget.onProduct(product))).toList());
              },
            ),
          ],
        ),
      );
}
