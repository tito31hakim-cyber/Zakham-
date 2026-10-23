class AppConfig {
  AppConfig._();

  static const appName = 'House of Zakham';
  static const apiBaseUrl = 'https://zakhamhouse.shop';

  // Infinity Free serves api.php through the /api/* rewrite rules.
  static const productsPath = '/api/storefront';
  static const ordersPath = '/api/orders';
  static const adminProductsPath = '/api/admin/products';
  static const adminCustomersPath = '/api/admin/customers';
  static const analyticsPath = '/api/analytics';
  static const productImageBaseUrl = '$apiBaseUrl/';
  static const featuredImage =
      '$apiBaseUrl/assets/products/catalog-royal-2026.jpg';

  static Uri get productsUri => Uri.parse('$apiBaseUrl$productsPath');
  static Uri get ordersUri => Uri.parse('$apiBaseUrl$ordersPath');
  static Uri adminProductUri(String id) =>
      Uri.parse('$apiBaseUrl$adminProductsPath/${Uri.encodeComponent(id)}');
  static Uri get adminProductsUri => Uri.parse('$apiBaseUrl$adminProductsPath');
  static Uri adminCustomersUri(String query) => Uri.parse(
        '$apiBaseUrl$adminCustomersPath?q=${Uri.encodeQueryComponent(query)}',
      );
  static Uri get analyticsUri => Uri.parse('$apiBaseUrl$analyticsPath');

  static String resolveImageUrl(String image) {
    final value = image.trim();
    if (value.isEmpty) return featuredImage;
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    return '$productImageBaseUrl${value.replaceFirst(RegExp(r'^/+'), '')}';
  }
}
