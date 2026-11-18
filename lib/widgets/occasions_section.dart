import 'package:flutter/material.dart';

import '../models/product.dart';
import '../services/occasions.dart';
import '../services/product_catalog.dart';
import '../theme/app_theme.dart';
import 'common_widgets.dart';

/// قسم «مناسبات قادمة» — يعرض أقرب 3 مناسبات (الأقرب أولاً) مع
/// تاريخ كل مناسبة وعطورها المقترحة كهدايا (من الكتالوج الحي، أو
/// النسخة المحفوظة بلا نت). زر العطر يفتح صفحته. يُستخدم في
/// الرئيسية وفي صفحة الأقسام.
class OccasionsSection extends StatefulWidget {
  const OccasionsSection({super.key, required this.onProduct});

  final ValueChanged<Product> onProduct;

  @override
  State<OccasionsSection> createState() => _OccasionsSectionState();
}

class _OccasionsSectionState extends State<OccasionsSection> {
  final ProductCatalog _catalog = ProductCatalog();
  List<UpcomingOccasion> _upcoming = const <UpcomingOccasion>[];
  bool _loaded = false;

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
        _upcoming = upcomingOccasions(result.products, DateTime.now());
        _loaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _upcoming.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'مناسبات قادمة', horizontal: 0),
        ..._upcoming.map(
          (occasion) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _OccasionCard(
              occasion: occasion,
              onProduct: widget.onProduct,
            ),
          ),
        ),
      ],
    );
  }
}

class _OccasionCard extends StatelessWidget {
  const _OccasionCard({required this.occasion, required this.onProduct});

  final UpcomingOccasion occasion;
  final ValueChanged<Product> onProduct;

  @override
  Widget build(BuildContext context) {
    final days = occasion.daysUntil(DateTime.now());
    final when = days == 0
        ? 'اليوم'
        : days == 1
            ? 'غداً'
            : 'بعد $days ${days == 2 ? 'يومين' : 'يوم'}';
    return Container(
      padding: const EdgeInsets.all(16),
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
              Icon(Icons.event_outlined, color: context.goldText, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  occasion.occasion.title,
                  style: TextStyle(
                    color: context.ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: gold.withOpacity(.16),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  when,
                  style: TextStyle(
                    color: context.goldText,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            formatArabicDate(occasion.date) +
                (occasion.occasion.hijri ? ' — قد يختلف يوماً حسب رؤية الهلال' : ''),
            style: TextStyle(color: context.subdued, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Text(
            occasion.occasion.giftNote,
            style: TextStyle(color: context.ink, fontSize: 13, height: 1.6),
          ),
          if (occasion.gifts.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 118,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: occasion.gifts.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final product = occasion.gifts[index];
                  return _GiftChip(
                    product: product,
                    onTap: () => onProduct(product),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GiftChip extends StatelessWidget {
  const _GiftChip({required this.product, required this.onTap});

  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 148,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: gold.withOpacity(.07),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    product.image,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: const Color(0xFF30271D),
                      child: const Center(
                        child: Icon(Icons.spa_outlined, color: gold, size: 20),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                product.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: context.ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${product.price.toStringAsFixed(0)} ${product.currency}',
                style: TextStyle(color: context.goldText, fontSize: 11),
              ),
            ],
          ),
        ),
      );
}
