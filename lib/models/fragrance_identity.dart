import '../data/fragrance_cards.dart';

/// إجابات أداة «بصمة زخم» الأربع — كلها قيم من بيانات التطبيق نفسه:
/// المناسبة وطابع النوتات من أسئلة المستكشف (wizardQuestions)،
/// والتركيز والحجم من تركيزات وأحجام المتجر الحي.
class IdentityAnswers {
  const IdentityAnswers({
    required this.category,
    required this.type,
    required this.concentration,
    required this.sizeMl,
  });

  /// المناسبة: formal | night | fresh | feminine.
  final String category;

  /// طابع النوتات: wood | sweet | citrus | floral.
  final String type;

  /// التركيز: presence | extra | nuclear.
  final String concentration;

  /// الحجم بالمل: 30 | 50 | 100.
  final int sizeMl;
}

/// ترشيح واحد: بطاقة عطرية + نقاط المطابقة + أسباب مبنية على بيانات
/// حقيقية فقط (المناسبة، الطابع، توفر التركيز والحجم) — بلا أي
/// تقييم أو سعر مخترع.
class IdentityRecommendation {
  const IdentityRecommendation({
    required this.card,
    required this.score,
    required this.reasons,
  });

  final FragranceCard card;
  final int score;
  final List<String> reasons;
}

/// ملف الهوية العطرية الناتج: اسم يجمع المناسبة والطابع + وصف.
/// الأسماء صياغة واجهة للتركيبة المختارة (وليست بيانات عن العطور)،
/// وتُراجع من المالك قبل النشر.
class IdentityProfile {
  const IdentityProfile({required this.name, required this.description});

  final String name;
  final String description;
}
