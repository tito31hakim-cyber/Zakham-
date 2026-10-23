import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models/product.dart';
import 'pages/checkout_page.dart';
import 'pages/admin_page.dart';
import 'pages/contact_page.dart';
import 'providers/cart_provider.dart';

import 'services/product_api.dart';

void main() => runApp(
  ChangeNotifierProvider(
    create: (_) => CartProvider(),
    child: const ZakhamApp(),
  ),
);

const gold = Color(0xFFC9A45C);
const cream = Color(0xFFF5EFE5);
const muted = Color(0xFF9D978E);
const card = Color(0xFF171615);
const productImage =
    'https://zakhamhouse.shop/assets/products/catalog-royal-2026.jpg';
const apiBaseUrl = 'https://zakhamhouse.shop/mobile-api/products.json';

class ZakhamApp extends StatelessWidget {
  const ZakhamApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'House of Zakham',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B0B0B),
        colorScheme: ColorScheme.fromSeed(
          seedColor: gold,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const StoreHome(),
    );
  }
}

class StoreHome extends StatefulWidget {
  const StoreHome({super.key});
  @override
  State<StoreHome> createState() => _StoreHomeState();
}

class _StoreHomeState extends State<StoreHome> {
  int selected = 0;
  bool favorite = false;
  void openProduct() => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ProductPage(
        favorite: favorite,
        onFavorite: () => setState(() => favorite = !favorite),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomePage(
        onProduct: openProduct,
        onQuiz: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const QuizPage()),
        ),
        favorite: favorite,
        onFavorite: () => setState(() => favorite = !favorite),
      ),
      CollectionPage(
        onProduct: openProduct,
        favorite: favorite,
        onFavorite: () => setState(() => favorite = !favorite),
      ),
      favorite
          ? ProductTile(
              onTap: openProduct,
              favorite: true,
              onFavorite: () => setState(() => favorite = false),
            )
          : const Center(
              child: Text('لم تحفظ أي عطر بعد', style: TextStyle(color: muted)),
            ),
      const AccountPage(),
    ];
    return Scaffold(
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: pages[selected],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected,
        onDestinationSelected: (value) => setState(() => selected = value),
        backgroundColor: const Color(0xFF101010),
        indicatorColor: gold.withOpacity(.2),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: gold),
            label: 'الرئيسية',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view_rounded),
            selectedIcon: Icon(Icons.grid_view, color: gold),
            label: 'التشكيلة',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_border),
            selectedIcon: Icon(Icons.favorite, color: gold),
            label: 'المفضلة',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: gold),
            label: 'حسابي',
          ),
        ],
      ),
    );
  }
}

class Header extends StatelessWidget {
  const Header({super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
    child: SizedBox(
      height: 112,
      width: double.infinity,
      child: Image.asset(
        'assets/brand/zakham-house-logo.png',
        fit: BoxFit.contain,
        alignment: Alignment.center,
      ),
    ),
  );
}

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.onProduct,
    required this.onQuiz,
    required this.favorite,
    required this.onFavorite,
  });
  final VoidCallback onProduct, onQuiz, onFavorite;
  final bool favorite;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        const Header(),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 15, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('هيبة حضور.', style: TextStyle(color: gold, fontSize: 16)),
              Text(
                'أثر يبقى.',
                style: TextStyle(
                  color: cream,
                  fontSize: 38,
                  fontWeight: FontWeight.w300,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'عطور بحضور تترك أثراً. اكتشف بصمتك من توليفات زخم.',
                style: TextStyle(color: muted, fontSize: 14, height: 1.7),
              ),
            ],
          ),
        ),
        HeroBanner(onTap: onProduct),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
          child: Row(
            children: [
              TextButton(
                onPressed: onQuiz,
                child: const Text(
                  'ابدأ الاختبار',
                  style: TextStyle(color: gold),
                ),
              ),
              const Spacer(),
              const Text(
                'اعثر على عطرك',
                style: TextStyle(
                  color: cream,
                  fontSize: 21,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        QuizBanner(onTap: onQuiz),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 28, 20, 12),
          child: Text(
            'اختيار زخم',
            style: TextStyle(
              color: cream,
              fontSize: 21,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ProductTile(
            onTap: onProduct,
            favorite: favorite,
            onFavorite: onFavorite,
          ),
        ),
        const SizedBox(height: 28),
      ],
    );
  }
}

class HeroBanner extends StatelessWidget {
  const HeroBanner({super.key, required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 280,
        margin: const EdgeInsets.symmetric(horizontal: 20),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(24)),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              productImage,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  Container(color: const Color(0xFF32261E)),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black],
                ),
              ),
            ),
            const Positioned(
              right: 20,
              bottom: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('التشكيلة الرسمية', style: TextStyle(color: gold)),
                  Text(
                    'زَخَم رويال',
                    style: TextStyle(color: cream, fontSize: 28),
                  ),
                  Text('اكتشف العطر', style: TextStyle(color: Colors.white70)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class QuizBanner extends StatelessWidget {
  const QuizBanner({super.key, required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: gold.withOpacity(.3)),
        ),
        child: Row(
          children: const [
            Icon(Icons.auto_awesome, color: gold, size: 34),
            SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'ثلاثة أسئلة فقط',
                    style: TextStyle(color: gold, fontSize: 12),
                  ),
                  Text(
                    'اكتشف الرائحة الأقرب لك',
                    style: TextStyle(
                      color: cream,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'نرشح لك عطراً يليق بذوقك',
                    style: TextStyle(color: muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_back_ios_new, size: 16, color: gold),
          ],
        ),
      ),
    );
  }
}

class CollectionPage extends StatelessWidget {
  const CollectionPage({
    super.key,
    required this.onProduct,
    required this.favorite,
    required this.onFavorite,
  });
  final VoidCallback onProduct, onFavorite;
  final bool favorite;
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        const Header(),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 15, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'التشكيلة',
                style: TextStyle(
                  color: cream,
                  fontSize: 30,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'اختر أثرك من عطور زخم الرسمية',
                style: TextStyle(color: muted),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ProductTile(
            onTap: onProduct,
            favorite: favorite,
            onFavorite: onFavorite,
          ),
        ),
        const SizedBox(height: 24),
        FutureBuilder<List<Product>>(
          future: ProductApi(baseUrl: apiBaseUrl).fetchProducts(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(28),
                child: Center(child: CircularProgressIndicator(color: gold)),
              );
            }
            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'تعذر جلب المنتجات من API حالياً: ${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: muted),
                ),
              );
            }
            final products = snapshot.data ?? const <Product>[];
            if (products.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'لا توجد منتجات في استجابة API.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: muted),
                ),
              );
            }
            return Column(
              children: products
                  .map(
                    (product) =>
                        ApiProductCard(product: product, onTap: onProduct),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}

class ApiProductCard extends StatelessWidget {
  const ApiProductCard({super.key, required this.product, required this.onTap});
  final Product product;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Card(
      color: card,
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: ListTile(
        onTap: onTap,
        leading: product.image.endsWith('.svg')
            ? const Icon(Icons.image_outlined, color: gold)
            : Image.network(
                product.image,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
              ),
        title: Text(
          product.name,
          textAlign: TextAlign.right,
          style: const TextStyle(color: cream),
        ),
        subtitle: Text(
          '${product.size} • ${product.price.toStringAsFixed(2)} ${product.currency}',
          textAlign: TextAlign.right,
          style: const TextStyle(color: gold),
        ),
        trailing: Icon(
          product.inStock
              ? Icons.check_circle_outline
              : Icons.remove_circle_outline,
          color: product.inStock ? Colors.green : Colors.redAccent,
        ),
      ),
    );
  }
}

class ProductTile extends StatelessWidget {
  const ProductTile({
    super.key,
    required this.onTap,
    required this.favorite,
    required this.onFavorite,
  });
  final VoidCallback onTap, onFavorite;
  final bool favorite;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 190,
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: onFavorite,
              icon: Icon(
                favorite ? Icons.favorite : Icons.favorite_border,
                color: favorite ? Colors.redAccent : gold,
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: const [
                    Text(
                      'زَخَم رويال',
                      style: TextStyle(
                        color: cream,
                        fontSize: 19,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'ZAKHAM ROYAL',
                      style: TextStyle(
                        color: gold,
                        fontSize: 10,
                        letterSpacing: 1.5,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'هيبة الملوك ونفحات القصور الفاخرة، صُمم للمناسبات الرسمية الكبرى.',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: TextStyle(color: muted, fontSize: 12, height: 1.4),
                    ),
                    Spacer(),
                    Text(
                      '500 ج.م',
                      style: TextStyle(
                        color: gold,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                right: Radius.circular(20),
              ),
              child: Image.network(
                productImage,
                width: 120,
                height: 190,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 120,
                  height: 190,
                  color: const Color(0xFF32261E),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProductPage extends StatelessWidget {
  const ProductPage({
    super.key,
    required this.favorite,
    required this.onFavorite,
  });
  final bool favorite;
  final VoidCallback onFavorite;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            onPressed: onFavorite,
            icon: Icon(
              favorite ? Icons.favorite : Icons.favorite_border,
              color: gold,
            ),
          ),
        ],
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: ListView(
          children: [
            Image.network(
              productImage,
              height: 330,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  Container(height: 330, color: const Color(0xFF32261E)),
            ),
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'ZAKHAM ROYAL',
                    style: TextStyle(color: gold, letterSpacing: 2),
                  ),
                  const Text(
                    'زَخَم رويال',
                    style: TextStyle(
                      color: cream,
                      fontSize: 32,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'هيبة الملوك ونفحات القصور الفاخرة، صُمم لليالي الشتوية والمناسبات الرسمية الكبرى.',
                    style: TextStyle(color: muted, height: 1.8),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'الهرم العطري',
                    style: TextStyle(
                      color: cream,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Note(title: 'المقدمة'),
                  const Note(title: 'القلب'),
                  const Note(title: 'القاعدة'),
                  const SizedBox(height: 16),
                  const Text(
                    'الأحجام والأسعار الرسمية ستظهر تلقائياً بعد ربط API المتجر.',
                    style: TextStyle(color: muted),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.add_shopping_cart),
                      label: const Text('أضف إلى السلة'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class Note extends StatelessWidget {
  const Note({super.key, required this.title});
  final String title;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      border: Border.all(color: Colors.white10),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        const Icon(Icons.circle, color: gold, size: 8),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            'تُزامن بيانات هذه النوتة من API المتجر',
            style: TextStyle(color: muted, fontSize: 12),
          ),
        ),
        Text(
          title,
          style: const TextStyle(color: cream, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
}

class QuizPage extends StatefulWidget {
  const QuizPage({super.key});
  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  int step = 0;
  final questions = const [
    (
      'ما الأجواء التي تفضلها؟',
      ['دافئة وشرقية', 'نظيفة ومنعشة', 'ناعمة وزهرية'],
    ),
    ('متى سترتدي عطرك؟', ['في المناسبات', 'كل يوم', 'في المساء']),
    ('ما الانطباع الذي تريده؟', ['حضور قوي', 'أناقة هادئة', 'غموض لافت']),
  ];
  void next() {
    if (step < 2) {
      setState(() => step++);
      return;
    }
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ترشيح زخم'),
        content: const Text(
          'نرشح لك زَخَم رويال. سيتم تحسين الترشيحات مع اكتمال بيانات المنتجات.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('حسنًا'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = questions[step];
    return Scaffold(
      appBar: AppBar(title: const Text('اختبار العطور')),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('0${step + 1} / 03', style: const TextStyle(color: gold)),
              const SizedBox(height: 25),
              Text(
                q.$1,
                style: const TextStyle(
                  color: cream,
                  fontSize: 27,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 25),
              ...q.$2.map(
                (option) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: next,
                      child: Text(option, style: const TextStyle(color: cream)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AccountPage extends StatelessWidget {
  const AccountPage({super.key});
  @override
  Widget build(BuildContext context) => ListView(
    padding: EdgeInsets.zero,
    children: [
      const Header(),
      Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'حسابي',
              style: TextStyle(
                color: cream,
                fontSize: 30,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'سجّل دخولك لمتابعة طلباتك ومفضلاتك.',
              style: TextStyle(color: muted),
            ),
            SizedBox(height: 30),
            Text('تسجيل الدخول', style: TextStyle(color: cream, fontSize: 16)),
            SizedBox(height: 22),
            Text('طلباتي', style: TextStyle(color: cream, fontSize: 16)),
            SizedBox(height: 22),
            Text(
              'إشعارات العروض',
              style: TextStyle(color: cream, fontSize: 16),
            ),
            SizedBox(height: 22),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.shopping_bag_outlined, color: gold),
              title: Text(
                'سلة المشتريات',
                style: TextStyle(color: cream, fontSize: 16),
              ),
              trailing: Icon(Icons.arrow_back_ios_new, color: gold, size: 16),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CheckoutPage()),
              ),
            ),
            SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.admin_panel_settings_outlined, color: gold),
              title: Text(
                'لوحة الإدارة',
                style: TextStyle(color: cream, fontSize: 16),
              ),
              trailing: Icon(Icons.arrow_back_ios_new, color: gold, size: 16),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminLoginPage()),
              ),
            ),
            SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.forum_outlined, color: gold),
              title: Text(
                'تواصل مع زخم',
                style: TextStyle(color: cream, fontSize: 16),
              ),
              trailing: Icon(Icons.arrow_back_ios_new, color: gold, size: 16),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ContactPage()),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
