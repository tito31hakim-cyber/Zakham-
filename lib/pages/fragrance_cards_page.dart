import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/fragrance_cards.dart';
import '../data/store_sections.dart';
import '../models/product.dart';
import '../services/product_catalog.dart';
import '../theme/app_theme.dart';

/// صفحة «البطاقات العطرية» — نفس صفحة الموقع
/// `zakhamhouse.shop/fragrance-cards/`: بطاقات العطور الأحد عشر من
/// بيانات المتجر الحية (وتُعرض النسخة المحفوظة بلا نت — كتالوج المرحلة
/// 1 — فلا تظهر الصفحة فارغة أبداً)، والمستكشف الذكي (سؤالان بنفس
/// نصوص وخيارات الموقع ومنطق التوصية نفسه)، ورادار يقارن عطرين على
/// المحاور الخمسة نفسها (الثبات، الفوحان، الدفء، الانتعاش، الهيبة).
class FragranceCardsPage extends StatefulWidget {
  const FragranceCardsPage({
    super.key,
    required this.onProduct,
    required this.isFavorite,
    required this.onFavorite,
  });

  final ValueChanged<Product> onProduct;
  final bool Function(Product product) isFavorite;
  final ValueChanged<Product> onFavorite;

  @override
  State<FragranceCardsPage> createState() => _FragranceCardsPageState();
}

class _FragranceCardsPageState extends State<FragranceCardsPage> {
  final ProductCatalog _catalog = ProductCatalog();
  List<FragranceCard> _cards = <FragranceCard>[];
  bool _loading = true;
  bool _fromCache = false;
  DateTime? _cachedAt;
  String? _error;
  bool _retrying = false;

  int _wizardStep = 0;
  String? _wizardCategory;
  String? _wizardType;
  FragranceCard? _recommended;

  String? _radarFirstId;
  String? _radarSecondId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final result = await _catalog.fetchCatalog();
      if (!mounted) return;
      setState(() {
        _cards = mergeFragranceCards(result.products);
        _fromCache = result.fromCache;
        _cachedAt = result.cachedAt;
        _loading = false;
        _error = null;
        _radarFirstId ??= _cards.isNotEmpty ? _cards.first.product.id : null;
        _radarSecondId ??= _cards.length > 1 ? _cards[1].product.id : null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذر تحميل البطاقات العطرية الآن.';
      });
    }
  }

  Future<void> _retry() async {
    if (_retrying) return;
    setState(() => _retrying = true);
    await _load();
    if (mounted) setState(() => _retrying = false);
  }

  void _wizardSelect(int step, String value) {
    if (step == 0) {
      setState(() {
        _wizardCategory = value;
        _wizardStep = 1;
      });
    } else {
      setState(() {
        _wizardType = value;
        _wizardStep = 2;
        _recommended = recommendFragranceCard(
          _cards,
          _wizardCategory ?? '',
          _wizardType ?? '',
        );
      });
    }
  }

  void _resetWizard() {
    setState(() {
      _wizardStep = 0;
      _wizardCategory = null;
      _wizardType = null;
      _recommended = null;
    });
  }

  Future<void> _orderRecommended(FragranceCard card) async {
    final uri = Uri.parse(
      zakhamWhatsAppUrl(
        'مرحباً دار زخم، أود طلب ${card.product.name} بناءً على توصية المستكشف الذكي.',
      ),
    );
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر فتح واتساب على هذا الجهاز.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('البطاقات العطرية')),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: gold))
            : _error != null && _cards.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.style_outlined,
                              color: context.goldText, size: 48),
                          const SizedBox(height: 16),
                          Text(_error!,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: context.ink, fontSize: 16)),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: _retrying ? null : _retry,
                            child: const Text('إعادة المحاولة'),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
                    children: [
                      Text(
                        'البطاقات العطرية الرسمية',
                        style: TextStyle(
                          color: context.ink,
                          fontSize: 26,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'الكتالوج الرقمي الرسمي والبطاقات التعريفية — استكشف جميع إصدارات زخم، مكونات الهرم العطري، وطابع كل عطر.',
                        style: TextStyle(color: context.subdued, height: 1.7),
                      ),
                      if (_fromCache) ...[
                        const SizedBox(height: 12),
                        _CacheBanner(cachedAt: _cachedAt, onRetry: _retry),
                      ],
                      const SizedBox(height: 20),
                      _ExplorerCard(
                        step: _wizardStep,
                        recommended: _recommended,
                        onSelect: _wizardSelect,
                        onReset: _resetWizard,
                        onOrder: _orderRecommended,
                        onOpenProduct: widget.onProduct,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'قائمة البطاقات العطرية الفاخرة',
                        style: TextStyle(
                          color: context.ink,
                          fontSize: 21,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ..._cards.map(
                        (card) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _FragranceCardTile(
                            card: card,
                            favorite: widget.isFavorite(card.product),
                            onFavorite: () => widget.onFavorite(card.product),
                            onTap: () => widget.onProduct(card.product),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _RadarSection(
                        cards: _cards,
                        firstId: _radarFirstId,
                        secondId: _radarSecondId,
                        onFirstChanged: (id) =>
                            setState(() => _radarFirstId = id),
                        onSecondChanged: (id) =>
                            setState(() => _radarSecondId = id),
                      ),
                    ],
                  ),
      ),
    );
  }
}

class _CacheBanner extends StatelessWidget {
  const _CacheBanner({required this.cachedAt, required this.onRetry});
  final DateTime? cachedAt;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: gold.withOpacity(.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: gold.withOpacity(.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.cloud_off_outlined, color: context.goldText, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'تعرض نسخة محفوظة${cachedAt == null ? '' : ' — آخر تحديث ${cachedAt!.day}/${cachedAt!.month}/${cachedAt!.year}'}',
                style: TextStyle(color: context.subdued, fontSize: 12),
              ),
            ),
            TextButton(onPressed: onRetry, child: const Text('إعادة المحاولة')),
          ],
        ),
      );
}

class _ExplorerCard extends StatelessWidget {
  const _ExplorerCard({
    required this.step,
    required this.recommended,
    required this.onSelect,
    required this.onReset,
    required this.onOrder,
    required this.onOpenProduct,
  });

  final int step;
  final FragranceCard? recommended;
  final void Function(int step, String value) onSelect;
  final VoidCallback onReset;
  final void Function(FragranceCard card) onOrder;
  final ValueChanged<Product> onOpenProduct;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: context.surfaceCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: gold.withOpacity(.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, color: context.goldText),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'المستكشف الذكي',
                    style: TextStyle(
                      color: context.ink,
                      fontSize: 19,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  step >= 2 ? 'النتيجة' : '${step + 1} / 2',
                  style: TextStyle(color: context.goldText, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'أجب عن سؤالين سريعين ليقوم النظام باقتراح العطر المثالي لطبيعة شخصيتك والمناسبة التي تستعد لها.',
              style: TextStyle(color: context.subdued, height: 1.7, fontSize: 13),
            ),
            const SizedBox(height: 16),
            if (step < 2) ...[
              Text(
                wizardQuestions[step].title,
                style: TextStyle(
                  color: context.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              ...wizardQuestions[step].options.map(
                    (option) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => onSelect(step, option.value),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 14,
                            ),
                            alignment: Alignment.centerRight,
                          ),
                          child: Text(
                            option.label,
                            textAlign: TextAlign.right,
                            style: TextStyle(color: context.ink),
                          ),
                        ),
                      ),
                    ),
                  ),
              if (step == 1)
                TextButton(
                  onPressed: onReset,
                  child: const Text('العودة للسؤال الأول'),
                ),
            ] else if (recommended != null) ...[
              _RecommendedCard(
                card: recommended!,
                onOrder: () => onOrder(recommended!),
                onOpenProduct: () => onOpenProduct(recommended!.product),
                onReset: onReset,
              ),
            ],
          ],
        ),
      );
}

class _RecommendedCard extends StatelessWidget {
  const _RecommendedCard({
    required this.card,
    required this.onOrder,
    required this.onOpenProduct,
    required this.onReset,
  });

  final FragranceCard card;
  final VoidCallback onOrder;
  final VoidCallback onOpenProduct;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'العطر الموصى به لك',
            style: TextStyle(color: context.goldText, fontSize: 13),
          ),
          const SizedBox(height: 8),
          if (card.extra.code.isNotEmpty)
            Text(
              card.extra.code,
              style: const TextStyle(
                color: gold,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
          Text(
            card.product.name,
            style: TextStyle(
              color: context.ink,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (card.product.nameEn.isNotEmpty)
            Text(
              card.product.nameEn,
              style: TextStyle(
                color: context.subdued,
                fontSize: 11,
                letterSpacing: 1.5,
              ),
            ),
          const SizedBox(height: 6),
          Text(
            '"${card.extra.quote}"',
            style: TextStyle(
              color: context.subdued,
              fontStyle: FontStyle.italic,
              height: 1.7,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'القمة: ${card.extra.top}',
            style: TextStyle(color: context.goldText, fontSize: 13),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onOrder,
                  icon: const Icon(Icons.chat_outlined, size: 18),
                  label: const Text('طلب العطر عبر واتساب'),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: onOpenProduct,
                child: const Text('عرض العطر'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: onReset,
              child: const Text('إعادة الاختيار 🔄'),
            ),
          ),
        ],
      );
}

class _FragranceCardTile extends StatelessWidget {
  const _FragranceCardTile({
    required this.card,
    required this.favorite,
    required this.onFavorite,
    required this.onTap,
  });

  final FragranceCard card;
  final bool favorite;
  final VoidCallback onFavorite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final product = card.product;
    final extra = card.extra;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: context.surfaceCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.hairline),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                Image.network(
                  product.image,
                  height: 210,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 210,
                    color: const Color(0xFF32261E),
                    child: const Center(
                      child: Icon(Icons.spa_outlined, color: gold, size: 56),
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      extra.tag,
                      style: const TextStyle(color: gold, fontSize: 11),
                    ),
                  ),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: IconButton(
                    onPressed: onFavorite,
                    tooltip: favorite ? 'إزالة من المفضلة' : 'أضف للمفضلة',
                    icon: Icon(
                      favorite ? Icons.favorite : Icons.favorite_border,
                      color: favorite ? Colors.redAccent : Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (extra.code.isNotEmpty)
                    Text(
                      extra.code,
                      style: const TextStyle(
                        color: gold,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  Text(
                    product.name,
                    style: TextStyle(
                      color: context.ink,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (product.nameEn.isNotEmpty)
                    Text(
                      product.nameEn,
                      style: TextStyle(
                        color: context.subdued,
                        fontSize: 11,
                        letterSpacing: 1.5,
                      ),
                    ),
                  const SizedBox(height: 6),
                  Text(
                    '"${extra.quote}"',
                    style: TextStyle(
                      color: context.subdued,
                      fontStyle: FontStyle.italic,
                      height: 1.7,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _PyramidRow(title: 'القمة', text: extra.top),
                  _PyramidRow(title: 'القلب', text: extra.heart),
                  _PyramidRow(title: 'القاعدة', text: extra.base),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(
                        '${product.price.toStringAsFixed(0)} ${product.currency}',
                        style: TextStyle(
                          color: context.goldText,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'يبدأ من',
                        style: TextStyle(color: context.subdued, fontSize: 11),
                      ),
                      const Spacer(),
                      Text(
                        product.season.isNotEmpty ? product.season : extra.tag,
                        style: TextStyle(color: context.subdued, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PyramidRow extends StatelessWidget {
  const _PyramidRow({required this.title, required this.text});
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$title: ',
              style: TextStyle(
                color: context.goldText,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            Expanded(
              child: Text(
                text,
                style: TextStyle(color: context.subdued, fontSize: 12, height: 1.6),
              ),
            ),
          ],
        ),
      );
}

class _RadarSection extends StatelessWidget {
  const _RadarSection({
    required this.cards,
    required this.firstId,
    required this.secondId,
    required this.onFirstChanged,
    required this.onSecondChanged,
  });

  final List<FragranceCard> cards;
  final String? firstId;
  final String? secondId;
  final ValueChanged<String?> onFirstChanged;
  final ValueChanged<String?> onSecondChanged;

  FragranceCard? _byId(String? id) {
    if (id == null) return null;
    for (final card in cards) {
      if (card.product.id == id) return card;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final first = _byId(firstId) ?? (cards.isNotEmpty ? cards.first : null);
    final second =
        _byId(secondId) ?? (cards.length > 1 ? cards[1] : null);
    if (first == null || second == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'تحليل المكونات والأداء',
            style: TextStyle(
              color: context.ink,
              fontSize: 19,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'يعرض الرادار التوازن الدقيق بين خصائص الأداء الخمسة لكل عطر (الثبات، الفوحان، الدفء، الانتعاش، والهيبة الشرقية). اختر عطرين لمقارنتهما جنباً إلى جنب.',
            style: TextStyle(color: context.subdued, height: 1.7, fontSize: 13),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _RadarDropdown(
                  label: 'العطر الأول (الذهبي)',
                  cards: cards,
                  value: first.product.id,
                  onChanged: onFirstChanged,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _RadarDropdown(
                  label: 'العطر الثاني (الداكن)',
                  cards: cards,
                  value: second.product.id,
                  onChanged: onSecondChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Center(
            child: _RadarChart(
              first: first.extra.stats,
              second: second.extra.stats,
              firstColor: gold,
              secondColor: context.ink,
            ),
          ),
          const SizedBox(height: 8),
          ...List.generate(radarAxes.length, (index) {
            final firstValue = first.extra.stats[index];
            final secondValue = second.extra.stats[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        radarAxes[index],
                        style: TextStyle(color: context.ink, fontSize: 12),
                      ),
                      const Spacer(),
                      Text(
                        '$firstValue',
                        style: const TextStyle(
                          color: gold,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        ' / $secondValue',
                        style: TextStyle(color: context.subdued, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: firstValue / 100,
                            minHeight: 6,
                            color: gold,
                            backgroundColor: context.hairline,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: secondValue / 100,
                            minHeight: 6,
                            color: context.ink.withOpacity(.55),
                            backgroundColor: context.hairline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendDot(color: gold, label: first.product.name),
              const SizedBox(width: 16),
              _LegendDot(color: context.ink, label: second.product.name),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: context.subdued, fontSize: 12)),
        ],
      );
}

class _RadarDropdown extends StatelessWidget {
  const _RadarDropdown({
    required this.label,
    required this.cards,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final List<FragranceCard> cards;
  final String value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: context.subdued, fontSize: 11)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              border: Border.all(color: context.hairline),
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                items: cards
                    .map(
                      (card) => DropdownMenuItem<String>(
                        value: card.product.id,
                        child: Text(
                          card.product.name,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: context.ink, fontSize: 13),
                        ),
                      ),
                    )
                    .toList(growable: false),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      );
}

/// رادار خماسي — مضلعان متداخلان (ذهبي للأول، بلون النص للثاني)
/// فوق شبكة من ثلاث حلقات، مع تسميات المحاور الخمسة.
class _RadarChart extends StatelessWidget {
  const _RadarChart({
    required this.first,
    required this.second,
    required this.firstColor,
    required this.secondColor,
  });

  final List<int> first;
  final List<int> second;
  final Color firstColor;
  final Color secondColor;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 280,
        height: 260,
        child: CustomPaint(
          painter: _RadarPainter(
            first: first,
            second: second,
            firstColor: firstColor,
            secondColor: secondColor,
            labelColor: context.subdued,
            gridColor: context.hairline,
          ),
        ),
      );
}

class _RadarPainter extends CustomPainter {
  _RadarPainter({
    required this.first,
    required this.second,
    required this.firstColor,
    required this.secondColor,
    required this.labelColor,
    required this.gridColor,
  });

  final List<int> first;
  final List<int> second;
  final Color firstColor;
  final Color secondColor;
  final Color labelColor;
  final Color gridColor;

  static const int _axes = 5;

  Offset _point(Offset center, double radius, int index, double value) {
    final angle = -math.pi / 2 + index * 2 * math.pi / _axes;
    final r = radius * (value / 100).clamp(0.0, 1.0);
    return Offset(
      center.dx + r * math.cos(angle),
      center.dy + r * math.sin(angle),
    );
  }

  Path _polygon(Offset center, double radius, List<int> values) {
    final path = Path();
    for (var i = 0; i < _axes; i++) {
      final point = _point(center, radius, i, values[i].toDouble());
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 + 6);
    final radius = (size.width / 2 - 34).clamp(60.0, 110.0);

    final gridPaint = Paint()
      ..color = gridColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final fraction in const <double>[1 / 3, 2 / 3, 1.0]) {
      final path = Path();
      for (var i = 0; i < _axes; i++) {
        final point = _point(center, radius * fraction, i, 100);
        if (i == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }
    for (var i = 0; i < _axes; i++) {
      canvas.drawLine(
        center,
        _point(center, radius, i, 100),
        gridPaint,
      );
    }

    final secondFill = Paint()
      ..color = secondColor.withOpacity(.12)
      ..style = PaintingStyle.fill;
    final secondStroke = Paint()
      ..color = secondColor.withOpacity(.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawPath(_polygon(center, radius, second), secondFill);
    canvas.drawPath(_polygon(center, radius, second), secondStroke);

    final firstFill = Paint()
      ..color = firstColor.withOpacity(.22)
      ..style = PaintingStyle.fill;
    final firstStroke = Paint()
      ..color = firstColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawPath(_polygon(center, radius, first), firstFill);
    canvas.drawPath(_polygon(center, radius, first), firstStroke);

    for (var i = 0; i < _axes; i++) {
      final angle = -math.pi / 2 + i * 2 * math.pi / _axes;
      final labelOffset = Offset(
        center.dx + (radius + 26) * math.cos(angle),
        center.dy + (radius + 26) * math.sin(angle),
      );
      final span = TextSpan(
        text: radarAxes[i],
        style: TextStyle(color: labelColor, fontSize: 11),
      );
      final painter = TextPainter(
        text: span,
        textDirection: TextDirection.rtl,
      )..layout();
      painter.paint(
        canvas,
        labelOffset - Offset(painter.width / 2, painter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) =>
      oldDelegate.first != first ||
      oldDelegate.second != second ||
      oldDelegate.firstColor != firstColor ||
      oldDelegate.secondColor != secondColor;
}
