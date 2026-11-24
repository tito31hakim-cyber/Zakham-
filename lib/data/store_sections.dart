import 'package:flutter/material.dart';

/// أقسام دار زخم — محتوى ثابت مطابق لصفحات الموقع الحي
/// (/ritual و/gifts و/packaging و/bundles) كما ظهرت في النسخة الحية،
/// بنفس نمط `featured_product.dart`: بيانات عرض ثابتة، وأي تغيير في
/// نصوص الموقع يبدأ من صفحات المتجر ثم يُحدَّث هنا.

enum SectionCtaKind {
  /// ينتقل إلى تبويب التشكيلة داخل التطبيق.
  collection,

  /// يفتح واتساب الدار برسالة جاهزة عن القسم.
  whatsapp,
}

/// خطوة مرقّمة داخل القسم (خطوات الطقس، تفاصيل التغليف، باقات التوفير).
class SectionStep {
  const SectionStep({
    required this.number,
    required this.title,
    required this.body,
    this.tag = '',
  });

  final String number;
  final String title;
  final String body;

  /// وسم صغير تحت العنوان (مثال: «المسافة الذهبية · 15 سم»، أو اسم
  /// الباقة بالإنجليزية مثل «Royal Trio»).
  final String tag;
}

class StoreSection {
  const StoreSection({
    required this.id,
    required this.title,
    required this.eyebrow,
    required this.tileDetail,
    required this.lead,
    required this.icon,
    this.highlightValue = '',
    this.highlightLabel = '',
    this.steps = const <SectionStep>[],
    this.features = const <String>[],
    this.closingTitle = '',
    this.closingBody = '',
    required this.ctaLabel,
    required this.ctaKind,
    this.whatsappMessage = '',
  });

  final String id;
  final String title;

  /// سطر تعريفي صغير فوق العنوان.
  final String eyebrow;

  /// سطر فرعي قصير لبطاقة القسم في شبكة الرئيسية — سطر واحد مكتمل
  /// بلا قص ولا تكرار إنجليزي؛ يختلف عن `eyebrow` (سطر الترويسة
  /// الذهبي في صفحة تفاصيل القسم).
  final String tileDetail;

  /// الفقرة الافتتاحية للقسم.
  final String lead;
  final IconData icon;

  /// رقم بارز اختياري (مثال: «15 سم» في طقس زخم).
  final String highlightValue;
  final String highlightLabel;

  final List<SectionStep> steps;

  /// نقاط مميزة (مثال: مزايا صندوق الإهداء).
  final List<String> features;

  /// خاتمة القسم (مثال: «سرّ الأثر في هدوئه»).
  final String closingTitle;
  final String closingBody;

  final String ctaLabel;
  final SectionCtaKind ctaKind;

  /// نص رسالة واتساب الجاهزة عند اختيار `whatsapp`.
  final String whatsappMessage;
}

const String _whatsappBase = 'https://wa.me/201042881176?text=';

/// كل أقسام الدار الخمسة بالترتيب الظاهر في الموقع.
const List<StoreSection> storeSections = <StoreSection>[
  StoreSection(
    id: 'collection',
    title: 'التشكيلة',
    eyebrow: 'تشكيلة زخم الرسمية · 2027',
    tileDetail: '11 عطراً',
    lead:
        'أحد عشر عطرًا في تشكيلة زخم 2027، وثلاثة تركيزات معتمدة مع أسعار كل سعة داخل بطاقة العطر.',
    icon: Icons.grid_view_rounded,
    ctaLabel: 'تصفّح التشكيلة',
    ctaKind: SectionCtaKind.collection,
  ),
  StoreSection(
    id: 'ritual',
    title: 'طقس زخم',
    eyebrow: 'THE ZAKHAM RITUAL · طقس زخم',
    tileDetail: 'تجربة التعتيق والرش',
    lead:
        'العطر أكثر من رائحة؛ إنه اللمسة الأخيرة التي تُعرّف بحضورك. امنحه لحظةً من العناية، ودعه يترك أثره.',
    icon: Icons.auto_awesome,
    highlightValue: '15 سم',
    highlightLabel: 'المسافة المثالية للرش',
    steps: <SectionStep>[
      SectionStep(
        number: '01',
        title: 'اختر موضع الأثر',
        body: 'وجّه العطر إلى نقاط النبض، أو إلى الأقمشة التي ترافق إطلالتك.',
        tag: 'نقاط النبض · الأقمشة',
      ),
      SectionStep(
        number: '02',
        title: 'اترك بينكما 15 سم',
        body: 'رشّ من المسافة المثالية لتوزيعٍ أنعم ولمسةٍ متوازنة على موضع الرش.',
        tag: 'المسافة الذهبية · 15 سم',
      ),
      SectionStep(
        number: '03',
        title: 'دع العطر يستقر',
        body: 'بعد الرش، لا تفرك العطر. امنحه لحظته ليبقى إحساسه كما ينبغي.',
        tag: 'لا تفرك · اتركه يهدأ',
      ),
    ],
    closingTitle: 'سرّ الأثر في هدوئه.',
    closingBody: 'رشةٌ مدروسة، ومسافةٌ صحيحة، ثم اترك للعطر أن يتحدث.',
    ctaLabel: 'اختر عطرك الآن',
    ctaKind: SectionCtaKind.collection,
  ),
  StoreSection(
    id: 'gifts',
    title: 'الإهداء',
    eyebrow: 'الهدايا الملكية · صندوق زخم الخشبي',
    tileDetail: 'صندوق الإهداء الملكي',
    lead:
        'حين تصبح الهدية أثرًا. خشب صُنع بلمسات يدوية، نقش يكتب لأجلك، وعطور تختارها لتحكيا حكايتك. قطعة تُحفظ قبل أن تُفتح.',
    icon: Icons.card_giftcard_outlined,
    features: <String>[
      'نقش مخصص مذهّب باسمك أو اسم من تحب',
      'تشكيلة عطور فاخرة من اختيارك',
      'بطاقة إهداء مذهّبة وتغليف قطيفة أسود فاخر',
    ],
    ctaLabel: 'صمّم صندوقك الخاص',
    ctaKind: SectionCtaKind.whatsapp,
    whatsappMessage:
        'مرحباً، أريد تصميم صندوق زخم الخشبي الملكي للإهداء.',
  ),
  StoreSection(
    id: 'packaging',
    title: 'التغليف الفاخر',
    eyebrow: 'THE ZAKHAM FINISH · التغليف الفاخر',
    tileDetail: 'تغليف فاخر يليق بك',
    lead:
        'الفخامة تبدأ قبل الرشّة. في دار زخم، تمتد التجربة من اختيار العطر إلى تفاصيل العبوة؛ ملمسٌ مخملي، درجةٌ مارونية عميقة، وزجاجةٌ كريستالية تليق بحضور العطر.',
    icon: Icons.diamond_outlined,
    steps: <SectionStep>[
      SectionStep(
        number: '01',
        title: 'علبة المارون المخملية',
        body:
            'لونٌ عميق وملمسٌ مخملي يقدّمان العطر بلمسةٍ تليق به، من أول نظرة وحتى لحظة فتح العلبة.',
        tag: '01 · MAROON VELVET · المارون المخملي',
      ),
      SectionStep(
        number: '02',
        title: 'زجاجة كريستالية ثقيلة',
        body:
            'صفاء الكريستال وثقل الزجاجة يمنحان العبوة حضورًا بصريًا متزنًا، امتدادًا لهوية زخم.',
        tag: '02 · CRYSTAL GLASS · الزجاجة الكريستالية',
      ),
    ],
    closingTitle: 'حين تكتمل العبوة، يبدأ الانطباع.',
    closingBody:
        'اكتشف العطر الذي يعبّر عن حضورك، ودع تفاصيل زخم تكمل حكايته.',
    ctaLabel: 'اكتشف التشكيلة',
    ctaKind: SectionCtaKind.collection,
  ),
  StoreSection(
    id: 'bundles',
    title: 'باقات التوفير',
    eyebrow: 'باقات التوفير من زخم · متعة البداية',
    tileDetail: 'باقات التوفير من زخم · متعة البداية',
    lead:
        'هدية أكبر، أثر أبقى. كوّن اختياراتك من التشكيلة المفضلة واستمتع بتغليف فاخر وتوفير خاص — السعر النهائي يحدد حسب اختياراتك عبر VIP WhatsApp.',
    icon: Icons.layers_outlined,
    steps: <SectionStep>[
      SectionStep(
        number: '01',
        title: 'بوكس الاستكشاف',
        body: 'مجموعة عبوات 30 مل لتجربة تشكيلة زخم المتنوعة.',
        tag: 'Discovery',
      ),
      SectionStep(
        number: '02',
        title: 'ثنائية التفرد',
        body: 'عبوتان بحجم 100 مل مع ميزة توفير حصرية.',
        tag: 'Signature Duo',
      ),
      SectionStep(
        number: '03',
        title: 'الثلاثية الملكية',
        body: '3 عطور بحجم 50 مل بخصم خاص وتغليف فاخر.',
        tag: 'Royal Trio',
      ),
    ],
    ctaLabel: 'اطلب التفاصيل',
    ctaKind: SectionCtaKind.whatsapp,
    whatsappMessage: 'مرحباً، أريد تفاصيل باقات التوفير من دار زخم.',
  ),
];

StoreSection sectionById(String id) => storeSections.firstWhere(
      (section) => section.id == id,
      orElse: () => storeSections.first,
    );

/// رابط واتساب الدار برسالة جاهزة.
String zakhamWhatsAppUrl(String message) =>
    '$_whatsappBase${Uri.encodeComponent(message)}';
