class AppConfig {
  AppConfig._();

  static const appName = 'House of Zakham';
  static const apiBaseUrl = 'https://zakhamhouse.shop';

  // الخادم الحالي serves api.php through the /api/* rewrite rules.
  static const productsPath = '/api/storefront';
  static const ordersPath = '/api/orders';
  static const adminProductsPath = '/api/admin/products';
  static const adminCustomersPath = '/api/admin/customers';
  static const adminOrdersSearchPath = '/api/admin/orders/search';
  static const adminSessionPath = '/api/admin/session';
  static const adminLoginPath = '/api/admin/login';
  static const adminLogoutPath = '/api/admin/logout';
  static const adminPushSendPath = '/api/admin/push/send';
  static const analyticsPath = '/api/analytics';
  // حسابات الأعضاء (العملاء) — نفس مسارات المتجر الحي.
  static const customerRegisterPath = '/api/auth/register';
  static const customerLoginPath = '/api/auth/login';
  static const customerVerifyPhonePath = '/api/auth/verify-phone';
  static const customerResendPhonePath = '/api/auth/resend-phone';
  static const customerMePath = '/api/auth/me';
  static const customerLogoutPath = '/api/auth/logout';
  static const customerOrdersPath = '/api/account/orders';
  static const customerPointsPath = '/api/account/points';
  static const customerAddressesPath = '/api/account/addresses';

  /// قائمة المحافظات والمدن المعتمدة (GET /api/locations/eg).
  static const locationsEgPath = '/api/locations/eg';

  /// قواعد الخصم المفعّلة — قراءة عامة (GET /api/discounts/active).
  static const discountsActivePath = '/api/discounts/active';

  /// إدارة قواعد الخصم — جلسة أدمن + صلاحية offers.manage.
  static const adminDiscountsPath = '/api/admin/discounts';
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
  static Uri get customerAddressesUri =>
      Uri.parse('$apiBaseUrl$customerAddressesPath');
  static Uri get locationsEgUri => Uri.parse('$apiBaseUrl$locationsEgPath');
  static Uri get discountsActiveUri =>
      Uri.parse('$apiBaseUrl$discountsActivePath');
  static Uri adminDiscountUri(String id) => Uri.parse(
        '$apiBaseUrl$adminDiscountsPath/${Uri.encodeComponent(id)}',
      );
  static Uri orderInvoiceUri(String ref) => Uri.parse(
        '$apiBaseUrl/api/orders/${Uri.encodeComponent(ref)}/invoice',
      );

  static String resolveImageUrl(String image) {
    final value = image.trim();
    if (value.isEmpty) return featuredImage;
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    return '$productImageBaseUrl${value.replaceFirst(RegExp(r'^/+'), '')}';
  }
}
