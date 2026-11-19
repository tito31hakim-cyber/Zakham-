import '../config/app_config.dart';

/// منتج من رد `/api/storefront` الحي.
///
/// ملاحظات عن شكل الرد الحي (تشكيلة 2027 — 11 عطراً):
/// - الأسعار تأتي كنصوص أحياناً ("500") وأحياناً أرقاماً (500)، داخل
///   `prices` وداخل `variants[concentration].prices`؛ لذلك كل تحويل سعري
///   يقبل النوعين.
/// - لا يوجد `perfumeCode` ولا `qrPayload` ولا `stockQty` في الرد العام
///   إطلاقاً — لا يعتمد عليها أي كود هنا.
/// - `notes.top/middle/base` قد تكون نصاً واحداً أو قائمة نصوص.
/// - التركيزات: `presence` (حُضور)، `extra` (فَوْحان)، `nuclear` (نووي).
///   النووي بلا حجم 30 مل (50 و100 فقط).
class Product {
  const Product({
    required this.id,
    required this.name,
    required this.price,
    required this.currency,
    required this.size,
    required this.category,
    required this.topNotes,
    required this.heartNotes,
    required this.baseNotes,
    required this.image,
    required this.inStock,
    this.nameEn = '',
    this.categoryLabel = '',
    this.description = '',
    this.season = '',
    this.occasion = '',
    this.lasting = '',
    this.visible = true,
    this.defaultConcentration = 'presence',
    this.prices = const <String, dynamic>{},
    this.variants = const <String, dynamic>{},
    this.tags = const <String>[],
  });

  final String id;
  final String name;
  final String nameEn;
  final double price;
  final String currency;
  final String size;
  final String category;
  final String categoryLabel;
  final List<String> topNotes;
  final List<String> heartNotes;
  final List<String> baseNotes;
  final String image;
  final bool inStock;
  final bool visible;
  final String description;
  final String season;
  final String occasion;
  final String lasting;
  final String defaultConcentration;
  final Map<String, dynamic> prices;
  final Map<String, dynamic> variants;
  /// وسوم الخادم (مثل `gender:unisex` / `gender:male`) — منها يُستنتج النوع.
  final List<String> tags;

  /// رابط صفحة العطر على الموقع — وهو نفسه رابط المشاركة والرابط العميق.
  String get productUrl => 'https://zakhamhouse.shop/product/$id';

  /// النوع من الوسوم: `male` / `female` / `unisex`، أو `''` إن لم يحدده الخادم.
  String get gender {
    for (final tag in tags) {
      final value = tag.trim().toLowerCase();
      if (value == 'gender:male') return 'male';
      if (value == 'gender:female') return 'female';
      if (value == 'gender:unisex') return 'unisex';
    }
    return '';
  }

  /// اسم النوع للعرض.
  String get genderLabel {
    switch (gender) {
      case 'male':
        return 'رجالي';
      case 'female':
        return 'نسائي';
      case 'unisex':
        return 'للجنسين';
      default:
        return '';
    }
  }

  /// كل النوتات (مقدمة + قلب + قاعدة) كنص واحد — أساس البحث بالنوتة.
  String get allNotesText =>
      <String>[...topNotes, ...heartNotes, ...baseNotes].join(' ');

  /// هل تطابق النوتات كلمة نوتة معينة؟ المقارنة على مستوى الكلمة
  /// الكاملة (مع «ال» أو بدونها)، حتى لا يطابق «ورد» مثلاً كلمة
  /// «وردي» في «فلفل وردي».
  bool matchesNote(String keyword) {
    final key = keyword.trim();
    if (key.isEmpty) return false;
    final words = allNotesText
        .split(RegExp(r'[\s،,.;:()\[\]"''«»]+'))
        .map((word) => word.trim())
        .where((word) => word.isNotEmpty);
    return words.any((word) => word == key || word == 'ال$key');
  }

  /// هل يطابق نص الموسم كلمة مفتاحية (مثل «شتو» في «الليالي الشتوية»)
  /// أو العبارة «كل الفصول»؟
  bool matchesSeason(String needle) =>
      needle.isNotEmpty && season.contains(needle);

  /// هل تطابق المناسبة كلمة مفتاحية (مثل «رسمي» في «مناسبات رسمية»)؟
  bool matchesOccasion(String needle) =>
      needle.isNotEmpty && occasion.contains(needle);

  /// ترتيب التركيزات المعتمد في المتجر الحي.
  static const List<String> concentrationOrder = <String>[
    'presence',
    'extra',
    'nuclear',
  ];

  static const Map<String, String> concentrationNamesAr =
      <String, String>{
    'presence': 'حُضور',
    'extra': 'فَوْحان',
    'nuclear': 'نووي',
  };

  static const Map<String, String> concentrationNamesEn =
      <String, String>{
    'presence': 'Eau de Parfum',
    'extra': 'Extrait Prime',
    'nuclear': 'Extrait Max',
  };

  /// يحوّل قيمة سعرية قد تكون رقماً أو نصاً رقمياً ("500") إلى double.
  static double? toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) {
      final cleaned = value.trim().replaceAll(',', '').replaceAll(' ', '');
      return double.tryParse(cleaned);
    }
    return null;
  }

  static bool _toVisible(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final lower = value.trim().toLowerCase();
      return lower == '1' || lower == 'true' || lower == 'yes';
    }
    return true;
  }

  /// أسعار تركيز ما: خريطة حجم (30/50/100) إلى سعر، بقيم رقمية.
  Map<int, double> _variantPrices(String concentration) {
    final result = <int, double>{};
    final variant = variants[concentration];
    if (variant is Map) {
      final raw = variant['prices'];
      if (raw is Map) {
        raw.forEach((key, value) {
          final size = int.tryParse('$key'.trim());
          final price = toDouble(value);
          if (size != null && price != null) result[size] = price;
        });
      }
    }
    return result;
  }

  /// الأسعار المسطّحة (بلا تركيز) من `prices`، بقيم رقمية.
  Map<int, double> get _flatPrices {
    final result = <int, double>{};
    prices.forEach((key, value) {
      final size = int.tryParse('$key'.trim());
      final price = toDouble(value);
      if (size != null && price != null) result[size] = price;
    });
    return result;
  }

  /// التركيزات المتوفرة لهذا المنتج بالترتيب المعتمد.
  List<String> get availableConcentrations {
    final found = concentrationOrder
        .where((key) => _variantPrices(key).isNotEmpty)
        .toList(growable: false);
    if (found.isNotEmpty) return found;
    if (concentrationOrder.contains(defaultConcentration)) {
      return <String>[defaultConcentration];
    }
    return const <String>['presence'];
  }

  /// الأحجام المتوفرة (بالمل) لتركيز معين، مرتبة تصاعدياً.
  List<int> availableSizes([String? concentration]) {
    final key = concentration ?? defaultConcentration;
    var sizes = _variantPrices(key).keys.toList(growable: false);
    if (sizes.isEmpty) sizes = _flatPrices.keys.toList(growable: false);
    sizes.sort();
    return sizes;
  }

  /// الحجم الافتراضي: 100 مل إن وُجد للتركيز الافتراضي، وإلا أكبر حجم متاح.
  int get defaultSizeMl {
    final sizes = availableSizes();
    if (sizes.isEmpty) return 100;
    if (sizes.contains(100)) return 100;
    return sizes.last;
  }

  /// عدد المللي في `size` (مثل "100 ml")، أو الحجم الافتراضي.
  int get sizeMl {
    final parsed =
        int.tryParse(size.replaceAll(RegExp(r'[^0-9]'), ''));
    return parsed ?? defaultSizeMl;
  }

  /// سعر حجم وتركيز محددين من `variants` أولاً ثم من `prices` المسطّحة.
  double? priceFor({required String concentration, required int sizeMl}) {
    final variantPrices = _variantPrices(concentration);
    if (variantPrices.containsKey(sizeMl)) return variantPrices[sizeMl];
    final flat = _flatPrices;
    if (flat.containsKey(sizeMl)) return flat[sizeMl];
    return null;
  }

  /// أقل سعر متاح عبر كل التركيزات والأحجام (المتغيرات ثم المسطّحة)،
  /// أو `price` عند غيابها — أساس «يبدأ من» في البطاقات.
  /// للعطر القياسي (100مل 500/700/950، 50مل 350/500/650،
  /// 30مل 250/350) الأدنى 250.
  double get lowestPrice {
    double? lowest;
    void consider(Map<int, double> values) {
      for (final value in values.values) {
        if (lowest == null || value < lowest!) lowest = value;
      }
    }
    for (final key in concentrationOrder) {
      consider(_variantPrices(key));
    }
    consider(_flatPrices);
    return lowest ?? price;
  }

  /// اسم التركيز للعرض (من `variants[].label` أولاً ثم الاسم المعتمد).
  String concentrationLabel(String key) {
    final variant = variants[key];
    if (variant is Map) {
      final label = '${variant['label'] ?? ''}'.trim();
      if (label.isNotEmpty) return label;
    }
    final ar = concentrationNamesAr[key];
    final en = concentrationNamesEn[key];
    if (ar != null && en != null) return '$ar · $en';
    return key;
  }

  /// نسخة من المنتج بتركيز/حجم/سعر مختارين (تُستخدم عند الإضافة إلى السلة).
  Product copyWith({double? price, String? size, String? defaultConcentration}) {
    return Product(
      id: id,
      name: name,
      nameEn: nameEn,
      price: price ?? this.price,
      currency: currency,
      size: size ?? this.size,
      category: category,
      categoryLabel: categoryLabel,
      topNotes: topNotes,
      heartNotes: heartNotes,
      baseNotes: baseNotes,
      image: image,
      inStock: inStock,
      visible: visible,
      description: description,
      season: season,
      occasion: occasion,
      lasting: lasting,
      defaultConcentration: defaultConcentration ?? this.defaultConcentration,
      prices: prices,
      variants: variants,
      tags: tags,
    );
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    final rawPyramid = json['olfactory_pyramid'];
    final pyramid = rawPyramid is Map
        ? Map<String, dynamic>.from(rawPyramid)
        : <String, dynamic>{};
    final rawNotes = json['notes'];
    final notesMap = rawNotes is Map
        ? Map<String, dynamic>.from(rawNotes)
        : <String, dynamic>{};

    List<String> notes(String pyramidKey, String legacyKey) {
      final value = pyramid[pyramidKey] ?? notesMap[legacyKey];
      if (value is String && value.trim().isNotEmpty) {
        return <String>[value.trim()];
      }
      if (value is List) {
        return value
            .whereType<String>()
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList(growable: false);
      }
      return const <String>[];
    }

    Map<String, dynamic> mapValue(String key) {
      final value = json[key];
      return value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
    }

    final prices = mapValue('prices');
    final variants = mapValue('variants');
    final defaultConcentration =
        '${json['defaultConcentration'] ?? 'presence'}';
    final visible = _toVisible(json['visible']);
    // الرد العام لا يحمل stockQty إطلاقاً؛ التوفر من stockStatus فقط.
    final inStock = json['in_stock'] == true ||
        json['stockStatus'] == 'available';

    double priceFrom(Map<int, double> values) {
      for (final key in const [100, 50, 30]) {
        if (values.containsKey(key)) return values[key]!;
      }
      return 0;
    }

    // السعر الافتراضي: التركيز الافتراضي بأكبر حجم متاح (100 مل عادةً).
    final probe = Product(
      id: '${json['product_id'] ?? json['id'] ?? ''}',
      name: '${json['name'] ?? json['nameAr'] ?? ''}',
      price: 0,
      currency: '${json['currency'] ?? 'EGP'}',
      size: '100 ml',
      category: '${json['category'] ?? ''}',
      topNotes: const <String>[],
      heartNotes: const <String>[],
      baseNotes: const <String>[],
      image: '',
      inStock: inStock,
      defaultConcentration: defaultConcentration,
      prices: prices,
      variants: variants,
    );
    final defaultPrice = probe.priceFor(
          concentration: defaultConcentration,
          sizeMl: probe.defaultSizeMl,
        ) ??
        toDouble(json['price']) ??
        priceFrom(probe._flatPrices);

    final season = '${json['season'] ?? ''}'.trim();
    final category = '${json['category'] ?? ''}';
    final categoryLabel = '${json['categoryLabel'] ?? ''}'.trim();
    final rawTags = json['tags'];
    final tags = rawTags is List
        ? rawTags
            .whereType<String>()
            .map((tag) => tag.trim())
            .where((tag) => tag.isNotEmpty)
            .toList(growable: false)
        : const <String>[];

    return Product(
      id: '${json['product_id'] ?? json['id'] ?? ''}',
      name: '${json['name'] ?? json['nameAr'] ?? ''}',
      nameEn: '${json['en'] ?? ''}'.trim(),
      price: defaultPrice,
      currency: '${json['currency'] ?? 'EGP'}',
      size: '${probe.defaultSizeMl} ml',
      category: category,
      categoryLabel: categoryLabel.isEmpty ? category : categoryLabel,
      topNotes: notes('top_notes', 'top'),
      heartNotes: notes('heart_notes', 'middle'),
      baseNotes: notes('base_notes', 'base'),
      image: AppConfig.resolveImageUrl('${json['image'] ?? ''}'),
      inStock: inStock,
      visible: visible,
      // الوصف: نص الموسم/المناسبة كما يرده الخادم (هو النسخة الوصفية
      // الوحيدة في الرد)، وتُعرض المناسبة والثبات كحقول مستقلة أيضاً.
      description: season,
      season: season,
      occasion: '${json['occasion'] ?? ''}'.trim(),
      lasting: '${json['lasting'] ?? ''}'.trim(),
      defaultConcentration: defaultConcentration,
      prices: prices,
      variants: variants,
      tags: tags,
    );
  }
}
