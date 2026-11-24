import 'dart:async';

import 'package:flutter/material.dart';
import '../data/featured_product.dart';
import '../models/product.dart';
import '../services/favorites_offer_service.dart';
import '../services/favorites_service.dart';
import '../services/product_catalog.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

/// خيارات التصفية الذكية: (التسمية، كلمة المطابقة).
/// النوتات الخمس هي نوتات المتجر المعتمدة في صفحة `/notes/`.
const List<(String, String)> _noteOptions = <(String, String)>[
  ('عود', 'عود'),
  ('مسك', 'مسك'),
  ('عنبر', 'عنبر'),
  ('ورد', 'ورد'),
  ('زعفران', 'زعفران'),
];

/// الموسم: التسمية + ما يُبحث عنه في نص الموسم
/// («شتو» يطابق «الليالي الشتوية»، و«كل الفصول» عبارة كاملة).
const List<(String, String)> _seasonOptions = <(String, String)>[
  ('كل الفصول', 'كل الفصول'),
  ('شتوي', 'شتو'),
  ('صيفي', 'صيف'),
  ('خريفي', 'خريف'),
  ('ربيعي', 'ربيع'),
];

/// المناسبة: كلمات تُطابَق كجزء من نص المناسبة.
const List<String> _occasionOptions = <String>[
  'يومي',
  'مسائي',
  'رسمي',
  'سهرات',
  'قيادي',
];

/// النوع: (التسمية، قيمة `gender` من وسوم الخادم).
/// «غير محدد» يطابق العطور بلا وسم نوع (6 من 11 حالياً في الكتالوج
/// الحي) حتى يغطي العدّاد التشكيلة كلها؛ تصنيفها الصحيح يحتاج
/// وسم gender على الخادم، لا اختراعاً هنا.
const List<(String, String)> _genderOptions = <(String, String)>[
  ('رجالي', 'male'),
  ('نسائي', 'female'),
  ('للجنسين', 'unisex'),
  ('غير محدد', ''),
];

class CollectionPage extends StatefulWidget {
  const CollectionPage({
    super.key,
    required this.onProduct,
    required this.isFavorite,
    required this.onFavorite,
  });
  final ValueChanged<Product> onProduct;
  final bool Function(Product) isFavorite;
  final ValueChanged<Product> onFavorite;
  @override
  State<CollectionPage> createState() => _CollectionPageState();
}

class _CollectionPageState extends State<CollectionPage> {
  late Future<CatalogResult> catalogFuture;
  final TextEditingController searchController = TextEditingController();
  bool availableOnly = false;
  bool favoritesOnly = false;
  String? selectedNote;
  String? selectedSeason;
  String? selectedOccasion;
  String? selectedGender;
  bool _autoRetryScheduled = false;

  /// النسخة المحفوظة السابقة (قبل هذا الجلب) — أساس مقارنة أسعار
  /// المفضلة للتنبيه داخل التطبيق. تُقرأ قبل بدء الجلب الطازج.
  Future<CatalogResult?>? _previousCachedFuture;

  /// هل فُحصت عروض المفضلة لهذا الجلب؟ مرة واحدة لكل تحميل.
  bool _favNoticeChecked = false;

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

  void _loadProducts() {
    _autoRetryScheduled = false;
    _favNoticeChecked = false;
    _previousCachedFuture = ProductCatalog().loadCached();
    catalogFuture = ProductCatalog().fetchCatalog();
  }

  Future<void> _refresh() async {
    setState(_loadProducts);
    await catalogFuture;
  }

  bool get _hasActiveFilters =>
      selectedNote != null ||
      selectedSeason != null ||
      selectedOccasion != null ||
      selectedGender != null ||
      favoritesOnly;

  void _clearFilters() => setState(() {
        selectedNote = null;
        selectedSeason = null;
        selectedOccasion = null;
        selectedGender = null;
        favoritesOnly = false;
      });

  /// يقارن التشكيلة الطازجة بالمحفوظة، وإن انخفض سعر عطر مفضّل أو
  /// عاد للمخزون يعرض تنبيهاً داخل التطبيق (بديل تنبيهات العروض
  /// الذي لا يحتاج الخادم). يُحترم مبدّل تنبيهات عروض المفضلة.
  Future<void> _checkFavoriteOffers(List<Product> fresh) async {
    try {
      if (!await FavoritesOfferService().isEnabled()) return;
      final previous = await _previousCachedFuture;
      if (previous == null) return;
      final favorites = await FavoritesService().load();
      if (favorites.isEmpty) return;
      final changes = detectFavoriteChanges(
        fresh: fresh,
        previous: previous.products,
        favoriteIds: favorites,
      );
      if (changes.isEmpty || !mounted) return;
      final change = changes.first;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(change.message),
        action: SnackBarAction(
          label: 'عرض العطر',
          onPressed: () => widget.onProduct(change.product),
        ),
        duration: const Duration(seconds: 6),
      ));
    } catch (_) {}
  }

  /// يعيد المحاولة في الخلفية مرة واحدة بعد 10 ثوانٍ إن كانت التشكيلة
  /// المعروضة نسخة محفوظة — دون أن يزعج المستخدم.
  void _scheduleBackgroundRetry() {
    if (_autoRetryScheduled) return;
    _autoRetryScheduled = true;
    unawaited(Future<void>.delayed(const Duration(seconds: 10), () async {
      if (!mounted) return;
      final result = await catalogFuture;
      if (!mounted || !result.fromCache) return;
      setState(_loadProducts);
    }));
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
              Padding(
                padding: EdgeInsets.fromLTRB(20, 15, 20, 16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('التشكيلة', style: TextStyle(color: context.ink, fontSize: 30, fontWeight: FontWeight.w600)),
                  SizedBox(height: 6),
                  Text('اختر أثرك من عطور زخم الرسمية', style: TextStyle(color: context.subdued)),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'ابحث عن عطر...',
                    prefixIcon: Icon(Icons.search, color: context.goldText),
                    suffixIcon: searchController.text.isEmpty ? null : IconButton(onPressed: () { searchController.clear(); setState(() {}); }, icon: const Icon(Icons.close)),
                    filled: true,
                    fillColor: context.surfaceCard,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                ),
              ),
              // سطر أفقي واحد قابل للتمرير بدل سطرين غير متماثلين
              // (زران فوق وواحد منفرد تحتهما).
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    ChoiceChip(label: const Text('كل العطور'), selected: !availableOnly && !favoritesOnly, onSelected: (_) => setState(() { availableOnly = false; favoritesOnly = false; })),
                    const SizedBox(width: 8),
                    ChoiceChip(label: const Text('المتوفر فقط'), selected: availableOnly, onSelected: (_) => setState(() => availableOnly = true)),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('المفضلة فقط'),
                      selected: favoritesOnly,
                      onSelected: (_) => setState(() {
                        favoritesOnly = !favoritesOnly;
                        if (favoritesOnly) availableOnly = false;
                      }),
                    ),
                  ]),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ProductTile(product: featuredProduct, badge: 'عطر مميز', onTap: () => widget.onProduct(featuredProduct), favorite: widget.isFavorite(featuredProduct), onFavorite: () => widget.onFavorite(featuredProduct)),
              ),
              Padding(padding: EdgeInsets.fromLTRB(20, 24, 20, 12), child: Text('كل العطور', textAlign: TextAlign.right, style: TextStyle(color: context.ink, fontSize: 20, fontWeight: FontWeight.w600))),
              FutureBuilder<CatalogResult>(
                future: catalogFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) return Padding(padding: EdgeInsets.all(28), child: Center(child: CircularProgressIndicator(color: context.goldText)));
                  if (snapshot.hasError) return Padding(padding: const EdgeInsets.all(20), child: Column(children: [Text('تعذر تحميل المنتجات حالياً.', textAlign: TextAlign.center, style: TextStyle(color: context.subdued)), const SizedBox(height: 10), OutlinedButton(onPressed: _refresh, child: const Text('إعادة المحاولة'))]));
                  final result = snapshot.data!;
                  final all = result.products;
                  if (result.fromCache) _scheduleBackgroundRetry();
                  if (!result.fromCache && !_favNoticeChecked) {
                    _favNoticeChecked = true;
                    unawaited(_checkFavoriteOffers(all));
                  }
                  final query = searchController.text.trim().toLowerCase();
                  final products = all.where((product) {
                    final matchesSearch = query.isEmpty || product.name.toLowerCase().contains(query) || product.nameEn.toLowerCase().contains(query) || product.category.toLowerCase().contains(query);
                    if (!matchesSearch) return false;
                    if (availableOnly && !product.inStock) return false;
                    if (favoritesOnly && !widget.isFavorite(product)) return false;
                    if (selectedNote != null && !product.matchesNote(selectedNote!)) return false;
                    if (selectedSeason != null && !product.matchesSeason(selectedSeason!)) return false;
                    if (selectedOccasion != null && !product.matchesOccasion(selectedOccasion!)) return false;
                    if (selectedGender != null && product.gender != selectedGender) return false;
                    return true;
                  }).toList(growable: false);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (result.fromCache) _StaleCatalogBanner(cachedAt: result.cachedAt, onRetry: _refresh),
                      _SmartFilters(
                        products: all,
                        selectedNote: selectedNote,
                        selectedSeason: selectedSeason,
                        selectedOccasion: selectedOccasion,
                        selectedGender: selectedGender,
                        onNote: (value) => setState(() => selectedNote = value),
                        onSeason: (value) =>
                            setState(() => selectedSeason = value),
                        onOccasion: (value) =>
                            setState(() => selectedOccasion = value),
                        onGender: (value) =>
                            setState(() => selectedGender = value),
                      ),
                      if (products.isEmpty) _buildEmptyState(),
                      ...products.map((product) => ApiProductCard(
                            product: product,
                            onTap: () => widget.onProduct(product),
                            favorite: widget.isFavorite(product),
                            onFavorite: () => widget.onFavorite(product),
                          )),
                    ],
                  );
                },
              ),
              // مساحة سفلية تُخلي البطاقة الأخيرة من زر «مساعد دار
              // زخم» العائم أثناء التمرير (الزر ~48px فوق شريط
              // التنقل السفلي).
              const SizedBox(height: 96),
            ],
          ),
        ),
      );

  Widget _buildEmptyState() {
    if (favoritesOnly &&
        !_hasActiveFiltersExceptFavorites &&
        searchController.text.trim().isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          Icon(Icons.favorite_border, color: context.goldText, size: 40),
          const SizedBox(height: 12),
          Text('لم تحفظ أي عطر بعد', textAlign: TextAlign.center, style: TextStyle(color: context.ink, fontSize: 17, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text('اضغط على علامة القلب بجانب عطرك المفضل ليظهر هنا.', textAlign: TextAlign.center, style: TextStyle(color: context.subdued, height: 1.6)),
        ]),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        Text('لا توجد عطور تطابق البحث أو التصفية حالياً.', textAlign: TextAlign.center, style: TextStyle(color: context.subdued)),
        if (_hasActiveFilters) ...[
          const SizedBox(height: 10),
          OutlinedButton(onPressed: _clearFilters, child: const Text('مسح التصفية')),
        ],
      ]),
    );
  }

  bool get _hasActiveFiltersExceptFavorites =>
      selectedNote != null ||
      selectedSeason != null ||
      selectedOccasion != null ||
      selectedGender != null;
}

/// شريط صغير يظهر عند عرض نسخة محفوظة من التشكيلة (بلا نت).
class _StaleCatalogBanner extends StatelessWidget {
  const _StaleCatalogBanner({required this.cachedAt, required this.onRetry});
  final DateTime? cachedAt;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final date = cachedAt == null
        ? ''
        : ' — آخر تحديث ${cachedAt!.day}/${cachedAt!.month}/${cachedAt!.year}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: gold.withOpacity(.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: gold.withOpacity(.35)),
        ),
        child: Row(children: [
          Icon(Icons.cloud_off_outlined, color: context.goldText, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'تعرض نسخة محفوظة من التشكيلة$date — تحقق من اتصالك بالإنترنت.',
              style: TextStyle(color: context.ink, fontSize: 12, height: 1.5),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('إعادة المحاولة')),
        ]),
      ),
    );
  }
}

/// خيارات فلتر مع عدّادها: (التسمية، القيمة، عدد المطابقات).
/// يُعرض كل خيار فقط إن طابق عطراً واحداً على الأقل من التشكيلة
/// المحمّلة. دالة خالصة (قابلة للاختبار) — يستخدمها `_SmartFilters`.
List<(String, String, int)> filterOptionsWithCounts(
  List<Product> products,
  List<(String, String)> options,
  bool Function(Product, String) matches,
) =>
    options
        .map((option) {
          final count =
              products.where((p) => matches(p, option.$2)).length;
          return (option.$1, option.$2, count);
        })
        .where((option) => option.$3 > 0)
        .toList(growable: false);

/// قوائم التصفية الذكية المنسدلة: النوتة / الموسم / المناسبة / النوع.
/// كل فلتر قائمة منسدلة مدمجة (التسمية + العدد بين قوسين) بدل صفوف
/// الأزرار المفرودة التي كانت تدفع التشكيلة للأسفل؛ «الكل» يلغي الفلتر.
class _SmartFilters extends StatelessWidget {
  const _SmartFilters({
    required this.products,
    required this.selectedNote,
    required this.selectedSeason,
    required this.selectedOccasion,
    required this.selectedGender,
    required this.onNote,
    required this.onSeason,
    required this.onOccasion,
    required this.onGender,
  });

  final List<Product> products;
  final String? selectedNote;
  final String? selectedSeason;
  final String? selectedOccasion;
  final String? selectedGender;
  final ValueChanged<String?> onNote;
  final ValueChanged<String?> onSeason;
  final ValueChanged<String?> onOccasion;
  final ValueChanged<String?> onGender;

  @override
  Widget build(BuildContext context) {
    final notes = filterOptionsWithCounts(
      products,
      _noteOptions,
      (product, keyword) => product.matchesNote(keyword),
    );
    final seasons = filterOptionsWithCounts(
      products,
      _seasonOptions,
      (product, needle) => product.matchesSeason(needle),
    );
    final occasions = filterOptionsWithCounts(
      products,
      _occasionOptions.map((label) => (label, label)).toList(),
      (product, label) => product.matchesOccasion(label),
    );
    final genders = filterOptionsWithCounts(
      products,
      _genderOptions,
      (product, value) => product.gender == value,
    );
    if (notes.isEmpty &&
        seasons.isEmpty &&
        occasions.isEmpty &&
        genders.isEmpty) {
      return const SizedBox.shrink();
    }
    final filters = <Widget>[
      if (notes.isNotEmpty)
        _FilterDropdown(
          label: 'النوتة',
          options: notes,
          selected: selectedNote,
          onSelected: onNote,
        ),
      if (seasons.isNotEmpty)
        _FilterDropdown(
          label: 'الموسم',
          options: seasons,
          selected: selectedSeason,
          onSelected: onSeason,
        ),
      if (occasions.isNotEmpty)
        _FilterDropdown(
          label: 'المناسبة',
          options: occasions,
          selected: selectedOccasion,
          onSelected: onOccasion,
        ),
      if (genders.isNotEmpty)
        _FilterDropdown(
          label: 'النوع',
          options: genders,
          selected: selectedGender,
          onSelected: onGender,
        ),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            'تصفية ذكية',
            textAlign: TextAlign.right,
            style: TextStyle(
              color: context.ink,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          // شبكة 2×2 (قائمتان في كل سطر) حتى لا تدفع القوائم الأربع
          // التشكيلة للأسفل بارتفاع كبير.
          for (var i = 0; i < filters.length; i += 2)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: filters[i]),
                  const SizedBox(width: 10),
                  Expanded(
                    child: i + 1 < filters.length
                        ? filters[i + 1]
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// قائمة منسدلة واحدة لفلتر: تسمية صغيرة فوق حقل منسدل منسق
/// (خلفية بطاقة، زوايا 16، سهم ذهبي)؛ الخيار الأول «الكل» يلغي الفلتر.
class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.label,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final List<(String, String, int)> options;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(label, style: TextStyle(color: context.subdued, fontSize: 12)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String?>(
              value: selected,
              isExpanded: true,
              dropdownColor: context.surfaceCard,
              icon: Icon(
                Icons.keyboard_arrow_down,
                color: context.goldText,
                size: 20,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: context.surfaceCard,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 4,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
              items: <DropdownMenuItem<String?>>[
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('الكل'),
                ),
                ...options.map(
                  (option) => DropdownMenuItem<String?>(
                    value: option.$2,
                    child: Text('${option.$1} (${option.$3})'),
                  ),
                ),
              ],
              onChanged: onSelected,
            ),
          ],
        );
}
