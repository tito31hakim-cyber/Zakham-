import 'package:flutter/material.dart';

import '../models/product.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.product,
    required this.onProduct,
    required this.onQuiz,
    required this.favorite,
    required this.onFavorite,
  });

  final Product product;
  final ValueChanged<Product> onProduct;
  final VoidCallback onQuiz;
  final bool favorite;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) => ListView(
        padding: EdgeInsets.zero,
        children: [
          const Header(),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 15, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('هيبة حضور.', style: TextStyle(color: gold, fontSize: 16)),
                Text('أثر يبقى.', style: TextStyle(color: cream, fontSize: 38, fontWeight: FontWeight.w300)),
                SizedBox(height: 10),
                Text(
                  'عطور بحضور تترك أثراً. اكتشف بصمتك من توليفات زخم.',
                  style: TextStyle(color: muted, fontSize: 14, height: 1.7),
                ),
              ],
            ),
          ),
          HeroBanner(product: product, onTap: () => onProduct(product)),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
            child: Row(
              children: [
                TextButton(onPressed: onQuiz, child: const Text('ابدأ الاختبار', style: TextStyle(color: gold))),
                const Spacer(),
                const Text('اعثر على عطرك', style: TextStyle(color: cream, fontSize: 21, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          QuizBanner(onTap: onQuiz),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 28, 20, 12),
            child: Text('اختيار زخم', style: TextStyle(color: cream, fontSize: 21, fontWeight: FontWeight.w600)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ProductTile(product: product, onTap: () => onProduct(product), favorite: favorite, onFavorite: onFavorite),
          ),
          const SizedBox(height: 28),
        ],
      );
}
