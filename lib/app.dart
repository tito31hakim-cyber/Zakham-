import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'data/featured_product.dart';
import 'models/product.dart';
import 'pages/account_page.dart';
import 'pages/cart_page.dart';
import 'pages/collection_page.dart';
import 'pages/fragrance_cards_page.dart';
import 'pages/home_page.dart';
import 'pages/product_page.dart';
import 'pages/quiz_page.dart';
import 'pages/sections_page.dart';
import 'pages/verify_page.dart';
import 'providers/cart_provider.dart';
import 'providers/theme_provider.dart';
import 'services/deep_link_service.dart';
import 'services/favorites_offer_service.dart';
import 'services/favorites_service.dart';
import 'services/product_catalog.dart';
import 'services/reminder_service.dart';
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
  final FavoritesService _favoritesService = FavoritesService();
  final DeepLinkService _deepLinkService = DeepLinkService();
  final ReminderService _reminders = ReminderService.instance;
  final FavoritesOfferService _favOffers = FavoritesOfferService();
  late final CartProvider _cartProvider;

  /// يظهر تنبيه «السلة الفارغة» داخل الرئيسية (مرة كل 3 أيام كحد أقصى).
  bool _showEmptyCartNudge = false;

  /// آخر مرة عُرض فيها تنبيه «السلة الفارغة» داخل التطبيق.
  static const String _nudgeLastShownKey =
      'zakham_emptycart_nudge_last_shown';

  @override
  void initState() {
    super.initState();
    _cartProvider = context.read<CartProvider>();
    _cartProvider.addListener(_onCartChanged);
    _loadFavorites();
    // الروابط العميقة best-effort: أي فشل في قناة المنصة يُتجاهل.
    unawaited(
      _deepLinkService.init(onProductSlug: _openProductSlug),
    );
    // التذكيرات المحلية best-effort: الضغط عليها يوجَّه هنا.
    _reminders.onNotificationTap = _handleReminderTap;
    unawaited(_reminders.init());
    unawaited(_reconcileReminders());
  }

  @override
  void dispose() {
    _cartProvider.removeListener(_onCartChanged);
    _reminders.onNotificationTap = null;
    _deepLinkService.dispose();
    super.dispose();
  }

  /// يستعيد المفضلة المحفوظة محلياً (مفتاح `zakham_favorites`).
  Future<void> _loadFavorites() async {
    final saved = await _favoritesService.load();
    if (!mounted) return;
    if (saved.isNotEmpty) setState(() => favoriteIds.addAll(saved));
    // تسجيل الجهاز مع المفضلة best-effort (يتخطى إن لم يتوفر الرمز بعد).
    unawaited(_favOffers.syncFavorites());
  }

  /// مزامنة التذكيرات عند التشغيل: يعيد جدولة ما فقده النظام،
  /// وينبّه داخل التطبيق إن بقيت السلة فارغة.
  Future<void> _reconcileReminders() async {
    await _reminders.reconcileOnStart(
      cartEmpty: _cartProvider.items.isEmpty,
      cartProductIds:
          _cartProvider.items.map((item) => item.product.id).toSet(),
    );
    await _refreshEmptyCartNudge();
  }

  /// أي تغيير في السلة يعيد ضبط التذكيرات (تذكير بعد 4 ساعات، أو
  /// تسليح تذكير «الفارغة») وينبّه داخل التطبيق عند الحاجة.
  void _onCartChanged() {
    if (!mounted) return;
    unawaited(_reminders.onCartChanged(
      cartEmpty: _cartProvider.items.isEmpty,
      cartProductIds:
          _cartProvider.items.map((item) => item.product.id).toSet(),
    ));
    unawaited(_refreshEmptyCartNudge());
  }

  /// يحدّث تنبيه «السلة الفارغة» داخل الرئيسية: يظهر فقط إن بقيت
  /// السلة فارغة ولم يُعرض خلال الأيام الثلاثة الماضية.
  Future<void> _refreshEmptyCartNudge() async {
    try {
      if (_cartProvider.items.isNotEmpty) {
        if (_showEmptyCartNudge && mounted) {
          setState(() => _showEmptyCartNudge = false);
        }
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      final lastShownMs = prefs.getInt(_nudgeLastShownKey);
      final lastShown = lastShownMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(lastShownMs);
      final now = DateTime.now();
      if (lastShown != null &&
          now.difference(lastShown) < const Duration(days: 3)) {
        if (_showEmptyCartNudge && mounted) {
          setState(() => _showEmptyCartNudge = false);
        }
        return;
      }
      await prefs.setInt(_nudgeLastShownKey, now.millisecondsSinceEpoch);
      if (mounted && !_showEmptyCartNudge) {
        setState(() => _showEmptyCartNudge = true);
      }
    } catch (_) {}
  }

  /// يوجّه الضغط على إشعار تذكير إلى وجهته: السلة، أو التشكيلة،
  /// أو صفحة العطر (إعادة الشراء / عرض المفضلة).
  void _handleReminderTap(String payload) {
    final tap = ReminderTap.parse(payload);
    if (!mounted) return;
    switch (tap.kind) {
      case ReminderTapKind.cart:
        Navigator.of(context).popUntil((route) => route.isFirst);
        setState(() => selected = 3);
        break;
      case ReminderTapKind.collection:
        openCollectionTab();
        break;
      case ReminderTapKind.reorder:
      case ReminderTapKind.offer:
        if (tap.productId != null) {
          unawaited(_openProductSlug(tap.productId!));
        }
        break;
      case ReminderTapKind.unknown:
        break;
    }
  }

  /// يفتح عطراً من رابط عميق `zakhamhouse.shop/product/<slug>`: يجرّب
  /// المنتجات المعروفة أولاً، ثم يجلب التشكيلة (من الشبكة أو الكاش)
  /// ليطابق الـ slug؛ وإن لم يُوجد يخبر المستخدم بدلاً من الصمت.
  Future<void> _openProductSlug(String slug) async {
    var product = knownProducts[slug];
    if (product == null) {
      try {
        final catalog = await ProductCatalog().fetchCatalog();
        for (final item in catalog.products) {
          if (item.id == slug) {
            product = item;
            break;
          }
        }
      } catch (_) {
        product = null;
      }
    }
    if (!mounted) return;
    if (product == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرابط لا يشير إلى عطر متاح حالياً.')),
      );
      return;
    }
    openProduct(product);
  }

  bool isFavorite(Product product) => favoriteIds.contains(product.id);

  void toggleFavorite(Product product) {
    setState(() {
      knownProducts[product.id] = product;
      if (!favoriteIds.add(product.id)) favoriteIds.remove(product.id);
    });
    // الحفظ محلي فقط، وbest-effort — لا يعطّل التبديل أبداً.
    unawaited(_favoritesService.save(favoriteIds));
    // تسجيل الجهاز مع المفضلة المحدّثة best-effort.
    unawaited(_favOffers.syncFavorites());
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

  /// يفتح صفحة «البطاقات العطرية» (البطاقات + المستكشف + الرادار).
  void openFragranceCards() => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FragranceCardsPage(
            onProduct: openProduct,
            isFavorite: isFavorite,
            onFavorite: toggleFavorite,
          ),
        ),
      );

  /// يفتح صفحة «تحقق من الأصالة» (إدخال الرقم أو مسح QR).
  void openVerify() => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const VerifyPage()),
      );

  /// يفتح صفحة «الأقسام» (التشكيلة، طقس زخم، الإهداء، التغليف
  /// الفاخر، باقات التوفير) فوق التبويبات.
  void openSections() => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SectionsPage(
            onSection: openSection,
            onOpenCollection: openCollectionTab,
            onFragranceCards: openFragranceCards,
            onVerify: openVerify,
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
        onFragranceCards: openFragranceCards,
        onVerify: openVerify,
        showEmptyCartNudge: _showEmptyCartNudge,
        onBrowseCollection: openCollectionTab,
        onDismissEmptyCartNudge: () {
          if (mounted) setState(() => _showEmptyCartNudge = false);
        },
      ),
      CollectionPage(
        onProduct: openProduct,
        isFavorite: isFavorite,
        onFavorite: toggleFavorite,
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
