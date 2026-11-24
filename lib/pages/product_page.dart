import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../providers/cart_provider.dart';
import '../services/product_share.dart';
import '../services/reviews_api.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class ProductPage extends StatefulWidget {
  const ProductPage({super.key, required this.product, required this.favorite, required this.onFavorite});
  final Product product;
  final bool favorite;
  final VoidCallback onFavorite;
  @override
  State<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  late bool favorite;
  late String _concentration;
  late int _sizeMl;
  bool _sharing = false;

  /// تقييمات العملاء من `/api/reviews` — تحميل best-effort لا يعطّل
  /// الصفحة أبداً.
  final ReviewsApi _reviewsApi = ReviewsApi();
  List<Review> _reviews = const <Review>[];
  ReviewSummary? _summary;

  @override
  void initState() {
    super.initState();
    favorite = widget.favorite;
    _concentration = widget.product.defaultConcentration;
    _sizeMl = widget.product.defaultSizeMl;
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    final results = await Future.wait([
      _reviewsApi.fetchReviews(widget.product.id),
      _reviewsApi.fetchSummary(),
    ]);
    if (!mounted) return;
    setState(() {
      _reviews = results[0] as List<Review>;
      final summaries = results[1] as Map<String, ReviewSummary>;
      _summary = summaries[widget.product.id];
    });
  }

  List<int> get _sizes => widget.product.availableSizes(_concentration);

  double get _unitPrice =>
      widget.product.priceFor(concentration: _concentration, sizeMl: _sizeMl) ??
      widget.product.price;

  void _selectConcentration(String concentration) {
    setState(() {
      _concentration = concentration;
      // النووي مثلاً بلا 30 مل؛ إن لم يتوفر الحجم الحالي نختار أول حجم متاح.
      if (!_sizes.contains(_sizeMl)) {
        _sizeMl = _sizes.isNotEmpty ? _sizes.first : widget.product.defaultSizeMl;
      }
    });
  }

  void _toggleFavorite() {
    widget.onFavorite();
    setState(() => favorite = !favorite);
  }

  /// مشاركة العطر (نص عربي + صورة العطر الحقيقية) — حارس ضد
  /// الضغط المزدوج أثناء فتح ورقة المشاركة.
  Future<void> _shareProduct() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      await ProductShare.share(widget.product);
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  void _addToCart() {
    final product = widget.product;
    if (!product.inStock) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('هذا المنتج غير متوفر حالياً.')));
      return;
    }
    context.read<CartProvider>().add(
      product,
      concentration: _concentration,
      sizeMl: _sizeMl,
    );
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('تمت إضافة ${product.name} — ${product.concentrationLabel(_concentration)} · $_sizeMl مل إلى السلة.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final concentrations = product.availableConcentrations;
    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل العطر'),
        actions: [
          IconButton(onPressed: _sharing ? null : _shareProduct, tooltip: 'مشاركة العطر', icon: Icon(Icons.share_outlined, color: context.goldText)),
          IconButton(onPressed: _toggleFavorite, tooltip: favorite ? 'إزالة من المفضلة' : 'أضف للمفضلة', icon: Icon(favorite ? Icons.favorite : Icons.favorite_border, color: favorite ? Colors.redAccent : context.goldText)),
        ],
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: ListView(children: [
          Stack(alignment: Alignment.bottomRight, children: [
            Image.network(product.image, height: 370, width: double.infinity, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(height: 370, color: const Color(0xFF32261E), child: const Center(child: Icon(Icons.spa_outlined, color: gold, size: 70)))),
            Container(height: 120, decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black87]))),
            Padding(padding: const EdgeInsets.all(22), child: Text(product.categoryLabel.toUpperCase(), style: const TextStyle(color: gold, letterSpacing: 2))),
          ]),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(product.name, textAlign: TextAlign.right, style: TextStyle(color: context.ink, fontSize: 32, fontWeight: FontWeight.w600)),
              if (product.nameEn.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(product.nameEn, textAlign: TextAlign.right, style: TextStyle(color: context.subdued, fontSize: 13, letterSpacing: 1.5)),
                ),
              const SizedBox(height: 10),
              Text(product.description.isEmpty ? 'هيبة الملوك ونفحات القصور الفاخرة، صُمم ليترك أثراً يليق بحضورك.' : product.description, textAlign: TextAlign.right, style: TextStyle(color: context.subdued, height: 1.8)),
              const SizedBox(height: 16),
              if (product.occasion.isNotEmpty || product.lasting.isNotEmpty)
                Wrap(spacing: 8, runSpacing: 8, children: [
                  if (product.occasion.isNotEmpty)
                    _InfoChip(icon: Icons.event_outlined, label: product.occasion),
                  if (product.lasting.isNotEmpty)
                    _InfoChip(icon: Icons.schedule_outlined, label: 'ثبات: ${product.lasting}'),
                ]),
              const SizedBox(height: 20),
              Text('التركيز', textAlign: TextAlign.right, style: TextStyle(color: context.ink, fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: concentrations.map((key) {
                final selected = key == _concentration;
                return ChoiceChip(
                  label: Text(product.concentrationLabel(key)),
                  selected: selected,
                  onSelected: (_) => _selectConcentration(key),
                  selectedColor: gold.withOpacity(.25),
                  labelStyle: TextStyle(color: selected ? context.goldText : context.ink, fontWeight: selected ? FontWeight.w700 : FontWeight.normal),
                );
              }).toList(growable: false)),
              const SizedBox(height: 16),
              Text('الحجم', textAlign: TextAlign.right, style: TextStyle(color: context.ink, fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              // صف أفقي واحد متساوٍ لكل الأحجام (لا سطران 2+1):
              // كل زر Expanded بعرض متساوٍ، والنص يتقلص قليلاً
              // (FittedBox) عند الحاجة حتى لا يفيض.
              Row(
                children: [
                  for (var i = 0; i < _sizes.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '${_sizes[i]} مل • ${(product.priceFor(concentration: _concentration, sizeMl: _sizes[i]) ?? 0).toStringAsFixed(0)} ${product.currency}',
                          ),
                        ),
                        selected: _sizes[i] == _sizeMl,
                        onSelected: (_) => setState(() => _sizeMl = _sizes[i]),
                        selectedColor: gold.withOpacity(.25),
                        labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                        labelStyle: TextStyle(color: _sizes[i] == _sizeMl ? context.goldText : context.ink, fontWeight: _sizes[i] == _sizeMl ? FontWeight.w700 : FontWeight.normal),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 20),
              Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: context.surfaceCard, borderRadius: BorderRadius.circular(16)), child: Row(children: [
                Text('${_unitPrice.toStringAsFixed(0)} ${product.currency}', style: TextStyle(color: context.goldText, fontSize: 21, fontWeight: FontWeight.bold)),
                const Spacer(),
                Text('$_sizeMl مل · ${product.concentrationLabel(_concentration)}', style: TextStyle(color: context.ink)),
                const SizedBox(width: 7),
                Icon(Icons.water_drop_outlined, color: context.goldText),
              ])),
              const SizedBox(height: 24),
              Text('الهرم العطري', textAlign: TextAlign.right, style: TextStyle(color: context.ink, fontSize: 20, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              NoteCard(title: 'المقدمة', notes: product.topNotes),
              NoteCard(title: 'القلب', notes: product.heartNotes),
              NoteCard(title: 'القاعدة', notes: product.baseNotes),
              const SizedBox(height: 14),
              Row(children: [Icon(Icons.verified_outlined, color: context.goldText, size: 19), const SizedBox(width: 8), Text(product.inStock ? 'متوفر وجاهز للطلب' : 'غير متوفر حالياً', style: TextStyle(color: product.inStock ? context.ink : context.subdued))]),
              const SizedBox(height: 20),
              SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: product.inStock ? _addToCart : null, icon: const Icon(Icons.add_shopping_cart), label: Text(product.inStock ? 'أضف إلى السلة' : 'غير متوفر'))),
              const SizedBox(height: 8),
              Text('رسوم التوصيل 120 ج.م لجميع المحافظات، والدفع مسبقاً عبر إنستاباي أو فودافون كاش.', textAlign: TextAlign.center, style: TextStyle(color: context.subdued, fontSize: 11)),
              const SizedBox(height: 26),
              _ReviewsSection(
                product: product,
                reviews: _reviews,
                summary: _summary,
                onSubmitted: _loadReviews,
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: context.surfaceCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.hairline),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: context.goldText, size: 15),
          const SizedBox(width: 6),
          Flexible(child: Text(label, style: TextStyle(color: context.ink, fontSize: 12))),
        ]),
      );
}

/// قسم «تقييمات العملاء» في صفحة العطر: متوسط النجوم وعدد التقييمات
/// من `/api/reviews/summary`، وقائمة المعتمَدة فقط من
/// `/api/reviews?productId=...`، ونموذج إرسال تقييم جديد (الاسم +
/// النجوم + التجربة + رقم الطلب اختيارياً للتوثيق). التقييم الجديد
/// يُحفظ بلا اعتماد فيُنشر بعد مراجعة الإدارة — ورسالة الخادم نفسها
/// تُعرض للمستخدم.
class _ReviewsSection extends StatefulWidget {
  const _ReviewsSection({
    required this.product,
    required this.reviews,
    required this.summary,
    required this.onSubmitted,
  });

  final Product product;
  final List<Review> reviews;
  final ReviewSummary? summary;
  final VoidCallback onSubmitted;

  @override
  State<_ReviewsSection> createState() => _ReviewsSectionState();
}

class _ReviewsSectionState extends State<_ReviewsSection> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _orderCodeController = TextEditingController();
  final ReviewsApi _api = ReviewsApi();
  int _rating = 5;
  bool _submitting = false;
  String? _message;
  bool _messageOk = false;

  @override
  void dispose() {
    _nameController.dispose();
    _commentController.dispose();
    _orderCodeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final name = _nameController.text.trim();
    final comment = _commentController.text.trim();
    if (name.length < 2) {
      setState(() {
        _message = 'الاسم مطلوب (حرفان على الأقل).';
        _messageOk = false;
      });
      return;
    }
    if (comment.length < 10) {
      setState(() {
        _message = 'اكتب تجربتك في 10 أحرف على الأقل.';
        _messageOk = false;
      });
      return;
    }
    setState(() {
      _submitting = true;
      _message = null;
    });
    final result = await _api.submitReview(
      productId: widget.product.id,
      customerName: name,
      rating: _rating,
      comment: comment,
      orderCode: _orderCodeController.text.trim(),
    );
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _message = result.message;
      _messageOk = result.ok;
      if (result.ok) {
        _nameController.clear();
        _commentController.clear();
        _orderCodeController.clear();
        _rating = 5;
      }
    });
    if (result.ok) widget.onSubmitted();
  }

  @override
  Widget build(BuildContext context) {
    final summary = widget.summary;
    final count = summary?.count ?? widget.reviews.length;
    final average = summary?.average ??
        (widget.reviews.isEmpty
            ? 0.0
            : widget.reviews
                    .map((review) => review.rating)
                    .reduce((a, b) => a + b) /
                widget.reviews.length);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'تقييمات العملاء',
          textAlign: TextAlign.right,
          style: TextStyle(
            color: context.ink,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        if (widget.reviews.isEmpty)
          Text(
            'كن أول من يشارك تجربته مع هذا العطر.',
            textAlign: TextAlign.right,
            style: TextStyle(color: context.subdued, height: 1.7),
          )
        else ...[
          Row(
            children: [
              _StarRow(rating: average.round(), size: 20),
              const SizedBox(width: 8),
              Text(
                average.toStringAsFixed(1),
                style: TextStyle(
                  color: context.goldText,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '($count ${count == 1 ? 'تقييم' : 'تقييماً'})',
                style: TextStyle(color: context.subdued, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...widget.reviews.map(
            (review) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.surfaceCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.hairline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          review.customerName,
                          style: TextStyle(
                            color: context.ink,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (review.verified)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: gold.withOpacity(.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified, color: gold, size: 13),
                              SizedBox(width: 4),
                              Text(
                                'عميل موثّق',
                                style: TextStyle(color: gold, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(width: 8),
                      _StarRow(rating: review.rating, size: 14),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    review.comment,
                    style: TextStyle(color: context.subdued, height: 1.7),
                  ),
                  if (review.createdAt.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      review.createdAt.length >= 10
                          ? review.createdAt.substring(0, 10)
                          : review.createdAt,
                      style: TextStyle(color: context.subdued, fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 14),
        Text(
          'شارك تجربتك',
          textAlign: TextAlign.right,
          style: TextStyle(
            color: context.ink,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(hintText: 'اسمك'),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Text('تقييمك: ', style: TextStyle(color: context.ink)),
            ...List.generate(
              5,
              (index) => IconButton(
                onPressed: () => setState(() => _rating = index + 1),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(
                  index < _rating ? Icons.star : Icons.star_border,
                  color: gold,
                  size: 28,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _commentController,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'اكتب تجربتك مع العطر (10 أحرف على الأقل)',
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _orderCodeController,
          decoration: const InputDecoration(
            hintText: 'رقم الطلب (اختياري — لتوثيق تقييمك)',
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _submitting ? null : _submit,
            child: Text(_submitting ? 'جارٍ الإرسال…' : 'أرسل تقييمك'),
          ),
        ),
        if (_message != null) ...[
          const SizedBox(height: 10),
          Text(
            _message!,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _messageOk ? context.goldText : Colors.redAccent,
              height: 1.7,
            ),
          ),
        ],
      ],
    );
  }
}

/// صف نجوم للعرض (متوسط أو تقييم واحد) — عدد ممتلئ حسب التقريب.
class _StarRow extends StatelessWidget {
  const _StarRow({required this.rating, this.size = 16});
  final int rating;
  final double size;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          5,
          (index) => Icon(
            index < rating.clamp(0, 5) ? Icons.star : Icons.star_border,
            color: gold,
            size: size,
          ),
        ),
      );
}
