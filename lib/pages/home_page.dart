import 'package:flutter/material.dart';
import '../data/featured_product.dart';
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
    required this.onFragranceIdentity,
    required this.favorite,
    required this.onFavorite,
    required this.onSection,
    required this.onOpenSections,
    required this.onFragranceCards,
    required this.onVerify,
    required this.onConsultation,
    this.pickProduct = featuredProduct,
    this.pickFavorite,
    this.onPickFavorite,
    this.isDailyPerfume = false,
    this.showEmptyCartNudge = false,
    this.onBrowseCollection,
    this.onDismissEmptyCartNudge,
  });
  final Product product;
  final ValueChanged<Product> onProduct;
  final VoidCallback onQuiz;

  /// عطر «اختيار زخم» — مختلف عن عطر اليوم (سلطان أولاً، يختاره
  /// الغلاف) ليرى العميل تشكيلة أوسع بمجرد التمرير؛ الافتراضي رويال
  /// (نفس احتياطي البطل) قبل تحميل التشكيلة.
  final Product pickProduct;

  /// يفتح أداة «بصمة زخم: دليلك للهوية العطرية».
  final VoidCallback onFragranceIdentity;

  final bool favorite;
  final VoidCallback onFavorite;

  /// حالة المفضلة لعطر «اختيار زخم» (تتبع `favorite`/`onFavorite`
  /// عند غيابها — كما في الاختبارات القديمة).
  final bool? pickFavorite;
  final VoidCallback? onPickFavorite;

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

  /// البطاقة العلوية هي عطر اليوم (دوران يومي حتمي — نفس العطر لكل
  /// المستخدمين في اليوم نفسه) فتظهر شارة «عطر اليوم» فوق صورتها؛
  /// ورويال احتياطي قبل تحميل التشكيلة فيُعرض بلا شارة.
  final bool isDailyPerfume;

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
          // 1 — الهوية والمتجر: هذا هو متجر دار زخم
          // الإلكتروني الرسمي — لا مجرد أداة.
          const StoreIdentityCard(),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('هيبة حضور.\nأثر يبقى.', textAlign: TextAlign.right, style: TextStyle(color: context.ink, fontSize: 38, height: 1.2, fontWeight: FontWeight.w300)),
              const SizedBox(height: 10),
              Text('عطور صُنعت لتكون جزءاً من حكايتك،\nوتترك أثراً لا يشبه سواك.', textAlign: TextAlign.right, style: TextStyle(color: context.subdued, fontSize: 14, height: 1.8)),
            ]),
          ),
          // 2 — عطر اليوم وأدوات الترشيح (الاختبار + بصمة زخم).
          HeroBanner(
            product: product,
            onTap: () => onProduct(product),
            badge: isDailyPerfume ? 'عطر اليوم' : null,
          ),
          // زر المفضلة لعطر اليوم فقط — رابط «اكتشف ...» حُذف لأنه
          // يكرر نص البطاقة نفسها («اكتشف العطر»)، والبطاقة قابلة
          // للضغط للدخول.
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 13, 20, 0),
            child: Row(children: [
              IconButton(onPressed: onFavorite, tooltip: favorite ? 'إزالة من المفضلة' : 'أضف للمفضلة', icon: Icon(favorite ? Icons.favorite : Icons.favorite_border, color: favorite ? Colors.redAccent : context.goldText)),
            ]),
          ),
          SectionHeader(title: 'اعثر على عطرك', actionLabel: 'ابدأ الاختبار', onAction: onQuiz),
          QuizBanner(onTap: onQuiz),
          const SizedBox(height: 12),
          _IdentityEntryCard(onTap: onFragranceIdentity),
          if (showEmptyCartNudge)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: _EmptyCartNudge(
                onBrowse: onBrowseCollection ?? () {},
                onDismiss: onDismissEmptyCartNudge ?? () {},
              ),
            ),
          // 3 — أقسام زخم و«اختيار زخم».
          SectionHeader(title: 'أقسام زخم', actionLabel: 'عرض الكل', onAction: onOpenSections),
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
                  detail: section.tileDetail,
                  onTap: () => section.id == 'collection'
                      ? onOpenSections()
                      : onSection(section.id),
                );
              },
            ),
          ),
          const SectionHeader(title: 'اختيار زخم'),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: ProductTile(product: pickProduct, onTap: () => onProduct(pickProduct), favorite: pickFavorite ?? favorite, onFavorite: onPickFavorite ?? onFavorite)),
          const SectionHeader(title: 'خدمات الدار'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              // stretch حتى تملأ بطاقة «استشارة عطرية» عرض الصف كاملاً:
              // بلا stretch تنكمش البطاقة على محتواها (236px بدل 760).
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 116,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _SectionTile(
                          icon: Icons.style_outlined,
                          title: 'البطاقات العطرية',
                          detail: 'المستكشف والرادار',
                          onTap: onFragranceCards,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _SectionTile(
                          icon: Icons.verified_outlined,
                          title: 'تحقق من الأصالة',
                          detail: 'رقم الكرت أو QR',
                          onTap: onVerify,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                // «استشارة عطرية» بعرض الصف الكامل حتى لا تبقى بطاقة
                // منفردة في صف ثانٍ بمساحة فارغة بجانبها.
                SizedBox(
                  height: 116,
                  child: _SectionTile(
                    icon: Icons.support_agent_outlined,
                    title: 'استشارة عطرية',
                    detail: 'احجز مكالمة أو واتساب',
                    onTap: onConsultation,
                  ),
                ),
              ],
            ),
          ),
          // 4 — المناسبات الموسمية.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: OccasionsSection(onProduct: onProduct),
          ),
          // 5 — «تجربة تليق بك».
          const SectionHeader(title: 'تجربة تليق بك'),
          const Padding(
            // حشو سفلي 96 يُخلي العناصر الأخيرة من زر «مساعد دار
            // زخم» العائم (نفس حشو التشكيلة).
            padding: EdgeInsets.fromLTRB(20, 0, 20, 96),
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

class _EmptyCartNudge extends StatelessWidget {
  const _EmptyCartNudge({required this.onBrowse, required this.onDismiss});
  final VoidCallback onBrowse;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: gold.withOpacity(.10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: gold.withOpacity(.35)),
        ),
        child: InkWell(
          onTap: onBrowse,
          borderRadius: BorderRadius.circular(20),
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

class _IdentityEntryCard extends StatelessWidget {
  const _IdentityEntryCard({required this.onTap});
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
              Icon(Icons.fingerprint, color: context.goldText, size: 34),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('تحليل بصمتك العطرية الكاملة', style: TextStyle(color: context.goldText, fontSize: 12)),
                    Text(
                      'بصمة زخم: دليلك للهوية العطرية',
                      style: TextStyle(color: context.ink, fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'اكتشف هويتك العطرية من تشكيلة الدار',
                      style: TextStyle(color: context.subdued, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_back_ios_new,
                color: context.goldText,
                size: 15,
              ),
            ],
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
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.surfaceCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: gold.withOpacity(.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: context.goldText, size: 22),
              ),
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
        decoration: BoxDecoration(color: context.surfaceCard, borderRadius: BorderRadius.circular(20), border: Border.all(color: context.hairline)),
        child: Column(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: gold.withOpacity(.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: context.goldText, size: 22),
          ),
          const SizedBox(height: 8),
          Text(title, textAlign: TextAlign.center, style: TextStyle(color: context.ink, fontSize: 12, fontWeight: FontWeight.w600)), const SizedBox(height: 4), Text(detail, textAlign: TextAlign.center, style: TextStyle(color: context.subdued, fontSize: 10))]),
      );
}
