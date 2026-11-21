import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/store_sections.dart';
import '../models/product.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../widgets/occasions_section.dart';

/// صفحة «الأقسام»: تسرد أقسام الدار الخمسة (التشكيلة، طقس زخم،
/// الإهداء، التغليف الفاخر، باقات التوفير) كما في الموقع الحي،
/// وكل قسم يفتح صفحة تفاصيل بنصوص الموقع الحقيقية.
class SectionsPage extends StatelessWidget {
  const SectionsPage({
    super.key,
    required this.onSection,
    required this.onOpenCollection,
    required this.onFragranceCards,
    required this.onVerify,
    required this.onConsultation,
    required this.onProduct,
  });

  final ValueChanged<String> onSection;
  final VoidCallback onOpenCollection;

  /// يفتح صفحة «البطاقات العطرية».
  final VoidCallback onFragranceCards;

  /// يفتح صفحة «تحقق من الأصالة».
  final VoidCallback onVerify;

  /// يفتح صفحة «حجز استشارة عطرية».
  final VoidCallback onConsultation;

  /// يفتح صفحة عطر (من قسم المناسبات).
  final ValueChanged<Product> onProduct;

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(title: const Text('أقسام زخم')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
            children: [
              Text(
                'تصفّح الدار',
                style: TextStyle(
                  color: context.ink,
                  fontSize: 30,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'كل ما في دار زخم في مكان واحد — من التشكيلة إلى طقس العطر وصندوق الإهداء.',
                style: TextStyle(color: context.subdued, height: 1.7),
              ),
              const SizedBox(height: 20),
              ...storeSections.map(
                (section) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _SectionCard(
                    section: section,
                    onTap: () => section.id == 'collection'
                        ? onOpenCollection()
                        : onSection(section.id),
                  ),
                ),
              ),
              const SectionHeader(title: 'خدمات الدار', horizontal: 0),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ServiceCard(
                  icon: Icons.style_outlined,
                  title: 'البطاقات العطرية',
                  lead:
                      'بطاقات العطور الأحد عشر، والمستكشف الذكي، ورادار يقارن عطرين.',
                  onTap: onFragranceCards,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ServiceCard(
                  icon: Icons.verified_outlined,
                  title: 'تحقق من الأصالة',
                  lead:
                      'تحقق من رقم كرت عطرك أو امسح رمز QR للتأكد أنه أصلي من الدار.',
                  onTap: onVerify,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ServiceCard(
                  icon: Icons.support_agent_outlined,
                  title: 'حجز استشارة عطرية',
                  lead:
                      'اختر اليوم والوقت المفضلين ونوع الاستشارة — مكالمة أو واتساب مع الدار.',
                  onTap: onConsultation,
                ),
              ),
              OccasionsSection(onProduct: onProduct),
            ],
          ),
        ),
      );
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.section, required this.onTap});
  final StoreSection section;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        color: context.surfaceCard,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: context.hairline),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: gold.withOpacity(.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(section.icon, color: context.goldText, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        section.title,
                        style: TextStyle(
                          color: context.ink,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        section.lead,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.subdued,
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.arrow_back_ios_new, size: 15, color: context.goldText),
              ],
            ),
          ),
        ),
      );
}

/// بطاقة خدمة من خدمات الدار (البطاقات العطرية، التحقق من الأصالة)
/// — بنفس شكل بطاقات الأقسام، لكنها تفتح صفحة خدمة لا قسماً.
class _ServiceCard extends StatelessWidget {
  const _ServiceCard({
    required this.icon,
    required this.title,
    required this.lead,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String lead;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        color: context.surfaceCard,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: context.hairline),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: gold.withOpacity(.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: context.goldText, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: context.ink,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        lead,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.subdued,
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.arrow_back_ios_new, size: 15, color: context.goldText),
              ],
            ),
          ),
        ),
      );
}

/// صفحة تفاصيل قسم واحد: عنوانه وفقراته وخطواته وخاتمته من الموقع،
/// مع زر الإجراء (تصفّح التشكيلة أو التواصل عبر واتساب).
class SectionDetailPage extends StatelessWidget {
  const SectionDetailPage({
    super.key,
    required this.sectionId,
    required this.onOpenCollection,
  });

  final String sectionId;
  final VoidCallback onOpenCollection;

  Future<void> _openWhatsApp(BuildContext context, String message) async {
    final uri = Uri.parse(zakhamWhatsAppUrl(message));
    final launched =
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر فتح واتساب على هذا الجهاز.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final section = sectionById(sectionId);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: Text(section.title)),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            Text(
              section.eyebrow,
              style: TextStyle(
                color: context.goldText,
                fontSize: 12,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              section.title,
              style: TextStyle(
                color: context.ink,
                fontSize: 30,
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              section.lead,
              style: TextStyle(
                color: context.subdued,
                fontSize: 15,
                height: 1.9,
              ),
            ),
            if (section.highlightValue.isNotEmpty) ...[
              const SizedBox(height: 22),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: gold.withOpacity(.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: gold.withOpacity(.3)),
                ),
                child: Column(
                  children: [
                    Text(
                      section.highlightValue,
                      style: TextStyle(
                        color: context.goldText,
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      section.highlightLabel,
                      style: TextStyle(color: context.subdued),
                    ),
                  ],
                ),
              ),
            ],
            if (section.features.isNotEmpty) ...[
              const SizedBox(height: 22),
              ...section.features.map(
                (feature) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.check_circle_outline,
                          color: context.goldText, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          feature,
                          style: TextStyle(
                            color: context.ink,
                            fontSize: 14,
                            height: 1.7,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (section.steps.isNotEmpty) ...[
              const SizedBox(height: 22),
              ...section.steps.map(
                (step) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.surfaceCard,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: context.hairline),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              step.number,
                              style: TextStyle(
                                color: context.goldText,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                step.title,
                                style: TextStyle(
                                  color: context.ink,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          step.body,
                          style: TextStyle(
                            color: context.subdued,
                            fontSize: 13,
                            height: 1.8,
                          ),
                        ),
                        if (step.tag.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            step.tag,
                            style: TextStyle(
                              color: context.goldText,
                              fontSize: 11,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
            if (section.closingTitle.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: gold.withOpacity(.3)),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      section.closingTitle,
                      style: TextStyle(
                        color: context.goldText,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      section.closingBody,
                      style: TextStyle(
                        color: context.subdued,
                        height: 1.8,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 26),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: section.ctaKind == SectionCtaKind.collection
                    ? onOpenCollection
                    : () => _openWhatsApp(context, section.whatsappMessage),
                icon: Icon(section.ctaKind == SectionCtaKind.collection
                    ? Icons.grid_view_rounded
                    : Icons.chat_outlined),
                label: Text(section.ctaLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
