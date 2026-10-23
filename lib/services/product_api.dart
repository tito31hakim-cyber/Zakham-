import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/product.dart';

class ProductApi {
  // الرابط المباشر الصحيح للملف داخل مجلد mobile-api الذي أنشأته
  static const String apiUrl = 'https://zakhamhouse.shop/mobile-api/products.json';

  Future<Map<String, dynamic>> fetchProducts() async {
    return await fetchStorefront();
  }

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
        throw Exception('فشل الاتصال: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('تعذر جلب المنتجات حالياً: $e');
    }
  }
}
