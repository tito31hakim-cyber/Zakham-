import 'package:flutter/material.dart';

import '../models/product.dart';
import '../theme/app_theme.dart';

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
          ),
        ),
      );
}

class HeroBanner extends StatelessWidget {
  const HeroBanner({super.key, required this.product, required this.onTap});
  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
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
                product.image,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(color: const Color(0xFF32261E)),
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
              Positioned(
                right: 20,
                bottom: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('التشكيلة الرسمية', style: TextStyle(color: gold)),
                    Text(
                      product.name,
                      style: const TextStyle(color: cream, fontSize: 28),
                    ),
                    const Text('اكتشف العطر', style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class QuizBanner extends StatelessWidget {
  const QuizBanner({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: gold.withOpacity(.3)),
          ),
          child: const Row(
            children: [
              Icon(Icons.auto_awesome, color: gold, size: 34),
              SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('ثلاثة أسئلة فقط', style: TextStyle(color: gold, fontSize: 12)),
                    Text(
                      'اكتشف الرائحة الأقرب لك',
                      style: TextStyle(color: cream, fontSize: 17, fontWeight: FontWeight.w600),
                    ),
                    Text('نرشح لك عطراً يليق بذوقك', style: TextStyle(color: muted, fontSize: 12)),
                  ],
                ),
              ),
              Icon(Icons.arrow_back_ios_new, size: 16, color: gold),
            ],
          ),
        ),
      );
}

class ProductTile extends StatelessWidget {
  const ProductTile({
    super.key,
    required this.product,
    required this.onTap,
    required this.favorite,
    required this.onFavorite,
  });

  final Product product;
  final VoidCallback onTap;
  final bool favorite;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          height: 190,
          decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(20)),
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
                    children: [
                      Text(
                        product.name,
                        style: const TextStyle(color: cream, fontSize: 19, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        product.category.toUpperCase(),
                        style: const TextStyle(color: gold, fontSize: 10, letterSpacing: 1.5),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'عطر بحضور يترك أثراً.',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: const TextStyle(color: muted, fontSize: 12, height: 1.4),
                      ),
                      const Spacer(),
                      Text(
                        '${product.price.toStringAsFixed(0)} ${product.currency}',
                        style: const TextStyle(color: gold, fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
              ClipRRect(
                borderRadius: const BorderRadius.horizontal(right: Radius.circular(20)),
                child: Image.network(
                  product.image,
                  width: 120,
                  height: 190,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(width: 120, height: 190, color: const Color(0xFF32261E)),
                ),
              ),
            ],
          ),
        ),
      );
}

class ApiProductCard extends StatelessWidget {
  const ApiProductCard({super.key, required this.product, required this.onTap});
  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        color: card,
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: ListTile(
          onTap: onTap,
          leading: Image.network(
            product.image,
            width: 48,
            height: 48,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Icon(Icons.image_outlined, color: gold),
          ),
          title: Text(product.name, textAlign: TextAlign.right, style: const TextStyle(color: cream)),
          subtitle: Text(
            '${product.size} • ${product.price.toStringAsFixed(2)} ${product.currency}',
            textAlign: TextAlign.right,
            style: const TextStyle(color: gold),
          ),
          trailing: Icon(
            product.inStock ? Icons.check_circle_outline : Icons.remove_circle_outline,
            color: product.inStock ? Colors.green : Colors.redAccent,
          ),
        ),
      );
}

class NoteCard extends StatelessWidget {
  const NoteCard({super.key, required this.title, required this.notes});
  final String title;
  final List<String> notes;

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
            Expanded(
              child: Text(
                notes.isEmpty ? 'لا توجد بيانات بعد' : notes.join('، '),
                style: const TextStyle(color: muted, fontSize: 12),
              ),
            ),
            Text(title, style: const TextStyle(color: cream, fontWeight: FontWeight.w600)),
          ],
        ),
      );
}
