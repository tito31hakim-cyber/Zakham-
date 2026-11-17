import 'dart:async';

import 'package:flutter/material.dart';
import '../data/featured_product.dart';
import '../models/product.dart';
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
const List<(String, String)> _genderOptions = <(String, String)>[
  ('رجالي', 'male'),
  ('نسائي', 'female'),
  ('للجنسين', 'unisex'),
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
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                child: Wrap(spacing: 8, children: [
                  ChoiceChip(label: const Text('كل العطور'), selected: !availableOnly && !favoritesOnly, onSelected: (_) => setState(() { availableOnly = false; favoritesOnly = false; })),
                  ChoiceChip(label: const Text('المتوفر فقط'), selected: availableOnly, onSelected: (_) => setState(() => availableOnly = true)),
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ProductTile(product: featuredProduct, onTap: () => widget.onProduct(featuredProduct), favorite: widget.isFavorite(featuredProduct), onFavorite: () => widget.onFavorite(featuredProduct)),
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
                        onNote: (value) => setState(() => selectedNote = selectedNote == value ? null : value),
                        onSeason: (value) => setState(() => selectedSeason = selectedSeason == value ? null : value),
                        onOccasion: (value) => setState(() => selectedOccasion = selectedOccasion == value ? null : value),
                        onGender: (value) => setState(() => selectedGender = selectedGender == value ? null : value),
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
              const SizedBox(height: 28),
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

/// صفوف التصفية الذكية: النوتة / الموسم / المناسبة / النوع.
/// يُعرض كل خيار فقط إن طابق عطراً واحداً على الأقل من التشكيلة
/// المحمّلة، مع عدد المطابقات بين قوسين.
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
  final ValueChanged<String> onNote;
  final ValueChanged<String> onSeason;
  final ValueChanged<String> onOccasion;
  final ValueChanged<String> onGender;

  List<(String, String, int)> _withCounts(
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

  @override
  Widget build(BuildContext context) {
    final notes = _withCounts(
      _noteOptions,
      (product, keyword) => product.matchesNote(keyword),
    );
    final seasons = _withCounts(
      _seasonOptions,
      (product, needle) => product.matchesSeason(needle),
    );
    final occasions = _occasionOptions
        .map((label) {
          final count = products
              .where((p) => p.matchesOccasion(label))
              .length;
          return (label, label, count);
        })
        .where((option) => option.$3 > 0)
        .toList(growable: false);
    final genders = _withCounts(
      _genderOptions,
      (product, value) => product.gender == value,
    );
    if (notes.isEmpty &&
        seasons.isEmpty &&
        occasions.isEmpty &&
        genders.isEmpty) {
      return const SizedBox.shrink();
    }
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
          if (notes.isNotEmpty)
            _FilterRow(
              label: 'النوتة',
              options: notes,
              selected: selectedNote,
              onSelected: onNote,
            ),
          if (seasons.isNotEmpty)
            _FilterRow(
              label: 'الموسم',
              options: seasons,
              selected: selectedSeason,
              onSelected: onSeason,
            ),
          if (occasions.isNotEmpty)
            _FilterRow(
              label: 'المناسبة',
              options: occasions,
              selected: selectedOccasion,
              onSelected: onOccasion,
            ),
          if (genders.isNotEmpty)
            _FilterRow(
              label: 'النوع',
              options: genders,
              selected: selectedGender,
              onSelected: onGender,
            ),
        ],
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.label,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final List<(String, String, int)> options;
  final String? selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(label, style: TextStyle(color: context.subdued, fontSize: 12)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: options.map((option) {
                final isSelected = selected == option.$2;
                return ChoiceChip(
                  label: Text('${option.$1} (${option.$3})'),
                  selected: isSelected,
                  onSelected: (_) => onSelected(option.$2),
                  selectedColor: gold.withOpacity(.25),
                  labelStyle: TextStyle(
                    color: isSelected ? context.goldText : context.ink,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                  ),
                );
              }).toList(growable: false),
            ),
          ],
        ),
      );
}
