import 'package:flutter/material.dart';

import '../models/fragrance_identity.dart';
import '../theme/app_theme.dart';
import 'identity_axes.dart';

/// بطاقة ترشيح واحدة في نتيجة «بصمة زخم»: اسم العطر واقتباسه،
/// وأسباب الترشيح، ومحاور المقارنة الخمسة، وسعر التركيز والحجم
/// المختارين (من بيانات المتجر الحية فقط — وإن لم يتوفر سعر لهما
/// لا يُعرض سعر إطلاقاً)، وأزرار العرض والإضافة للسلة.
///
/// العطور الثلاثة الجديدة (ليل، إلكسير، سلطان) درجات محاورها قيم
/// افتراضية من نصوص المتجر — يُمرَّر ذلك للتنويه أسفل المحاور.
class IdentityResultCard extends StatelessWidget {
  const IdentityResultCard({
    super.key,
    required this.recommendation,
    required this.concentration,
    required this.sizeMl,
    this.price,
    required this.rank,
    required this.onViewProduct,
    required this.onAddToCart,
  });

  final IdentityRecommendation recommendation;
  final String concentration;
  final int sizeMl;

  /// سعر التركيز والحجم المختارين من المتجر الحي، أو null إن لم يتوفر.
  final double? price;
  final int rank;
  final VoidCallback onViewProduct;
  final VoidCallback onAddToCart;

  static const Set<String> _defaultStatsIds = <String>{
    'layl',
    'elixir',
    'sultan',
  };

  @override
  Widget build(BuildContext context) {
    final card = recommendation.card;
    final product = card.product;
    final concentrationLabel = product.concentrationLabel(concentration);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: rank == 1 ? gold.withOpacity(.55) : context.hairline,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: gold.withOpacity(.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  rank == 1 ? 'الترشيح الأول' : 'ترشيح ${rank + 1}',
                  style: TextStyle(
                    color: context.goldText,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              if (card.extra.code.isNotEmpty)
                Text(
                  card.extra.code,
                  style: TextStyle(color: context.subdued, fontSize: 12),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            product.name,
            style: TextStyle(
              color: context.ink,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (card.extra.quote.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              card.extra.quote,
              style: TextStyle(color: context.subdued, fontSize: 14, height: 1.7),
            ),
          ],
          const SizedBox(height: 12),
          ...recommendation.reasons.map(
            (reason) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• ', style: TextStyle(color: context.goldText)),
                  Expanded(
                    child: Text(
                      reason,
                      style: TextStyle(color: context.ink, fontSize: 14, height: 1.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          IdentityAxes(
            stats: card.extra.stats,
            valuesAreDefaults: _defaultStatsIds.contains(product.id),
          ),
          const SizedBox(height: 14),
          if (price != null)
            // مسافة غير فاصلة (U+00A0) بين الرقم و«مل» حتى لا تنفصل
            // الوحدة في سطر جديد عن الرقم.
            Text(
              '${price!.toStringAsFixed(0)} ج.م — $concentrationLabel · $sizeMl\u00A0مل',
              style: TextStyle(
                color: context.goldText,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            )
          else
            Text(
              'السعر حسب التركيز والحجم في صفحة العطر.',
              style: TextStyle(color: context.subdued, fontSize: 13),
            ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: onViewProduct,
                  child: const Text('عرض العطر'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: onAddToCart,
                  child: const Text('أضف للسلة'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
