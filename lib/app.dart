import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'data/featured_product.dart';
import 'models/product.dart';
import 'pages/account_page.dart';
import 'pages/cart_page.dart';
import 'pages/collection_page.dart';
import 'pages/home_page.dart';
import 'pages/product_page.dart';
import 'pages/quiz_page.dart';
import 'pages/sections_page.dart';
import 'providers/cart_provider.dart';
import 'providers/theme_provider.dart';
import 'theme/app_theme.dart';
import 'widgets/common_widgets.dart';

class ZakhamApp extends StatelessWidget {
  const ZakhamApp({super.key});
  @override
  Widget build(BuildContext context) {
    final themeMode = context.watch<ThemeProvider>().mode;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'دار زخم للعطور',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      home: const StoreShell(),
    );
  }
}

class StoreShell extends StatefulWidget {
  const StoreShell({super.key});
  @override
  State<StoreShell> createState() => _StoreShellState();
}

class _StoreShellState extends State<StoreShell> {
  int selected = 0;
  final Set<String> favoriteIds = <String>{};
  final Map<String, Product> knownProducts = <String, Product>{featuredProduct.id: featuredProduct};

  bool isFavorite(Product product) => favoriteIds.contains(product.id);

  void toggleFavorite(Product product) {
    setState(() {
      knownProducts[product.id] = product;
      if (!favoriteIds.add(product.id)) favoriteIds.remove(product.id);
    });
  }

  void openProduct(Product product) {
    knownProducts[product.id] = product;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductPage(
          product: product,
          favorite: isFavorite(product),
          onFavorite: () => toggleFavorite(product),
        ),
      ),
    ).then((_) => setState(() {}));
  }

  void openQuiz() => Navigator.push(context, MaterialPageRoute(builder: (_) => const QuizPage()));

  /// يفتح صفحة «الأقسام» (التشكيلة، طقس زخم، الإهداء، التغليف
  /// الفاخر، باقات التوفير) فوق التبويبات.
  void openSections() => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SectionsPage(
            onSection: openSection,
            onOpenCollection: openCollectionTab,
          ),
        ),
      );

  /// يفتح صفحة تفاصيل قسم واحد من الأقسام.
  void openSection(String id) => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SectionDetailPage(
            sectionId: id,
            onOpenCollection: openCollectionTab,
          ),
        ),
      );

  /// يعود إلى تبويب التشكيلة (يغلق أي صفحة مفتوحة فوق التبويبات أولاً).
  void openCollectionTab() {
    Navigator.of(context).popUntil((route) => route.isFirst);
    setState(() => selected = 1);
  }

  @override
  Widget build(BuildContext context) {
    final cartCount = context.watch<CartProvider>().itemCount;
    final savedProducts = favoriteIds.map((id) => knownProducts[id]).whereType<Product>().toList(growable: false);
    final pages = <Widget>[
      HomePage(
        product: featuredProduct,
        onProduct: openProduct,
        onQuiz: openQuiz,
        favorite: isFavorite(featuredProduct),
        onFavorite: () => toggleFavorite(featuredProduct),
        onSection: openSection,
        onOpenSections: openSections,
      ),
      CollectionPage(
        onProduct: openProduct,
        favorite: isFavorite(featuredProduct),
        onFavorite: () => toggleFavorite(featuredProduct),
      ),
      _FavoritesPage(products: savedProducts, onProduct: openProduct, onFavorite: toggleFavorite),
      const CartPage(),
      AccountPage(onOpenSections: openSections),
    ];
    return Scaffold(
      body: Directionality(textDirection: TextDirection.rtl, child: pages[selected]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected,
        onDestinationSelected: (value) => setState(() => selected = value),
        backgroundColor: context.isLightTheme ? lightCard : darkNavBar,
        indicatorColor: gold.withOpacity(.2),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home, color: context.goldText), label: 'الرئيسية'),
          NavigationDestination(icon: const Icon(Icons.grid_view_rounded), selectedIcon: Icon(Icons.grid_view, color: context.goldText), label: 'التشكيلة'),
          NavigationDestination(icon: const Icon(Icons.favorite_border), selectedIcon: Icon(Icons.favorite, color: context.goldText), label: 'المفضلة'),
          NavigationDestination(
            icon: _CartDestinationIcon(count: cartCount),
            selectedIcon: _CartDestinationIcon(count: cartCount, selected: true),
            label: 'السلة',
          ),
          NavigationDestination(icon: const Icon(Icons.person_outline), selectedIcon: Icon(Icons.person, color: context.goldText), label: 'حسابي'),
        ],
      ),
    );
  }
}

class _CartDestinationIcon extends StatelessWidget {
  const _CartDestinationIcon({required this.count, this.selected = false});
  final int count;
  final bool selected;
  @override
  Widget build(BuildContext context) => Stack(clipBehavior: Clip.none, children: [
        Icon(selected ? Icons.shopping_bag : Icons.shopping_bag_outlined, color: selected ? context.goldText : null),
        if (count > 0)
          Positioned(
            top: -7,
            right: -9,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(color: gold, borderRadius: BorderRadius.circular(10)),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text('$count', textAlign: TextAlign.center, style: const TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.bold)),
            ),
          ),
      ]);
}

class _FavoritesPage extends StatelessWidget {
  const _FavoritesPage({required this.products, required this.onProduct, required this.onFavorite});
  final List<Product> products;
  final ValueChanged<Product> onProduct;
  final ValueChanged<Product> onFavorite;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 34, 20, 28),
        children: [
          const Header(),
          const SizedBox(height: 18),
          Text('عطورك المحفوظة', textAlign: TextAlign.right, style: TextStyle(color: context.ink, fontSize: 28, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('اختياراتك التي تستحق العودة إليها.', textAlign: TextAlign.right, style: TextStyle(color: context.subdued)),
          const SizedBox(height: 22),
          if (products.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 55, horizontal: 16),
              child: Column(children: [
                Icon(Icons.favorite_border, color: context.goldText, size: 48),
                const SizedBox(height: 16),
                Text('لم تحفظ أي عطر بعد', style: TextStyle(color: context.ink, fontSize: 19, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text('اضغط على علامة القلب بجانب عطرك المفضل ليظهر هنا.', textAlign: TextAlign.center, style: TextStyle(color: context.subdued, height: 1.6)),
              ]),
            )
          else
            ...products.map((product) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: ProductTile(product: product, onTap: () => onProduct(product), favorite: true, onFavorite: () => onFavorite(product)),
                )),
        ],
      );
}
