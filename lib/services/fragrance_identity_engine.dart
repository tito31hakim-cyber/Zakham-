import '../data/fragrance_cards.dart';
import '../models/fragrance_identity.dart';

/// محرك ترشيح «بصمة زخم» — منطق نقي بلا واجهة وبلا شبكة وبلا أي
/// حالة: يقرأ بطاقات عطرية مدموجة (منتج حي + بيانات البطاقات
/// المحلية، نفس مصدر صفحة «البطاقات العطرية») ويعيد ترشيحات مرتبة
/// ترتيباً حتمياً — نفس الإجابات تعطي نفس الترتيب دائماً.
///
/// قواعد التسجيل (من بيانات حقيقية فقط):
/// - مطابقة المناسبة (wizardCategory): +3.
/// - مطابقة طابع النوتات (wizardType): +2.
/// - توفر التركيز المختار في العطر: +2.
/// - توفر الحجم المختار في ذلك التركيز: +1.
/// - كسر التعادل: مجموع درجات المحاور الخمسة تنازلياً، ثم ترتيب
///   التشكيلة الأصلي — فلا عشوائية ولا اعتماد على وقت أو شبكة.
///
/// المحاور الخمسة للعرض فقط (من `extra.stats`، نفس درجات صفحة
/// البطاقات) وليست مدخلاً في التسجيل؛ ودرجات العطور الثلاثة الجديدة
/// (ليل، إلكسير، سلطان) قيم افتراضية من نصوص المتجر موسومة في
/// `fragrance_cards.dart` بانتظار اعتماد الدار.
class FragranceIdentityEngine {
  const FragranceIdentityEngine._();

  static const int categoryScore = 3;
  static const int typeScore = 2;
  static const int concentrationScore = 2;
  static const int sizeScore = 1;

  /// تسميات المناسبات الأربع للعرض ولأسباب الترشيح.
  static const Map<String, String> categoryLabels = <String, String>{
    'formal': 'مناسبات رسمية',
    'night': 'أمسيات خاصة',
    'fresh': 'استخدام يومي',
    'feminine': 'إطلالة أنثوية',
  };

  /// تسميات طوابع النوتات الأربع للعرض ولأسباب الترشيح.
  static const Map<String, String> typeLabels = <String, String>{
    'wood': 'الأخشاب والعود والجلود',
    'sweet': 'الفانيليا والتونكا والتوباكو',
    'citrus': 'الحمضيات والنوتات المنعشة',
    'floral': 'الزعفران والورود والمسك',
  };

  /// أسماء ملفات الهوية لكل تركيبة (مناسبة × طابع) — صياغة واجهة
  /// للتركيبة المختارة، تُراجع من المالك قبل النشر.
  static const Map<String, IdentityProfile> _profiles =
      <String, IdentityProfile>{
    'formal|wood': IdentityProfile(
      name: 'الهيبة الخشبية',
      description: 'حضور قيادي برائحة أخشاب وعود رصينة تليق بالمحافل.',
    ),
    'formal|sweet': IdentityProfile(
      name: 'الفخامة الدافئة',
      description: 'دفء ملكي من الفانيليا والتونكا لمناسباتك الكبرى.',
    ),
    'formal|citrus': IdentityProfile(
      name: 'الأناقة المنعشة',
      description: 'رسمية مشرقة بنوتات حمضية نظيفة لا تفقد هيبتها.',
    ),
    'formal|floral': IdentityProfile(
      name: 'الرقي الملكي',
      description: 'زعفران وورود ملكية بإطلالة رسمية راقية.',
    ),
    'night|wood': IdentityProfile(
      name: 'الغموض الليلي',
      description: 'عود وأخشاب داكنة لأمسية لا تُنسى.',
    ),
    'night|sweet': IdentityProfile(
      name: 'الدفء الليلي',
      description: 'توباكو وفانيليا دافئة للياليك الخاصة.',
    ),
    'night|citrus': IdentityProfile(
      name: 'السهرة المنعشة',
      description: 'انتعاش خفيف يضيء السهرة دون أن يثقلها.',
    ),
    'night|floral': IdentityProfile(
      name: 'السحر الليلي',
      description: 'ورود ومسك بسحر هادئ في المساء.',
    ),
    'fresh|wood': IdentityProfile(
      name: 'الانتعاش الرصين',
      description: 'أخشاب نظيفة ليومك — حضور هادئ وواثق.',
    ),
    'fresh|sweet': IdentityProfile(
      name: 'الحلاوة اليومية',
      description: 'لمسة حلوة دافئة ترافقك كل يوم.',
    ),
    'fresh|citrus': IdentityProfile(
      name: 'الانتعاش النهاري',
      description: 'حمضيات ونوتات منعشة لنهار خفيف وحيوي.',
    ),
    'fresh|floral': IdentityProfile(
      name: 'النعومة اليومية',
      description: 'زهور ومسك بنعومة راقية كل يوم.',
    ),
    'feminine|wood': IdentityProfile(
      name: 'الأنوثة الرصينة',
      description: 'أخشاب ناعمة بإطلالة أنثوية واثقة.',
    ),
    'feminine|sweet': IdentityProfile(
      name: 'الأنوثة الدافئة',
      description: 'فانيليا دافئة بإطلالة أنثوية رزينة.',
    ),
    'feminine|citrus': IdentityProfile(
      name: 'الإشراقة الأنثوية',
      description: 'انتعاش مشرق يليق بإطلالتك.',
    ),
    'feminine|floral': IdentityProfile(
      name: 'الأنوثة الملكية',
      description: 'زعفران وورود ملكية لإطلالة أنثوية راقية جداً.',
    ),
  };

  /// ملف الهوية لتركيبة الإجابات؛ وإن لم تُوجد تركيبة (لا يحدث مع
  /// الخيارات الأربعة المعتمدة) يُعاد ملف عام.
  static IdentityProfile profileFor(String category, String type) {
    return _profiles['$category|$type'] ??
        const IdentityProfile(
          name: 'بصمة زخم',
          description: 'هويتك العطرية من تشكيلة دار زخم.',
        );
  }

  /// نقاط مطابقة بطاقة واحدة مع الإجابات.
  static int scoreCard(FragranceCard card, IdentityAnswers answers) {
    var score = 0;
    if (card.extra.wizardCategory == answers.category) {
      score += categoryScore;
    }
    if (card.extra.wizardType == answers.type) {
      score += typeScore;
    }
    final product = card.product;
    if (product.availableConcentrations.contains(answers.concentration)) {
      score += concentrationScore;
      if (product.availableSizes(answers.concentration).contains(answers.sizeMl)) {
        score += sizeScore;
      }
    }
    return score;
  }

  /// أسباب الترشيح — من المطابقات الحقيقية فقط، بصياغة ثابتة.
  static List<String> reasonsFor(
    FragranceCard card,
    IdentityAnswers answers,
  ) {
    final reasons = <String>[];
    final categoryLabel = categoryLabels[answers.category];
    if (card.extra.wizardCategory == answers.category && categoryLabel != null) {
      reasons.add('يطابق مناسبتك: $categoryLabel.');
    }
    final typeLabel = typeLabels[answers.type];
    if (card.extra.wizardType == answers.type && typeLabel != null) {
      reasons.add('طابعك المفضل: $typeLabel.');
    }
    final product = card.product;
    if (product.availableConcentrations.contains(answers.concentration)) {
      reasons.add(
        'متوفر بتركيز ${product.concentrationLabel(answers.concentration)}.',
      );
      if (product.availableSizes(answers.concentration).contains(answers.sizeMl)) {
        reasons.add('متوفر بحجم ${answers.sizeMl} مل.');
      }
    }
    if (reasons.isEmpty) {
      reasons.add('من تشكيلة دار زخم المعتمدة.');
    }
    return reasons;
  }

  /// يرتب البطاقات حسب النقاط (تنازلياً)، ثم مجموع درجات المحاور
  /// (تنازلياً)، ثم ترتيب التشكيلة الأصلي — ويعيد أول ثلاثة.
  /// قائمة فارغة تعيد قائمة فارغة (بلا استثناء وبلا افتراض).
  static List<IdentityRecommendation> rankRecommendations(
    List<FragranceCard> cards,
    IdentityAnswers answers,
  ) {
    final scored = <_ScoredCard>[];
    for (var index = 0; index < cards.length; index++) {
      final card = cards[index];
      scored.add(
        _ScoredCard(
          card: card,
          score: scoreCard(card, answers),
          statsSum: card.extra.stats.fold<int>(0, (sum, value) => sum + value),
          index: index,
        ),
      );
    }
    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      final byStats = b.statsSum.compareTo(a.statsSum);
      if (byStats != 0) return byStats;
      return a.index.compareTo(b.index);
    });
    return scored.take(3).map((entry) {
      return IdentityRecommendation(
        card: entry.card,
        score: entry.score,
        reasons: reasonsFor(entry.card, answers),
      );
    }).toList(growable: false);
  }
}

class _ScoredCard {
  const _ScoredCard({
    required this.card,
    required this.score,
    required this.statsSum,
    required this.index,
  });

  final FragranceCard card;
  final int score;
  final int statsSum;
  final int index;
}
