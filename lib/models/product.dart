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

  factory Product.fromJson(Map<String, dynamic> json) {
    final pyramid = (json['olfactory_pyramid'] as Map<String, dynamic>?) ?? {};

    List<String> notes(String key) => List<String>.from(
      (pyramid[key] as List<dynamic>?) ?? const <dynamic>[],
    );

    return Product(
      id: '${json['product_id'] ?? json['id'] ?? ''}',
      name: '${json['name'] ?? ''}',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      currency: '${json['currency'] ?? 'EGP'}',
      size: '${json['size'] ?? ''}',
      category: '${json['category'] ?? ''}',
      topNotes: notes('top_notes'),
      heartNotes: notes('heart_notes'),
      baseNotes: notes('base_notes'),
      image: '${json['image'] ?? ''}',
      inStock: json['in_stock'] == true,
    );
  }
}
