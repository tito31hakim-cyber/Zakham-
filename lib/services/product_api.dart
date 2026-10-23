import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import '../models/product.dart';

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

class ProductApi {
  static const String apiUrl = 'https://zakhamhouse.shop/api.php?route=api/storefront';

  Future<Map<String, dynamic>> fetchProducts() async {
    return await fetchStorefront();
  }

  Future<Map<String, dynamic>> fetchStorefront() async {
    try {
      // تفعيل تجاوز الشهادات على مستوى التطبيق بالكامل
      HttpOverrides.global = MyHttpOverrides();
      
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
        },
      );
      
      if (response.statusCode == 200) {
        final body = response.body.trim();
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
        throw Exception('خطأ في استجابة الخادم: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('تعذر جلب المنتجات حالياً: $e');
    }
  }
}
