import 'package:flutter/material.dart';
import 'services/product_api.dart';
import 'models/product.dart';

void main() {
  runApp(const ZakhamApp());
}

class ZakhamApp extends StatelessWidget {
  const ZakhamApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'دار زَخَم',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.brown,
        scaffoldBackgroundColor: const Color(0xFF121212),
      ),
      home: const StorefrontScreen(),
    );
  }
}

class StorefrontScreen extends StatelessWidget {
  const StorefrontScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('دار زَخَم | ZAKHAM HOUSE', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        centerTitle: true,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: ProductApi().fetchProducts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.amber));
          } else if (snapshot.hasError) {
            return Center(
              child: Text(
                'خطأ في الاتصال: ${snapshot.error}',
                style: const TextStyle(color: Colors.white70),
              ),
            );
          } else if (!snapshot.hasData || snapshot.data!['products'].isEmpty) {
            return const Center(
              child: Text(
                'لا توجد منتجات متاحة حالياً',
                style: TextStyle(color: Colors.white70),
              ),
            );
          }

          final data = snapshot.data!;
          final products = data['products'] as List<Product>;

          return ListView.builder(
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              return Card(
                color: const Color(0xFF1E1E1E),
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: const Icon(Icons.shopping_bag, color: Colors.amber),
                  title: Text(
                    product.name,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${product.price} ر.س',
                    style: const TextStyle(color: Colors.amberAccent),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
