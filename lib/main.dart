FutureBuilder<Map<String, dynamic>>(
  // التعديل هنا لكي يتوافق مع الكلاس بدون معاملات
  future: ProductApi().fetchProducts(),
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return Center(child: CircularProgressIndicator());
    } else if (snapshot.hasError) {
      return Center(child: Text('خطأ: ${snapshot.error}'));
    } else if (!snapshot.hasData || snapshot.data!['products'].isEmpty) {
      return Center(child: Text('لا توجد منتجات متاحة حالياً'));
    }

    final data = snapshot.data!;
    final products = data['products'];
    final settings = data['settings'];

    // واجهة عرض المنتجات والبيانات
    return ListView.builder(
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return ListTile(
          title: Text(product.name),
          subtitle: Text('${product.price} ر.س'),
        );
      },
    );
  },
)
