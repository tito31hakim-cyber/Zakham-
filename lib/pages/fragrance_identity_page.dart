import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/fragrance_cards.dart';
import '../models/fragrance_identity.dart';
import '../models/product.dart';
import '../providers/cart_provider.dart';
import '../services/fragrance_identity_engine.dart';
import '../services/product_catalog.dart';
import '../theme/app_theme.dart';
import '../widgets/identity_result_card.dart';

/// «بصمة زخم: دليلك للهوية العطرية» — تدفق من 4 خطوات ثم شاشة نتيجة.
///
/// الخطوات: المناسبة ونمط الاستخدام، تفضيل النوتات، التركيز، الحجم.
/// أسئلة الخطوتين الأولى والثانية هي أسئلة المستكشف نفسها
/// (wizardQuestions) بنصوصها وخياراتها؛ والترشيح من محرك
/// `FragranceIdentityEngine` على البطاقات المدموجة (منتج حي +
/// بيانات البطاقات المحلية)، ويعمل بلا نت من النسخة المحفوظة.
///
/// بلا أي أسعار محسوبة داخل الأداة: سعر التركيز والحجم المختارين
/// يُقرأ من بيانات المتجر الحية فقط (`priceFor`)، والحساب النهائي
/// للطلب والخصم والنقاط من جهة الخادم.
class FragranceIdentityPage extends StatefulWidget {
  const FragranceIdentityPage({
    super.key,
    this.initialCards,
    required this.onProduct,
    required this.onConsultation,
    required this.onOpenChat,
  });

  /// بطاقات جاهزة — تُمرَّر في الاختبارات فقط لتفادي الشبكة؛ وفي
  /// الإنتاج تُحمَّل من الكتالوج (شبكة أو نسخة محفوظة).
  final List<FragranceCard>? initialCards;

  /// يفتح صفحة عطر.
  final ValueChanged<Product> onProduct;

  /// يفتح صفحة حجز استشارة عطرية.
  final VoidCallback onConsultation;

  /// يفتح «مساعد دار زخم».
  final VoidCallback onOpenChat;

  /// نصوص الثقة الثابتة في شاشة النتيجة — موثقة فقط، بلا حساب أسعار.
  static const List<String> trustLines = <String>[
    'الدفع مسبقاً عبر إنستاباي أو فودافون كاش.',
    'الشحن 120 ج.م لجميع المحافظات خلال 4–7 أيام عمل.',
    'الاستبدال خلال يومين للمنتج غير المستخدم المبرشم.',
    'نقاط الولاء وهدية عيد الميلاد تُحتسب من جهة الخادم عند الطلب.',
  ];

  @override
  State<FragranceIdentityPage> createState() => _FragranceIdentityPageState();
}

class _FragranceIdentityPageState extends State<FragranceIdentityPage> {
  final ProductCatalog _catalog = ProductCatalog();
  List<FragranceCard> _cards = <FragranceCard>[];
  bool _loading = true;
  bool _fromCache = false;
  String? _error;
  bool _retrying = false;

  int _step = 0;
  String? _category;
  String? _type;
  String? _concentration;
  int? _sizeMl;

  @override
  void initState() {
    super.initState();
    if (widget.initialCards != null) {
      _cards = widget.initialCards!;
      _loading = false;
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final result = await _catalog.fetchCatalog();
      if (!mounted) return;
      setState(() {
        _cards = mergeFragranceCards(result.products);
        _fromCache = result.fromCache;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذر تحميل التشكيلة الآن.';
      });
    }
  }

  Future<void> _retry() async {
    if (_retrying) return;
    setState(() {
      _retrying = true;
      _loading = true;
      _error = null;
    });
    await _load();
    if (mounted) setState(() => _retrying = false);
  }

  void _choose(String value) {
    switch (_step) {
      case 0:
        setState(() {
          _category = value;
          _step = 1;
        });
        break;
      case 1:
        setState(() {
          _type = value;
          _step = 2;
        });
        break;
      case 2:
        setState(() {
          _concentration = value;
          if (_sizeMl == 30 && value == 'nuclear') _sizeMl = null;
          _step = 3;
        });
        break;
      case 3:
        final size = int.tryParse(value);
        if (size == null) return;
        setState(() {
          _sizeMl = size;
          _step = 4;
        });
        break;
    }
  }

  void _back() {
    if (_step > 0) setState(() => _step--);
  }

  void _restart() {
    setState(() {
      _step = 0;
      _category = null;
      _type = null;
      _concentration = null;
      _sizeMl = null;
    });
  }

  void _addToCart(Product product) {
    if (_concentration == null || _sizeMl == null) return;
    context.read<CartProvider>().add(
          product,
          concentration: _concentration,
          sizeMl: _sizeMl,
        );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('أُضيف ${product.name} إلى السلة.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('بصمة زخم')),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _ErrorView(message: _error!, onRetry: _retry)
                : _step < 4
                    ? _StepView(
                        step: _step,
                        concentration: _concentration,
                        onChoose: _choose,
                        onBack: _step > 0 ? _back : null,
                      )
                    : _ResultView(
                        cards: _cards,
                        answers: IdentityAnswers(
                          category: _category ?? 'fresh',
                          type: _type ?? 'floral',
                          concentration: _concentration ?? 'presence',
                          sizeMl: _sizeMl ?? 50,
                        ),
                        fromCache: _fromCache,
                        onProduct: widget.onProduct,
                        onConsultation: widget.onConsultation,
                        onOpenChat: widget.onOpenChat,
                        onAddToCart: _addToCart,
                        onRestart: _restart,
                      ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: context.ink, fontSize: 16, height: 1.7),
              ),
              const SizedBox(height: 16),
              FilledButton(onPressed: onRetry, child: const Text('إعادة المحاولة')),
            ],
          ),
        ),
      );
}

class _StepView extends StatelessWidget {
  const _StepView({
    required this.step,
    required this.concentration,
    required this.onChoose,
    this.onBack,
  });

  final int step;
  final String? concentration;
  final ValueChanged<String> onChoose;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final String title;
    final List<(String, String)> options;
    if (step == 0) {
      final question = wizardQuestions[0];
      title = question.title;
      options = question.options
          .map((option) => (option.value, option.label))
          .toList(growable: false);
    } else if (step == 1) {
      final question = wizardQuestions[1];
      title = question.title;
      options = question.options
          .map((option) => (option.value, option.label))
          .toList(growable: false);
    } else if (step == 2) {
      title = 'ما التركيز الذي تفضله؟';
      options = Product.concentrationOrder.map((key) {
        final ar = Product.concentrationNamesAr[key] ?? key;
        final en = Product.concentrationNamesEn[key] ?? '';
        return (key, '$ar · $en');
      }).toList(growable: false);
    } else {
      title = 'ما الحجم المناسب لك؟';
      options = const <(String, String)>[
        ('30', '30 مل'),
        ('50', '50 مل'),
        ('100', '100 مل'),
      ];
    }
    return Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '0${step + 1} / 04',
            style: TextStyle(color: context.goldText),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (step + 1) / 4,
              minHeight: 5,
              color: context.goldText,
              backgroundColor: context.hairline,
            ),
          ),
          const SizedBox(height: 28),
          Text(
            title,
            style: TextStyle(
              color: context.ink,
              fontSize: 27,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (step == 2) ...[
            const SizedBox(height: 10),
            Text(
              'النووي (Extrait Max) متوفر بحجمي 50 و100 مل فقط.',
              style: TextStyle(color: context.subdued, fontSize: 14, height: 1.6),
            ),
          ],
          const SizedBox(height: 25),
          ...options.map((option) {
            final disabled =
                step == 3 && option.$1 == '30' && concentration == 'nuclear';
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed:
                      disabled ? null : () => onChoose(option.$1),
                  child: Text(
                    option.$2,
                    style: TextStyle(color: context.ink),
                  ),
                ),
              ),
            );
          }),
          if (onBack != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: onBack, child: const Text('رجوع')),
            ),
        ],
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({
    required this.cards,
    required this.answers,
    required this.fromCache,
    required this.onProduct,
    required this.onConsultation,
    required this.onOpenChat,
    required this.onAddToCart,
    required this.onRestart,
  });

  final List<FragranceCard> cards;
  final IdentityAnswers answers;
  final bool fromCache;
  final ValueChanged<Product> onProduct;
  final VoidCallback onConsultation;
  final VoidCallback onOpenChat;
  final ValueChanged<Product> onAddToCart;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final profile = FragranceIdentityEngine.profileFor(
      answers.category,
      answers.type,
    );
    final recommendations =
        FragranceIdentityEngine.rankRecommendations(cards, answers);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      children: [
        if (fromCache)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'نسخة محفوظة — تُعرض بيانات آخر تشكيلة محفوظة بلا نت.',
              style: TextStyle(color: context.subdued, fontSize: 12),
            ),
          ),
        Text(
          'بصمتك العطرية',
          style: TextStyle(color: context.goldText, fontSize: 14),
        ),
        const SizedBox(height: 6),
        Text(
          profile.name,
          style: TextStyle(
            color: context.ink,
            fontSize: 30,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          profile.description,
          style: TextStyle(color: context.subdued, fontSize: 15, height: 1.7),
        ),
        const SizedBox(height: 22),
        if (recommendations.isEmpty)
          Text(
            'لا توجد عطور مطابقة حالياً — جرّب التشكيلة كاملة.',
            style: TextStyle(color: context.ink, fontSize: 16, height: 1.7),
          )
        else
          ...recommendations.asMap().entries.map((entry) {
            final index = entry.key;
            final recommendation = entry.value;
            final product = recommendation.card.product;
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: IdentityResultCard(
                recommendation: recommendation,
                concentration: answers.concentration,
                sizeMl: answers.sizeMl,
                price: product.priceFor(
                  concentration: answers.concentration,
                  sizeMl: answers.sizeMl,
                ),
                rank: index,
                onViewProduct: () => onProduct(product),
                onAddToCart: () => onAddToCart(product),
              ),
            );
          }),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onConsultation,
                child: const Text('احجز استشارة عطرية'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: onOpenChat,
                child: const Text('اسأل مساعد دار زخم'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        Text(
          'ثقة وشفافية',
          style: TextStyle(
            color: context.ink,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        ...FragranceIdentityPage.trustLines.map(
          (line) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• ', style: TextStyle(color: context.goldText)),
                Expanded(
                  child: Text(
                    line,
                    style: TextStyle(color: context.subdued, fontSize: 14, height: 1.7),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'الحساب النهائي للطلب والخصم والنقاط من جهة الخادم.',
          style: TextStyle(color: context.subdued, fontSize: 12, height: 1.6),
        ),
        const SizedBox(height: 18),
        Center(
          child: TextButton(onPressed: onRestart, child: const Text('أعد الاختبار')),
        ),
      ],
    );
  }
}
