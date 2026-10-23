import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import '../models/product.dart';

class ProductApi {
  static const String apiUrl = 'https://zakhamhouse.shop/mobile-api/products.json';

  // إنشاء عميل HTTP يتجاوز شهادة الأمان نهائياً لمنع ظهور خطأ HandshakeException
  http.Client _getUnsafeClient() {
    HttpClient httpClient = HttpClient()
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
    return IOClient(httpClient);
  }

  Future<Map<String, dynamic>> fetchProducts() async {
    return await fetchStorefront();
  }

  Future<Map<String, dynamic>> fetchStorefront() async {
    try {
      final client = _getUnsafeClient();
      final response = await client.get(
        Uri.parse(apiUrl),
        headers: {
          'Accept': 'application/json',
        },
      );
      
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
