import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import '../models/product.dart';

class ProductApi {
  static const String apiUrl = 'https://zakhamhouse.shop/api.php?route=api/storefront';

  http.Client _getClient() {
    bool trustSelfSigned = true;
    HttpClient httpClient = HttpClient()
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => trustSelfSigned;
    return IOClient(httpClient);
  }

  Future<Map<String, dynamic>> fetchProducts() async {
    return await fetchStorefront();
  }

  Future<Map<String, dynamic>> fetchStorefront() async {
    try {
      final client = _getClient();
      
      // إضافة Headers لخداع جدار الحماية ومنع ظهور صفحة التحقق الـ HTML
      final response = await client.get(
        Uri.parse(apiUrl),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept': 'application/json, text/plain, */*',
        },
      );
      
      if (response.statusCode == 200) {
        // التحقق من أن الاستجابة وليست صفحة HTML حماية
        if (response.body.trim().startsWith('<')) {
          throw Exception('الخادم يعيد صفحة حماية HTML بدلاً من بيانات المنتجات.');
        }

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
