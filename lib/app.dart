import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config/app_version.dart';
import 'data/featured_product.dart';
import 'models/product.dart';
import 'pages/account_page.dart';
import 'pages/cart_page.dart';
import 'pages/collection_page.dart';
import 'pages/consultation_page.dart';
import 'pages/customer_chat_page.dart';
import 'pages/fragrance_cards_page.dart';
import 'pages/fragrance_identity_page.dart';
import 'pages/home_page.dart';
import 'pages/notifications_page.dart';
import 'pages/product_page.dart';
import 'pages/quiz_page.dart';
import 'pages/sections_page.dart';
import 'pages/verify_page.dart';
import 'providers/cart_provider.dart';
import 'providers/customer_provider.dart';
import 'providers/discount_provider.dart';
import 'providers/theme_provider.dart';
import 'services/deep_link_service.dart';
import 'services/daily_perfume.dart';
import 'services/app_update_api.dart';
import 'services/favorites_offer_service.dart';
import 'services/favorites_service.dart';
import 'services/product_catalog.dart';
import 'services/push_service.dart';
import 'services/reminder_service.dart';
import 'theme/app_theme.dart';
import 'widgets/app_update_dialog.dart';
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
  const StoreShell({super.key, this.appUpdateApi});

  /// عميل فحص التحديث — يُحقن في الاختبارات فقط؛ وفي الإنتاج يُبنى
  /// العميل الحقيقي تلقائياً. (الحقن يجعل اختبار فحص الإطلاق
  /// حتمياً بلا أي شبكة حقيقية.)
  final AppUpdateApi? appUpdateApi;

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

  /// زر المساعد العائم ظاهر أم مخفي أثناء التمرير: يُخفى عند
  /// التمرير للأسفل حتى لا يحجب أسطر البطاقات، ويعود عند التمرير
  /// للأعلى (سلوك معتاد للأزرار العائمة).
  bool _fabVisible = true;

  /// يخفي زر المساعد أثناء التمرير العمودي للأسفل ويعيده عند
  /// التمرير للأعلى؛ التمرير الأفقي (قوائم جانبية) لا يؤثر فيه.
  bool _onScroll(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification &&
        notification.metrics.axis == Axis.vertical &&
        notification.scrollDelta != null) {
      final delta = notification.scrollDelta!;
      if (delta > 0 && _fabVisible) {
        setState(() => _fabVisible = false);
      } else if (delta < 0 && !_fabVisible) {
        setState(() => _fabVisible = true);
      }
    }
    return false;
  }

  /// عطر اليوم من التشكيلة (من الشبكة أو الكاش) — يخفى إن لم تُحمَّل
  /// التشكيلة بعد.
  Product? _dailyProduct;

  /// آخر مرة عُرض فيها تنبيه «السلة الفارغة» داخل التطبيق.
  static const String _nudgeLastShownKey =
      'zakham_emptycart_nudge_last_shown';

  @override
  void initState() {
    super.initState();
    _cartProvider = context.read<CartProvider>();
    _cartProvider.addListener(_onCartChanged);
    _loadFavorites();
    // قواعد الخصم المفعّلة best-effort (غيابها = لا خصم، لا عطل).
    unawaited(context.read<DiscountProvider>().refresh());
    // الروابط العميقة best-effort: أي فشل في قناة المنصة يُتجاهل.
    unawaited(
      _deepLinkService.init(onProductSlug: _openProductSlug),
    );
    // التذكيرات المحلية best-effort: الضغط عليها يوجَّه هنا.
    _reminders.onNotificationTap = _handleReminderTap;
    unawaited(_reminders.init());
    unawaited(_reconcileReminders());
    // إشعارات المناسبات best-effort: قبل كل مناسبة قادمة بأسبوع.
    unawaited(_reminders.ensureOccasionReminders());
    // عطر اليوم best-effort: من التشكيلة (شبكة أو كاش) مع إشعاره.
    unawaited(_loadDailyPerfume());
    // فحص التحديث best-effort: عند كل فتح، وبعد أول إطار حتى يكون
    // السياق جاهزاً للحوار؛ أي فشل يمر بصمت بلا حوار وبلا عطل.
    // (البوابة اليومية أُزيلت في البناء 39: كانت تسجّل تاريخ
    // الفحص قبل الجلب، فمن فتح التطبيق قبل تحديث النقطة لم يظهر
    // له التنبيه حتى اليوم التالي — الآن استدعاء GET واحد عند
    // كل فتح يكفي.)
    WidgetsBinding.instance.addPostFrameCallback(
      (_) {
        unawaited(_checkAppUpdate());
        // فتح التطبيق من إشعار تحديث: يفتح صفحة الإشعارات مباشرة
        // (حيث بطاقة التحديث وزر «تحديث الآن») بدل الرئيسية فقط.
        unawaited(_handlePendingNotificationTap());
      },
    );
  }

  @override
  void dispose() {
    _cartProvider.removeListener(_onCartChanged);
    _reminders.onNotificationTap = null;
    _deepLinkService.dispose();
    super.dispose();
  }

  /// يستعيد المفضلة المحفوظة محلياً (مفتاح `zakham_favorites`)، ويسجّل
  /// معها التشكيلة المحفوظة محلياً في المنتجات المعروفة — فبدونها
  /// تبقى صفحة المفضلة فارغة بعد إعادة التشغيل: المعرّفات تُستعاد
  /// لكن كائنات العطور لا توجد في ذاكرة الجلسة بعد.
  Future<void> _loadFavorites() async {
    final saved = await _favoritesService.load();
    // الكتالوج المحفوظ محلياً فقط (بلا شبكة): يكفي لحلّ المعرّفات.
    final cached = await ProductCatalog().loadCached();
    if (!mounted) return;
    setState(() {
      if (cached != null) {
        for (final item in cached.products) {
          knownProducts.putIfAbsent(item.id, () => item);
        }
      }
      favoriteIds.addAll(saved);
    });
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

  /// يفحص وجود إصدار أحدث على المتجر عند كل فتح للتطبيق ويعرض
  /// حوار «تحديث جديد» — زر «تحديث الآن» فيه يفتح رابط الرسالة
  /// المثبّتة في قناة تليجرام (بناء 41)، و«لاحقاً» يغلقه فقط
  /// ويظهر مجدداً عند الفتح التالي طالما التحديث معلّق (الرفض
  /// لا يُحفظ أبداً).
  ///
  /// التطبيق ليس على Google Play والتحديث لن يتم تلقائياً أبداً،
  /// فهذا التنبيه هو ما يوجّه المستخدمين لتثبيت كل إصدار جديد.
  /// best-effort: أي فشل (شبكة أو رد غير صالح) يمر بصمت بلا
  /// حوار وبلا عطل — استدعاء GET واحد للنقطة عند الفتح يكفي.
  Future<void> _checkAppUpdate() async {
    try {
      final latest = await (widget.appUpdateApi ?? AppUpdateApi())
          .fetchLatest();
      if (latest == null) return;
      if (!isUpdateAvailable(
        latestVersionCode: latest.versionCode,
        installedVersionCode: AppVersion.versionCode,
      )) {
        return;
      }
      if (!mounted) return;
      await showAppUpdateDialog(
        context,
        versionName: latest.versionName,
        notes: latest.notes,
      );
    } catch (_) {}
  }

  /// يستهلك راية فتح صفحة الإشعارات (تُرفع عند نقر إشعار تحديث
  /// تطبيق) فيفتح الصفحة مرة واحدة عند الإقلاع. best-effort بلا
  /// عطل — غياب الراية يعني إقلاعاً عادياً على الرئيسية.
  Future<void> _handlePendingNotificationTap() async {
    try {
      final open =
          await PushService.instance.takePendingOpenNotifications();
      if (!open || !mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NotificationsPage(
            onDailyPerfumeEnabled: _scheduleDailyPerfume,
          ),
        ),
      );
    } catch (_) {}
  }

  /// يحمّل عطر اليوم من التشكيلة (من الشبكة أو الكاش عند غياب النت)
  /// ويجدول إشعاره اليومي — best-effort، لا يعطّل الإطلاق أبداً.
  Future<void> _loadDailyPerfume() async {
    try {
      final catalog = await ProductCatalog().fetchCatalog();
      final today = perfumeOfTheDay(catalog.products, DateTime.now());
      if (!mounted) return;
      setState(() {
        // تسجيل التشكيلة الكاملة (شبكة أو كاش) في المنتجات المعروفة
        // حتى تُحلّ معرّفات المفضلة المستعادة — يغطي أول إقلاع
        // بلا كاش محفوظ، ويحدّث بيانات العطور المعروفة.
        for (final item in catalog.products) {
          knownProducts.putIfAbsent(item.id, () => item);
        }
        if (today != null) _dailyProduct = today;
      });
      if (today == null) return;
      await _reminders.ensureDailyPerfumeScheduled(
        productId: today.id,
        productName: today.name,
        price: today.price,
        currency: today.currency,
      );
    } catch (_) {}
  }

  /// يعيد جدولة إشعار «عطر اليوم» عند تفعيل مبدّله من صفحة الحساب
  /// (الغلاف وحده يعرف عطر اليوم الحالي).
  Future<void> _scheduleDailyPerfume() async {
    final today = _dailyProduct;
    if (today == null) return;
    try {
      await _reminders.ensureDailyPerfumeScheduled(
        productId: today.id,
        productName: today.name,
        price: today.price,
        currency: today.currency,
      );
    } catch (_) {}
  }

  /// يوجّه الضغط على إشعار تذكير إلى وجهته: السلة، أو التشكيلة،
  /// أو صفحة العطر (إعادة الشراء / عرض المفضلة / عطر اليوم /
  /// مناسبة قادمة)، أو صفحة الحساب (هدية عيد الميلاد).
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
      case ReminderTapKind.birthday:
        Navigator.of(context).popUntil((route) => route.isFirst);
        setState(() => selected = 4);
        break;
      case ReminderTapKind.reorder:
      case ReminderTapKind.offer:
      case ReminderTapKind.daily:
      case ReminderTapKind.occasion:
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

  void openQuiz() => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => QuizPage(
            onViewProduct: () => openProduct(featuredProduct),
            onOpenIdentity: openFragranceIdentity,
          ),
        ),
      );

  /// يفتح أداة «بصمة زخم: دليلك للهوية العطرية» (4 خطوات + نتيجة).
  void openFragranceIdentity() => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FragranceIdentityPage(
            onProduct: openProduct,
            onConsultation: openConsultation,
            onOpenChat: _openCustomerChat,
          ),
        ),
      );

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

  /// يفتح صفحة «حجز استشارة عطرية».
  void openConsultation() {
    final provider = context.read<CustomerProvider>();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ConsultationPage(
          consultations: provider.consultations,
          ownerKey: provider.addressOwnerKey,
        ),
      ),
    );
  }

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
            onConsultation: openConsultation,
            onProduct: openProduct,
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

  /// يفتح محادثة العملاء المصغرة — من الأيقونة العائمة في شاشتي
  /// الرئيسية والتشكيلة؛ بلا مصادقة، ونطاقها كتالوج المتجر فقط.
  void _openCustomerChat() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CustomerChatPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cartCount = context.watch<CartProvider>().itemCount;
    final savedProducts = favoriteIds.map((id) => knownProducts[id]).whereType<Product>().toList(growable: false);
    // البطاقة العلوية هي عطر اليوم (دوران يومي) — ورويال احتياطي
    // قبل تحميل التشكيلة أو بلا نت؛ والمفضلة تتبع العطر المعروض.
    final heroProduct = _dailyProduct ?? featuredProduct;
    final pages = <Widget>[
      HomePage(
        product: heroProduct,
        onProduct: openProduct,
        onQuiz: openQuiz,
        onFragranceIdentity: openFragranceIdentity,
        favorite: isFavorite(heroProduct),
        onFavorite: () => toggleFavorite(heroProduct),
        onSection: openSection,
        onOpenSections: openSections,
        onFragranceCards: openFragranceCards,
        onVerify: openVerify,
        onConsultation: openConsultation,
        isDailyPerfume: _dailyProduct != null,
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
      AccountPage(
        onOpenSections: openSections,
        onDailyPerfumeEnabled: _scheduleDailyPerfume,
      ),
    ];
    return Scaffold(
      body: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: Directionality(textDirection: TextDirection.rtl, child: pages[selected]),
      ),
      // زر المساعد الذكي العائم — «مساعد دار زخم» بأيقونة ذكاء
      // اصطناعي، يظهر للزوار والعملاء على شاشتي الرئيسية والتشكيلة
      // فقط، ويفتح المحادثة المصغرة (كتالوج المتجر فقط). يُخفى
      // أثناء التمرير للأسفل (انظر _onScroll) حتى لا يحجب البطاقات.
      floatingActionButton: (selected == 0 || selected == 1)
          ? IgnorePointer(
              ignoring: !_fabVisible,
              child: AnimatedOpacity(
                opacity: _fabVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: FloatingActionButton.extended(
                  heroTag: 'advisorFab',
                  onPressed: _openCustomerChat,
                  tooltip: 'مساعد دار زخم',
                  backgroundColor: gold,
                  foregroundColor: Colors.black,
                  icon: const Icon(Icons.auto_awesome, size: 22),
                  label: const Text('مساعد دار زخم'),
                ),
              ),
            )
          : null,
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
