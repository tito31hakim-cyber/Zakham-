import 'package:flutter/material.dart';

import 'data/featured_product.dart';
import 'models/product.dart';
import 'pages/account_page.dart';
import 'pages/collection_page.dart';
import 'pages/home_page.dart';
import 'pages/product_page.dart';
import 'pages/quiz_page.dart';
import 'theme/app_theme.dart';
import 'widgets/common_widgets.dart';

class ZakhamApp extends StatelessWidget {
  const ZakhamApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'House of Zakham',
        theme: AppTheme.dark(),
        home: const StoreShell(),
      );
}

class StoreShell extends StatefulWidget {
  const StoreShell({super.key});

  @override
  State<StoreShell> createState() => _StoreShellState();
}

class _StoreShellState extends State<StoreShell> {
  int selected = 0;
  bool favorite = false;
  Product selectedProduct = featuredProduct;

  void openProduct(Product product) {
    setState(() => selectedProduct = product);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductPage(
          product: product,
          favorite: favorite,
          onFavorite: () => setState(() => favorite = !favorite),
        ),
      ),
    );
  }

  void openQuiz() => Navigator.push(context, MaterialPageRoute(builder: (_) => const QuizPage()));

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomePage(
        product: featuredProduct,
        onProduct: openProduct,
        onQuiz: openQuiz,
        favorite: favorite,
        onFavorite: () => setState(() => favorite = !favorite),
      ),
      CollectionPage(
        onProduct: openProduct,
        favorite: favorite,
        onFavorite: () => setState(() => favorite = !favorite),
      ),
      favorite
          ? ProductTile(
              product: selectedProduct,
              onTap: () => openProduct(selectedProduct),
              favorite: true,
              onFavorite: () => setState(() => favorite = false),
            )
          : const Center(child: Text('لم تحفظ أي عطر بعد', style: TextStyle(color: muted))),
      const AccountPage(),
    ];

    return Scaffold(
      body: Directionality(textDirection: TextDirection.rtl, child: pages[selected]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected,
        onDestinationSelected: (value) => setState(() => selected = value),
        backgroundColor: const Color(0xFF101010),
        indicatorColor: gold.withOpacity(.2),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home, color: gold), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.grid_view_rounded), selectedIcon: Icon(Icons.grid_view, color: gold), label: 'التشكيلة'),
          NavigationDestination(icon: Icon(Icons.favorite_border), selectedIcon: Icon(Icons.favorite, color: gold), label: 'المفضلة'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person, color: gold), label: 'حسابي'),
        ],
      ),
    );
  }
}
