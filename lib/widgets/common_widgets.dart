import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';

class Header extends StatelessWidget {
  const Header({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      child: Stack(
        children: [
          SizedBox(
            height: 112,
            width: double.infinity,
            child: Image.asset(
              'assets/brand/zakham-house-logo.png',
              fit: BoxFit.contain,
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            child: IconButton(
              onPressed: theme.toggle,
              tooltip: theme.isLight ? 'الواجهة الداكنة' : 'الواجهة الفاتحة',
              icon: Icon(
                theme.isLight ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                color: context.goldText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// بطاقة هوية المتجر — تظهر فور فتح التطبيق لتقول للعميل إن هذا
/// هو متجر دار زخم الإلكتروني الرسمي: علامة الدار + الاسم + شارة
/// «المتجر الإلكتروني الرسمي» + سطر تعريفي قصير. بلا أي بنرات عروض.
class StoreIdentityCard extends StatelessWidget {
  const StoreIdentityCard({super.key});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(20, 6, 20, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.surfaceCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: gold.withOpacity(.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'assets/brand/zakham-brand-mark.png',
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 52,
                      height: 52,
                      color: const Color(0xFF17130B),
                      child: const Icon(
                        Icons.spa_outlined,
                        color: gold,
                        size: 26,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'متجر دار زخم',
                        style: TextStyle(
                          color: context.ink,
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: gold.withOpacity(.16),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: gold.withOpacity(.4)),
                        ),
                        child: Text(
                          'المتجر الإلكتروني الرسمي',
                          style: TextStyle(
                            color: context.goldText,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'متجر زخم الإلكتروني — التشكيلة الكاملة، حسابك، طلباتك، وتتبع الشحنات.',
              style: TextStyle(
                color: context.subdued,
                fontSize: 13,
                height: 1.8,
              ),
            ),
          ],
        ),
      );
}

/// عنوان قسم موحّد في الرئيسية: العنوان يميناً (عربي) وزر نصي
/// اختياري يساراً، ونفس الهوامش في كل الأقسام (20 أفقي، 28 أعلى،
/// 12 أسفل). يوحّد عناوين «أقسام زخم» و«خدمات الدار» و«عطر اليوم»
/// و«اختيار زخم» و«تجربة تليق بك» و«مناسبات قادمة».
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.horizontal = 20,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// الهامش الأفقي (20 في الرئيسية؛ 0 داخل قسم المناسبات لأنه
  /// يضيف الهامش بنفسه).
  final double horizontal;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(horizontal, 28, horizontal, 12),
        child: Row(
          children: [
            Text(
              title,
              style: TextStyle(
                color: context.ink,
                fontSize: 21,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            if (actionLabel != null)
              TextButton(
                onPressed: onAction,
                child: Text(
                  actionLabel!,
                  style: TextStyle(color: context.goldText),
                ),
              ),
          ],
        ),
      );
}

/// عنوان مجموعة في صفحة الحساب: شريط ذهبي + عنوان + فاصل خفيف.
/// يوحّد عناوين المجموعات (حسابي، الولاء والمكافآت، التذكيرات،
/// روابط سريعة، الإعدادات).
class AccountGroupHeader extends StatelessWidget {
  const AccountGroupHeader({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 28, 22, 10),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 20,
              decoration: BoxDecoration(
                color: gold,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: TextStyle(
                color: context.ink,
                fontSize: 19,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Divider(color: context.hairline, height: 1)),
          ],
        ),
      );
}

class HeroBanner extends StatelessWidget {
  const HeroBanner({super.key, required this.product, required this.onTap});
  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          height: 280,
          margin: const EdgeInsets.symmetric(horizontal: 20),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(20)),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                product.image,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(color: const Color(0xFF32261E)),
              ),
              // النص فوق الصورة والتدرج الأسود — يبقى بألوانه الداكنة
              // الثابتة في الوضعين، لأن خلفيته صورة داكنة دائماً.
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black],
                  ),
                ),
              ),
              Positioned(
                right: 20,
                bottom: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('التشكيلة الرسمية', style: TextStyle(color: gold)),
                    Text(
                      product.name,
                      style: const TextStyle(color: cream, fontSize: 28),
                    ),
                    const Text('اكتشف العطر', style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class QuizBanner extends StatelessWidget {
  const QuizBanner({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: context.surfaceCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: gold.withOpacity(.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.auto_awesome, color: context.goldText, size: 34),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('ثلاثة أسئلة فقط', style: TextStyle(color: context.goldText, fontSize: 12)),
                    Text(
                      'اكتشف الرائحة الأقرب لك',
                      style: TextStyle(color: context.ink, fontSize: 17, fontWeight: FontWeight.w600),
                    ),
                    Text('نرشح لك عطراً يليق بذوقك', style: TextStyle(color: context.subdued, fontSize: 12)),
                  ],
                ),
              ),
              Icon(Icons.arrow_back_ios_new, size: 16, color: context.goldText),
            ],
          ),
        ),
      );
}

class ProductTile extends StatelessWidget {
  const ProductTile({
    super.key,
    required this.product,
    required this.onTap,
    required this.favorite,
    required this.onFavorite,
  });

  final Product product;
  final VoidCallback onTap;
  final bool favorite;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          height: 190,
          decoration: BoxDecoration(color: context.surfaceCard, borderRadius: BorderRadius.circular(20)),
          child: Row(
            children: [
              IconButton(
                onPressed: onFavorite,
                icon: Icon(
                  favorite ? Icons.favorite : Icons.favorite_border,
                  color: favorite ? Colors.redAccent : context.goldText,
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        product.name,
                        style: TextStyle(color: context.ink, fontSize: 19, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        product.categoryLabel.isEmpty
                            ? product.category.toUpperCase()
                            : product.categoryLabel,
                        style: TextStyle(color: context.goldText, fontSize: 10, letterSpacing: 1.5),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'عطر بحضور يترك أثراً.',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: TextStyle(color: context.subdued, fontSize: 12, height: 1.4),
                      ),
                      const Spacer(),
                      Text(
                        '${product.price.toStringAsFixed(0)} ${product.currency}',
                        style: TextStyle(color: context.goldText, fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
              ClipRRect(
                borderRadius: const BorderRadius.horizontal(right: Radius.circular(20)),
                child: Image.network(
                  product.image,
                  width: 120,
                  height: 190,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(width: 120, height: 190, color: const Color(0xFF32261E)),
                ),
              ),
            ],
          ),
        ),
      );
}

class ApiProductCard extends StatelessWidget {
  const ApiProductCard({
    super.key,
    required this.product,
    required this.onTap,
    this.favorite = false,
    this.onFavorite,
  });
  final Product product;
  final VoidCallback onTap;
  final bool favorite;
  final VoidCallback? onFavorite;

  @override
  Widget build(BuildContext context) => Card(
        color: context.surfaceCard,
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: ListTile(
          onTap: onTap,
          leading: Image.network(
            product.image,
            width: 48,
            height: 48,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Icon(Icons.image_outlined, color: context.goldText),
          ),
          title: Text(product.name, textAlign: TextAlign.right, style: TextStyle(color: context.ink)),
          subtitle: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'يبدأ من ${product.lowestPrice.toStringAsFixed(0)} ج.م',
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: context.goldText,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                product.availableConcentrations
                    .map(product.concentrationLabel)
                    .join(' • '),
                textAlign: TextAlign.right,
                style: TextStyle(color: context.subdued, fontSize: 11),
              ),
            ],
          ),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            if (onFavorite != null)
              IconButton(
                onPressed: onFavorite,
                tooltip: favorite ? 'إزالة من المفضلة' : 'أضف للمفضلة',
                icon: Icon(
                  favorite ? Icons.favorite : Icons.favorite_border,
                  color: favorite ? Colors.redAccent : context.goldText,
                  size: 20,
                ),
              ),
            Icon(
              product.inStock ? Icons.check_circle_outline : Icons.remove_circle_outline,
              color: product.inStock ? Colors.green : Colors.redAccent,
            ),
          ]),
        ),
      );
}

class NoteCard extends StatelessWidget {
  const NoteCard({super.key, required this.title, required this.notes});
  final String title;
  final List<String> notes;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: context.hairline),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(Icons.circle, color: context.goldText, size: 8),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                notes.isEmpty ? 'لا توجد بيانات بعد' : notes.join('، '),
                style: TextStyle(color: context.subdued, fontSize: 12),
              ),
            ),
            Text(title, style: TextStyle(color: context.ink, fontWeight: FontWeight.w600)),
          ],
        ),
      );
}
