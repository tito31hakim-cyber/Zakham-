import 'package:flutter/material.dart';
import '../models/product.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.product, required this.onProduct, required this.onQuiz, required this.favorite, required this.onFavorite});
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
            padding: EdgeInsets.fromLTRB(22, 8, 22, 18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('دار زخم للعطور', style: TextStyle(color: gold, fontSize: 13, letterSpacing: 1.5)),
              SizedBox(height: 8),
              Text('هيبة حضور.\nأثر يبقى.', textAlign: TextAlign.right, style: TextStyle(color: cream, fontSize: 38, height: 1.2, fontWeight: FontWeight.w300)),
              SizedBox(height: 10),
              Text('عطور صُنعت لتكون جزءاً من حكايتك،\nوتترك أثراً لا يشبه سواك.', textAlign: TextAlign.right, style: TextStyle(color: muted, fontSize: 14, height: 1.8)),
            ]),
          ),
          HeroBanner(product: product, onTap: () => onProduct(product)),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 13, 20, 0),
            child: Row(children: [
              IconButton(onPressed: onFavorite, tooltip: favorite ? 'إزالة من المفضلة' : 'أضف للمفضلة', icon: Icon(favorite ? Icons.favorite : Icons.favorite_border, color: favorite ? Colors.redAccent : gold)),
              const Spacer(),
              TextButton(onPressed: () => onProduct(product), child: const Text('اكتشف زخم رويال', style: TextStyle(color: gold))),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
            child: Row(children: [
              TextButton(onPressed: onQuiz, child: const Text('ابدأ الاختبار', style: TextStyle(color: gold))),
              const Spacer(),
              const Text('اعثر على عطرك', style: TextStyle(color: cream, fontSize: 21, fontWeight: FontWeight.w600)),
            ]),
          ),
          QuizBanner(onTap: onQuiz),
          const Padding(padding: EdgeInsets.fromLTRB(20, 28, 20, 12), child: Text('اختيار زخم', textAlign: TextAlign.right, style: TextStyle(color: cream, fontSize: 21, fontWeight: FontWeight.w600))),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: ProductTile(product: product, onTap: () => onProduct(product), favorite: favorite, onFavorite: onFavorite)),
          const Padding(padding: EdgeInsets.fromLTRB(20, 28, 20, 12), child: Text('تجربة تليق بك', textAlign: TextAlign.right, style: TextStyle(color: cream, fontSize: 21, fontWeight: FontWeight.w600))),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 26),
            child: Row(children: [
              Expanded(child: _Promise(icon: Icons.local_shipping_outlined, title: 'توصيل لبابك', detail: 'في جميع أنحاء مصر')),
              SizedBox(width: 10),
              Expanded(child: _Promise(icon: Icons.verified_outlined, title: 'أصالة زخم', detail: 'تجربة عطرية موثوقة')),
              SizedBox(width: 10),
              Expanded(child: _Promise(icon: Icons.support_agent, title: 'نحن معك', detail: 'دعم قبل وبعد الطلب')),
            ]),
          ),
        ],
      );
}

class _Promise extends StatelessWidget {
  const _Promise({required this.icon, required this.title, required this.detail});
  final IconData icon;
  final String title;
  final String detail;
  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minHeight: 112),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
        child: Column(children: [Icon(icon, color: gold), const SizedBox(height: 8), Text(title, textAlign: TextAlign.center, style: const TextStyle(color: cream, fontSize: 12, fontWeight: FontWeight.w600)), const SizedBox(height: 4), Text(detail, textAlign: TextAlign.center, style: const TextStyle(color: muted, fontSize: 10))]),
      );
}
