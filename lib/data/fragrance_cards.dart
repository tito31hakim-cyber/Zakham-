import '../models/product.dart';

/// بيانات البطاقات العطرية — من صفحة الموقع
/// `https://zakhamhouse.shop/fragrance-cards/` (المصفوفة الثابتة
/// `FALLBACK_PERFUMES` فيها) مدموجة مع بيانات المتجر الحية
/// (`/api/storefront`).
///
/// القاعدة نفسها في الموقع: العطر الحي (الاسم، الصورة، السعر، الهرم)
/// من المتجر، والاقتباس ودرجات الرادار وتصنيف المستكشف من بيانات
/// محلية للعطور الثمانية المكتوبة في الكتالوج. للعطور الثلاثة الجديدة
/// (ليل، إلكسير، سلطان) قيم افتراضية من نصوص المتجر نفسها (الموسم
/// والمناسبة والنوتات كما يردها `/api/storefront`)، موسومة بتعليق
/// `افتراضي` حتى تُستبدل بنصوص من الدار إن أرادت.
class FragranceCardExtra {
  const FragranceCardExtra({
    required this.code,
    required this.tag,
    required this.quote,
    required this.top,
    required this.heart,
    required this.base,
    required this.stats,
    required this.wizardCategory,
    required this.wizardType,
  });

  /// كود الكتالوج (ZH-01..ZH-08) — فارغ للعطور الجديدة بلا أكواد.
  final String code;

  /// الوسم الظاهر على البطاقة (مثل «مناسبات رسمية»).
  final String tag;

  /// اقتباس العطر.
  final String quote;

  /// الهرم العطري كنصوص نثرية (من الكتالوج).
  final String top;
  final String heart;
  final String base;

  /// درجات الرادار الخمس: [الثبات، الفوحان، الدفء، الانتعاش، الهيبة].
  final List<int> stats;

  /// تصنيف المستكشف الذكي (نفس منطق صفحة الموقع).
  final String wizardCategory;
  final String wizardType;
}

/// بطاقة عطر مدموجة: منتج حي من المتجر + بيانات البطاقة المحلية.
class FragranceCard {
  const FragranceCard({required this.product, required this.extra});

  final Product product;
  final FragranceCardExtra extra;

  /// نص الهرم العطري للعرض: النثر الكتالوجي إن وُجد، وإلا نوتات
  /// المنتج الحية.
  String pyramidText(String Function(List<String>) joinNotes) {
    final top = extra.top.isNotEmpty ? extra.top : joinNotes(product.topNotes);
    final heart =
        extra.heart.isNotEmpty ? extra.heart : joinNotes(product.heartNotes);
    final base =
        extra.base.isNotEmpty ? extra.base : joinNotes(product.baseNotes);
    return '$top\n$heart\n$base';
  }
}

/// محاور الرادار الخمسة — نفس ترتيب صفحة الموقع.
const List<String> radarAxes = <String>[
  'الثبات',
  'الفوحان',
  'الدفء',
  'الانتعاش',
  'الهيبة',
];

/// أسئلة المستكشف الذكي — نفس نصوص وخيارات صفحة الموقع حرفياً.
class WizardQuestion {
  const WizardQuestion({required this.title, required this.options});
  final String title;
  final List<WizardOption> options;
}

class WizardOption {
  const WizardOption({required this.value, required this.label});
  final String value;
  final String label;
}

const List<WizardQuestion> wizardQuestions = <WizardQuestion>[
  WizardQuestion(
    title: 'ما هي طبيعة المناسبة أو الأجواء المراد ارتداء العطر فيها؟',
    options: <WizardOption>[
      WizardOption(
        value: 'formal',
        label: '🏛️ مناسبات رسمية كبرى واجتماعات هامة',
      ),
      WizardOption(
        value: 'night',
        label: '🌙 أمسيات خاصة وليالي دافئة',
      ),
      WizardOption(
        value: 'fresh',
        label: '☀️ استخدام يومي، دوام، أو أجواء صيفية',
      ),
      WizardOption(
        value: 'feminine',
        label: '🌸 إطلالة أنثوية رزينة وراقية جداً',
      ),
    ],
  ),
  WizardQuestion(
    title: 'ما هو طابع الروائح والأكوردات التي تميل إليها حواسك؟',
    options: <WizardOption>[
      WizardOption(
        value: 'wood',
        label: '🪵 الأخشاب، العود، والجلود الفاخرة',
      ),
      WizardOption(
        value: 'sweet',
        label: '🍨 الفانيليا، التونكا، والتوباكو الدافئ',
      ),
      WizardOption(
        value: 'citrus',
        label: '🍋 الحمضيات المنعشة والنوتات البحرية/الشاي',
      ),
      WizardOption(
        value: 'floral',
        label: '🌹 الزعفران الفاخر والورود الملكية مع المسك',
      ),
    ],
  ),
];

/// بيانات البطاقات المحلية — الثمانية من كتالوج الموقع حرفياً،
/// والثلاثة الجديدة قيم افتراضية من نصوص المتجر.
const Map<String, FragranceCardExtra> fragranceCardExtras =
    <String, FragranceCardExtra>{
  'royal': FragranceCardExtra(
    code: 'ZH-01',
    tag: 'مناسبات رسمية',
    quote:
        'هيبة الملوك ونفحات القصور الفاخرة، صمم لليالي الشتوية والمناسبات الرسمية الكبرى.',
    top: 'نفحات الكونياك المعتق، القرفة السيلانية الدافئة.',
    heart: 'حبوب التونكا، أخشاب البلوط، لمسات اللوز المر.',
    base: 'الفانيليا المدغشقرية، حلوى البرالين، خشب الصندل، العنبر الملكي.',
    stats: <int>[96, 92, 95, 20, 98],
    wizardCategory: 'formal',
    wizardType: 'sweet',
  ),
  'storm': FragranceCardExtra(
    code: 'ZH-02',
    tag: 'انتعاش محيطي',
    quote: 'طاقة عارمة تجتاح الحواس بحضور طاغ وانتعاش محيطي جريء.',
    top: 'برغموت إيطالي، مياه البحر النقية، نوتات الأوزون، فلفل وردي.',
    heart: 'إكليل الجبل (روزماري)، السرو، الخزامي العطرية.',
    base: 'الأمبروكسان، المسك الأبيض، الباتشولي، طحلب البلوط.',
    stats: <int>[86, 88, 30, 98, 75],
    wizardCategory: 'fresh',
    wizardType: 'citrus',
  ),
  'aura': FragranceCardExtra(
    code: 'ZH-03',
    tag: 'هالة ذهبية',
    quote:
        'هالة ذهبية مشعة بالتفرد والرقي، تمتزج فيها أثمن التوابل مع الزهور البيضاء.',
    top: 'الزعفران الأحمر الفاخر، اللوز المر.',
    heart: 'ياسمين غرانديفلوروم المصري، أخشاب الأرز الأطلسي.',
    base: 'العنبر الرمادي (Ambergris)، الأخشاب الدافئة، المسك البلوري.',
    stats: <int>[94, 93, 80, 50, 92],
    wizardCategory: 'night',
    wizardType: 'floral',
  ),
  'aurora': FragranceCardExtra(
    code: 'ZH-04',
    tag: 'إشراقة الفجر',
    quote:
        'إشراقة الفجر ونقاء الطبيعة في زجاجة، توازن ساحر بين الحمضيات والشاي الأسود.',
    top: 'برغموت كالابريا، يوسفي صقلية، ليمون منعش.',
    heart: 'الشاي الأسود الصيني، زهر البرتقال، الزنجبيل الطازج.',
    base: 'اللبان الحوجري، أخشاب الغاياك، الأمبروكسان.',
    stats: <int>[84, 82, 45, 92, 72],
    wizardCategory: 'fresh',
    wizardType: 'citrus',
  ),
  'fares': FragranceCardExtra(
    code: 'ZH-05',
    tag: 'شخصيات قيادية',
    quote:
        'الأصالة والشهامة والهيبة في كل حضور، صمم للشخصيات القيادية والمحافل.',
    top: 'الهيل، القرنفل الفاخر.',
    heart: 'الورد الطائفي، الجلد الأصلي.',
    base: 'العود المعتق، خشب الصندل.',
    stats: <int>[98, 96, 92, 25, 99],
    wizardCategory: 'formal',
    wizardType: 'wood',
  ),
  'tobacco': FragranceCardExtra(
    code: 'ZH-06',
    tag: 'أمسيات داكنة',
    quote:
        'سحر الأمسيات الداكنة ودفء التوباكو الفاخر مع لمسات الفانيليا والكاكاو.',
    top: 'أوراق التوباكو، التوابل العطرية.',
    heart: 'زهر التبغ، الكاكاو، حبوب التونكا.',
    base: 'الفانيليا المدغشقرية، العنبر الخشبي.',
    stats: <int>[95, 90, 98, 15, 90],
    wizardCategory: 'night',
    wizardType: 'sweet',
  ),
  'fahd': FragranceCardExtra(
    code: 'ZH-07',
    tag: 'جاذبية مطلقة',
    quote: 'خلاصة الجاذبية المطلقة والتركيز العالي، تنبض بالثقة والجسارة.',
    top: 'الجريب فروت، النعناع المنعش، القرفة.',
    heart: 'الورد، الهيل العطري.',
    base: 'العنبر الخشبي، الجلود الفاخرة.',
    stats: <int>[92, 94, 75, 65, 94],
    wizardCategory: 'night',
    wizardType: 'wood',
  ),
  'musk': FragranceCardExtra(
    code: 'ZH-08',
    tag: 'انتعاش يومي',
    quote: 'نقاء المسك الأبيض بلمسات عصرية ساحرة تجمع بين الدفء والانتعاش.',
    top: 'المسك الأبيض النقي، البرغموت.',
    heart: 'زهر البرتقال، حبوب التونكا.',
    base: 'المسك الملكي، أخشاب الكشمير.',
    stats: <int>[88, 85, 55, 85, 78],
    wizardCategory: 'fresh',
    wizardType: 'floral',
  ),
  // --- العطور الثلاثة الجديدة: قيم افتراضية من نصوص المتجر ---
  'layl': FragranceCardExtra(
    code: '',
    tag: 'يومي ومسائي',
    quote: 'رفيق الليل الهادئ؛ عود ومسك وعنبر لكل الفصول، ليومك ومسائك.',
    top: 'برغموت، فلفل وردي.',
    heart: 'ورد طائفي، ياسمين.',
    base: 'عود، مسك، عنبر.',
    stats: <int>[88, 86, 70, 60, 85],
    wizardCategory: 'fresh',
    wizardType: 'floral',
  ),
  'elixir': FragranceCardExtra(
    code: '',
    tag: 'السهرات والجاذبية المطلقة',
    quote:
        'تابلي أروماتيك جبار الحضور؛ الهيل والقرفة واللافندر لسهرات لا تُنسى.',
    top: 'الهيل، جوزة الطيب، القرفة، الجريب فروت.',
    heart: 'اللافندر الفرنسي (الخزامى).',
    base: 'العرقسوس، خشب الصندل، العنبر، الباتشولي، نجيل الهند.',
    stats: <int>[99, 97, 85, 30, 96],
    wizardCategory: 'night',
    wizardType: 'wood',
  ),
  'sultan': FragranceCardExtra(
    code: '',
    tag: 'الاجتماعات الرسمية والمناسبات',
    quote: 'جلدي أرستقراطي مهيب.',
    top: 'الدافانا، البرغموت الإيطالي، الفلفل الوردي.',
    heart: 'العود الكمبودي، العنبر الأبيض، إكليل الجبل.',
    base: 'الجلود، المسك، نجيل الهند، الباتشولي.',
    stats: <int>[97, 95, 90, 25, 99],
    wizardCategory: 'formal',
    wizardType: 'wood',
  ),
};

/// يدمج منتجات المتجر الحية مع بيانات البطاقات المحلية — بنفس ترتيب
/// التشكيلة الحية (ليل، إلكسير، سلطان أولاً). عطر بلا بيانات محلية
/// (لا يحدث اليوم) يأخذ اقتباساً ودرجات افتراضية من نوتاته.
List<FragranceCard> mergeFragranceCards(List<Product> products) {
  return products.map((product) {
    final extra = fragranceCardExtras[product.id];
    if (extra != null) return FragranceCard(product: product, extra: extra);
    return FragranceCard(
      product: product,
      extra: FragranceCardExtra(
        code: '',
        tag: product.occasion,
        quote: product.name,
        top: product.topNotes.join('، '),
        heart: product.heartNotes.join('، '),
        base: product.baseNotes.join('، '),
        stats: const <int>[85, 85, 60, 50, 85],
        wizardCategory: 'fresh',
        wizardType: 'floral',
      ),
    );
  }).toList(growable: false);
}

/// توصية المستكشف الذكي — نفس منطق صفحة الموقع حرفياً: مطابقة
/// دقيقة (المناسبة + الطابع)، ثم مطابقة المناسبة وحدها، ثم أول بطاقة.
FragranceCard recommendFragranceCard(
  List<FragranceCard> cards,
  String category,
  String type,
) {
  for (final card in cards) {
    if (card.extra.wizardCategory == category &&
        card.extra.wizardType == type) {
      return card;
    }
  }
  for (final card in cards) {
    if (card.extra.wizardCategory == category) return card;
  }
  return cards.first;
}
