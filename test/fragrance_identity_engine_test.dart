import 'package:flutter_test/flutter_test.dart';
import 'package:house_of_zakham/data/fragrance_cards.dart';
import 'package:house_of_zakham/models/fragrance_identity.dart';
import 'package:house_of_zakham/models/product.dart';
import 'package:house_of_zakham/services/fragrance_identity_engine.dart';

void main() {
  group('FragranceIdentityEngine', () {
    late List<FragranceCard> cards;
    late List<Product> products;

    setUp(() {
      products = [
        Product(
          id: 'royal',
          name: 'زخم رويال',
          price: 500.0,
          currency: 'EGP',
          size: '100 ml',
          category: 'عطور',
          topNotes: const ['برغموت'],
          heartNotes: const ['ورد'],
          baseNotes: const ['عود'],
          image: 'assets/products/royal-official.webp',
          inStock: true,
          description: 'هوية ملكية.',
          season: 'شتوي',
          occasion: 'formal',
          tags: const ['gender:male'],
          variants: const {
            'presence': {
              'prices': {'30': 250.0, '50': 350.0, '100': 500.0},
            },
            'nuclear': {
              'prices': {'50': 650.0, '100': 950.0},
            },
          },
        ),
        Product(
          id: 'aurora',
          name: 'أورورا',
          price: 500.0,
          currency: 'EGP',
          size: '100 ml',
          category: 'عطور',
          topNotes: const ['ليمون'],
          heartNotes: const ['ياسمين'],
          baseNotes: const ['مسك'],
          image: 'assets/products/aurora.webp',
          inStock: true,
          description: 'انتعاش صباحي.',
          season: 'صيفي',
          occasion: 'fresh',
          tags: const ['gender:female'],
          variants: const {
            'presence': {
              'prices': {'30': 250.0, '50': 350.0, '100': 500.0},
            },
          },
        ),
        Product(
          id: 'musk',
          name: 'المسك',
          price: 500.0,
          currency: 'EGP',
          size: '100 ml',
          category: 'عطور',
          topNotes: const ['مسك'],
          heartNotes: const ['فانيليا'],
          baseNotes: const ['عنبر'],
          image: 'assets/products/musk.webp',
          inStock: true,
          description: 'نعومة يومية.',
          season: 'كل المواسم',
          occasion: 'fresh',
          tags: const ['gender:male'],
          variants: const {
            'presence': {
              'prices': {'30': 250.0, '50': 350.0, '100': 500.0},
            },
          },
        ),
      ];
      cards = products
          .map(
            (p) => FragranceCard(
              extra: FragranceCardExtra(
                code: '',
                tag: '',
                quote: '',
                top: '',
                heart: '',
                base: '',
                stats: const [85, 85, 60, 50, 85],
                wizardCategory: p.occasion,
                wizardType: p.id == 'royal' ? 'wood' : 'floral',
              ),
              product: p,
            ),
          )
          .toList();
    });

    const answers = IdentityAnswers(
      category: 'formal',
      type: 'wood',
      concentration: 'presence',
      sizeMl: 30,
    );

    test('الحتمية: نفس الإجابات تعطي نفس الترتيب دائماً', () {
      final first = FragranceIdentityEngine.rankRecommendations(cards, answers);
      final second =
          FragranceIdentityEngine.rankRecommendations(cards, answers);
      expect(
        second.map((r) => r.card.product.id).toList(),
        first.map((r) => r.card.product.id).toList(),
      );
    });

    test('المطابقة الدقيقة أولاً: رويال (formal + wood) في المقدمة', () {
      final ranked =
          FragranceIdentityEngine.rankRecommendations(cards, answers);
      expect(ranked.first.card.product.id, 'royal');
      // 3 (مناسبة) + 2 (طابع) + 2 (تركيز) + 1 (حجم) = 8.
      expect(ranked.first.score, 8);
    });

    test('مكافأة التركيز والحجم: عطر بلا التركيز المطلوب يتأخر', () {
      const noNuclear = IdentityAnswers(
        category: 'formal',
        type: 'wood',
        concentration: 'nuclear',
        sizeMl: 30,
      );
      final ranked =
          FragranceIdentityEngine.rankRecommendations(cards, noNuclear);
      // رويال يملك nuclear لكن بلا 30 مل: 3 + 2 + 2 + 0 = 7.
      final royal = ranked.firstWhere((r) => r.card.product.id == 'royal');
      expect(royal.score, 7);
      // أورورا والمسك بلا nuclear أصلاً: 0 + 0 + 0 + 0 = 0.
      final others = ranked.where((r) => r.card.product.id != 'royal');
      expect(others.every((r) => r.score == 0), isTrue);
    });

    test('قائمة فارغة: لا ترشيحات ولا استثناء', () {
      final ranked = FragranceIdentityEngine.rankRecommendations(
        const [],
        answers,
      );
      expect(ranked, isEmpty);
    });

    test('فئة غير معروفة: الترشيح يستمر بلا نقاط المناسبة', () {
      const unknown = IdentityAnswers(
        category: 'غير-معروفة',
        type: 'wood',
        concentration: 'presence',
        sizeMl: 50,
      );
      final ranked =
          FragranceIdentityEngine.rankRecommendations(cards, unknown);
      final royal = ranked.firstWhere((r) => r.card.product.id == 'royal');
      // 0 (مناسبة) + 2 (طابع) + 2 (تركيز) + 1 (حجم) = 5.
      expect(royal.score, 5);
    });

    test('الملفات الـ 16 كلها موجودة ولها اسم ووصف', () {
      for (final category in FragranceIdentityEngine.categoryLabels.keys) {
        for (final type in FragranceIdentityEngine.typeLabels.keys) {
          final profile = FragranceIdentityEngine.profileFor(category, type);
          expect(profile.name, isNotEmpty);
          expect(profile.description, isNotEmpty);
        }
      }
    });

    test('الأسباب بلا أي سعر: لا «ج.م» في أسباب الترشيح', () {
      final ranked =
          FragranceIdentityEngine.rankRecommendations(cards, answers);
      for (final recommendation in ranked) {
        for (final reason in recommendation.reasons) {
          expect(reason.contains('ج.م'), isFalse);
        }
      }
    });

    test('أعلى 3 ترشيحات فقط كحد أقصى', () {
      final ranked =
          FragranceIdentityEngine.rankRecommendations(cards, answers);
      expect(ranked.length, lessThanOrEqualTo(3));
      expect(ranked.length, 3);
    });
  });
}
