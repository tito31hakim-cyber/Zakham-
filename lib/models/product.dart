import '../config/app_config.dart';

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
    this.description = '',
    this.defaultConcentration = 'presence',
    this.prices = const <String, dynamic>{},
    this.variants = const <String, dynamic>{},
  });

  final String id;
  final String name;
  final double price;
  final String currency;
  final String size;
  final String category;
  final List<String> topNotes;
  final List<String> heartNotes;
  final List<String> baseNotes;
  final String image;
  final bool inStock;
  final String description;
  final String defaultConcentration;
  final Map<String, dynamic> prices;
  final Map<String, dynamic> variants;

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
      if (value is String && value.trim().isNotEmpty) return [value.trim()];
      if (value is List) return value.whereType<String>().toList(growable: false);
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
    final selectedVariant = variants[defaultConcentration];
    final variantPrices = selectedVariant is Map
        ? Map<String, dynamic>.from(selectedVariant['prices'] as Map? ?? {})
        : <String, dynamic>{};
    final stockQty = (json['stockQty'] as num?)?.toInt() ?? 0;
    final inStock = json['in_stock'] == true ||
        json['stockStatus'] == 'available' ||
        stockQty > 0;

    double priceFrom(Map<String, dynamic> values) {
      for (final key in const ['100', '50', '30']) {
        final value = values[key] ?? values[int.parse(key)];
        if (value is num) return value.toDouble();
      }
      return 0;
    }

    return Product(
      id: '${json['product_id'] ?? json['id'] ?? ''}',
      name: '${json['name'] ?? json['nameAr'] ?? ''}',
      price: (json['price'] as num?)?.toDouble() ??
          priceFrom(variantPrices.isNotEmpty ? variantPrices : prices),
      currency: '${json['currency'] ?? 'EGP'}',
      size: '${json['size'] ?? json['sizeMl'] ?? '100 ml'}',
      category: '${json['category'] ?? ''}',
      topNotes: notes('top_notes', 'top'),
      heartNotes: notes('heart_notes', 'middle'),
      baseNotes: notes('base_notes', 'base'),
      image: AppConfig.resolveImageUrl('${json['image'] ?? ''}'),
      inStock: inStock,
      description: '${json['season'] ?? ''}',
      defaultConcentration: defaultConcentration,
      prices: prices,
      variants: variants,
    );
  }
}
