import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/product.dart';

class ProductApi {
  // الرابط المباشر المحدث للـ API على استضافتك
  static const String apiUrl = 'https://zakhamhouse.shop/api.php?route=api/storefront';

  Future<Map<String, dynamic>> fetchStorefront() async {
    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<Product> products = [];
        if (data['products'] != null) {
          products = (data['products'] as List)
              .map((item) => Product.fromJson(item))
              .toList();
        }
        return {
          'settings': data['settings'] ?? {},
          'products': products,
        };
      } else {
        throw Exception('فشل الاتصال بالخادم: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('تعذر جلب المنتجات حالياً: $e');
    }
  }
}
