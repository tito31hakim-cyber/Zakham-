import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/product.dart';

class ProductApi {
  // استخدام الرابط المباشر لملف الـ api.php الأساسي في استضافتك
  static const String apiUrl = 'https://zakhamhouse.shop/api.php?route=api/storefront';

  Future<Map<String, dynamic>> fetchProducts() async {
    return await fetchStorefront();
  }

  Future<Map<String, dynamic>> fetchStorefront() async {
    try {
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      );
      
      if (response.statusCode == 200) {
        final body = response.body.trim();
        
        // إذا كان الرد يحتوي على أكواد صفحة HTML أو خطأ حماية
        if (body.startsWith('<')) {
          throw Exception('الخادم يعيد صفحة HTML. تأكد من إيقاف حماية الاستضافة المؤقتة (Anti-DDoS / WAF).');
        }

        final data = json.decode(body);
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
        throw Exception('خطأ في الخادم: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('تعذر جلب المنتجات حالياً: $e');
    }
  }
}
