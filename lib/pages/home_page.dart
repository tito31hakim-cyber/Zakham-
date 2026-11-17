import 'package:flutter/material.dart';
import '../data/store_sections.dart';
import '../models/product.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../widgets/occasions_section.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.product,
    required this.onProduct,
    required this.onQuiz,
    required this.favorite,
    required this.onFavorite,
    required this.onSection,
    required this.onOpenSections,
    required this.onFragranceCards,
    required this.onVerify,
    required this.onConsultation,
    this.dailyProduct,
    this.showEmptyCartNudge = false,
    this.onBrowseCollection,
    this.onDismissEmptyCartNudge,
  });
  final Product product;
  final ValueChanged<Product> onProduct;
  final VoidCallback onQuiz;
  final bool favorite;
  final VoidCallback onFavorite;

  /// يفتح صفحة تفاصيل قسم (طقس زخم، الإهداء، ...).
  final ValueChanged<String> onSection;

  /// يفتح صفحة «الأقسام» الكاملة.
  final VoidCallback onOpenSections;

  /// يفتح صفحة «البطاقات العطرية».
  final VoidCallback onFragranceCards;

  /// يفتح صفحة «تحقق من الأصالة».
  final VoidCallback onVerify;

  /// يفتح صفحة «حجز استشارة عطرية».
  final VoidCallback onConsultation;

  /// عطر اليوم (من التشكيلة، من الشبكة أو الكاش) — يخفى إن لم
  /// تُحمَّل التشكيلة بعد؛ لا يظهر فارغاً أبداً.
  final Product? dailyProduct;

  /// يظهر تنبيه «السلة الفارغة» اللطيف داخل الرئيسية (مرة كل 3 أيام
  /// كحد أقصى — يديره الغلاف StoreShell).
  final bool showEmptyCartNudge;

  /// يفتح تبويب التشكيلة من تنبيه «السلة الفارغة».
  final VoidCallback? onBrowseCollection;

  /// يخفي تنبيه «السلة الفارغة» لهذه الجلسة.
  final VoidCallback? onDismissEmptyCartNudge;

  @override
  Widget build(BuildContext context) => ListView(
        padding: EdgeInsets.zero,
        children: [
          const Header(),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 8, 22, 18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('دار زخم للعطور', style: TextStyle(color: context.goldText, fontSize: 13, letterSpacing: 1.5)),
              const SizedBox(height: 8),
              Text('هيبة حضور.\nأثر يبقى.', textAlign: TextAlign.right, style: TextStyle(color: context.ink, fontSize: 38, height: 1.2, fontWeight: FontWeight.w300)),
              const SizedBox(height: 10),
              Text('عطور صُنعت لتكون جزءاً من حكايتك،\nوتترك أثراً لا يشبه سواك.', textAlign: TextAlign.right, style: TextStyle(color: context.subdued, fontSize: 14, height: 1.8)),
            ]),
          ),
          HeroBanner(product: product, onTap: () => onProduct(product)),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 13, 20, 0),
            child: Row(children: [
              IconButton(onPressed: onFavorite, tooltip: favorite ? 'إزالة من المفضلة' : 'أضف للمفضلة', icon: Icon(favorite ? Icons.favorite : Icons.favorite_border, color: favorite ? Colors.redAccent : context.goldText)),
              const Spacer(),
              TextButton(onPressed: () => onProduct(product), child: Text('اكتشف زخم رويال', style: TextStyle(color: context.goldText))),
            ]),
          ),
          if (dailyProduct != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: _DailyPerfumeCard(
                product: dailyProduct!,
                onTap: () => onProduct(dailyProduct!),
              ),
            ),
          if (showEmptyCartNudge)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: _EmptyCartNudge(
                onBrowse: onBrowseCollection ?? () {},
                onDismiss: onDismissEmptyCartNudge ?? () {},
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
            child: Row(children: [
              TextButton(onPressed: onQuiz, child: Text('ابدأ الاختبار', style: TextStyle(color: context.goldText))),
              const Spacer(),
              Text('اعثر على عطرك', style: TextStyle(color: context.ink, fontSize: 21, fontWeight: FontWeight.w600)),
            ]),
          ),
          QuizBanner(onTap: onQuiz),
          Padding(padding: const EdgeInsets.fromLTRB(20, 28, 20, 12), child: Text('اختيار زخم', textAlign: TextAlign.right, style: TextStyle(color: context.ink, fontSize: 21, fontWeight: FontWeight.w600))),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: ProductTile(product: product, onTap: () => onProduct(product), favorite: favorite, onFavorite: onFavorite)),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
            child: Row(children: [
              TextButton(onPressed: onOpenSections, child: Text('عرض الكل', style: TextStyle(color: context.goldText))),
              const Spacer(),
              Text('أقسام زخم', style: TextStyle(color: context.ink, fontSize: 21, fontWeight: FontWeight.w600)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.55,
              ),
              itemCount: storeSections.length + 1,
              itemBuilder: (context, index) {
                if (index == storeSections.length) {
                  return _SectionTile(
                    icon: Icons.apps_outlined,
                    title: 'كل الأقسام',
                    detail: 'تصفّح الدار كاملة',
                    onTap: onOpenSections,
                  );
                }
                final section = storeSections[index];
                return _SectionTile(
                  icon: section.icon,
                  title: section.title,
                  detail: section.id == 'collection' ? '11 عطراً' : section.eyebrow,
                  onTap: () => section.id == 'collection'
                      ? onOpenSections()
                      : onSection(section.id),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
            child: Text('خدمات الدار', textAlign: TextAlign.right, style: TextStyle(color: context.ink, fontSize: 21, fontWeight: FontWeight.w600)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GridView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.55,
              ),
              children: [
                _SectionTile(
                  icon: Icons.style_outlined,
                  title: 'البطاقات العطرية',
                  detail: 'المستكشف والرادار',
                  onTap: onFragranceCards,
                ),
                _SectionTile(
                  icon: Icons.verified_outlined,
                  title: 'تحقق من الأصالة',
                  detail: 'رقم الكرت أو QR',
                  onTap: onVerify,
                ),
                _SectionTile(
                  icon: Icons.support_agent_outlined,
                  title: 'استشارة عطرية',
                  detail: 'احجز مكالمة أو واتساب',
                  onTap: onConsultation,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: OccasionsSection(onProduct: onProduct),
          ),
          Padding(padding: const EdgeInsets.fromLTRB(20, 28, 20, 12), child: Text('تجربة تليق بك', textAlign: TextAlign.right, style: TextStyle(color: context.ink, fontSize: 21, fontWeight: FontWeight.w600))),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 26),
            child: Row(children: [
              Expanded(child: _Promise(icon: Icons.local_shipping_outlined, title: 'توصيل لبابك', detail: 'في جميع أنحاء مصر')),
              SizedBox(width: 10),
              Expanded(child: _Promise(icon: Icons.verified_outlined, title: 'أصالة زخم', detail: 'تجربة عطرية موثوقة')),
              SizedBox(width: 10),
              Expanded(child: _Promise(icon: Icons.support_agent, title: 'نحن معك', detail: 'دعم قبل وبعد الطلب')),
            ]),
          ),
        ],
      );
}

class _DailyPerfumeCard extends StatelessWidget {
  const _DailyPerfumeCard({required this.product, required this.onTap});
  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: gold.withOpacity(.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: gold.withOpacity(.35)),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  product.image,
                  width: 56,
                  height: 64,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 56,
                    height: 64,
                    color: const Color(0xFF30271D),
                    child: const Icon(Icons.spa_outlined, color: gold, size: 22),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('عطر اليوم', style: TextStyle(color: context.goldText, fontSize: 12, letterSpacing: 1)),
                    const SizedBox(height: 3),
                    Text(product.name, style: TextStyle(color: context.ink, fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text('يبدأ من ${product.price.toStringAsFixed(0)} ${product.currency}', style: TextStyle(color: context.subdued, fontSize: 12)),
                  ],
                ),
              ),
              TextButton(
                onPressed: onTap,
                child: Text('عرض العطر', style: TextStyle(color: context.goldText)),
              ),
            ]),
          ),
        ),
      );
}

class _EmptyCartNudge extends StatelessWidget {
  const _EmptyCartNudge({required this.onBrowse, required this.onDismiss});
  final VoidCallback onBrowse;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: gold.withOpacity(.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: gold.withOpacity(.35)),
        ),
        child: InkWell(
          onTap: onBrowse,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            child: Row(children: [
              Icon(Icons.shopping_bag_outlined, color: context.goldText, size: 26),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('سلتك فاضية', style: TextStyle(color: context.ink, fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text('تصفح التشكيلة واختر عطرك.', style: TextStyle(color: context.subdued, fontSize: 12)),
                  ],
                ),
              ),
              TextButton(
                onPressed: onBrowse,
                child: Text('تصفح التشكيلة', style: TextStyle(color: context.goldText)),
              ),
              IconButton(
                onPressed: onDismiss,
                icon: Icon(Icons.close, color: context.subdued, size: 18),
                tooltip: 'إخفاء',
                visualDensity: VisualDensity.compact,
              ),
            ]),
          ),
        ),
      );
}

class _SectionTile extends StatelessWidget {
  const _SectionTile({required this.icon, required this.title, required this.detail, required this.onTap});
  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.surfaceCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: context.goldText, size: 24),
              const SizedBox(height: 8),
              Text(title, style: TextStyle(color: context.ink, fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(detail, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.subdued, fontSize: 10)),
            ],
          ),
        ),
      );
}

class _Promise extends StatelessWidget {
  const _Promise({required this.icon, required this.title, required this.detail});
  final IconData icon;
  final String title;
  final String detail;
  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minHeight: 112),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: context.surfaceCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: context.hairline)),
        child: Column(children: [Icon(icon, color: context.goldText), const SizedBox(height: 8), Text(title, textAlign: TextAlign.center, style: TextStyle(color: context.ink, fontSize: 12, fontWeight: FontWeight.w600)), const SizedBox(height: 4), Text(detail, textAlign: TextAlign.center, style: TextStyle(color: context.subdued, fontSize: 10))]),
      );
}
