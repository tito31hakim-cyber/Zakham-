import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../providers/customer_provider.dart';
import '../services/customer_auth.dart';
import '../theme/app_theme.dart';
import 'auth_page.dart';

/// صفحة «ادعُ صديق» — برنامج الدعوة كما حدده صاحب الدار:
/// - المدعو يكسب 25 نقطة عند تسجيل حسابه.
/// - الداعي يكسب 25 نقطة عند تسليم أول طلب للمدعو.
/// - كود الدعوة الفريد لكل عميل (ZK + 6 أحرف/أرقام) يُجلب من نقطة
///   الخادم المنشورة `GET /api/account/referral-code` بمصادقة
///   العميل، ويُعرض مع زر نسخ ومشاركة رابط الدعوة.
/// - الضيف (بلا جلسة) يرى دعوة لتسجيل الدخول بدل الكود، وأي فشل
///   في الجلب يظهر رسالة واضحة مع زر إعادة المحاولة — الصفحة لا
///   تنكسر أبداً ولا تخترع كوداً.

class ReferralPage extends StatefulWidget {
  const ReferralPage({super.key});

  static const _storeUrl = 'https://zakhamhouse.shop';

  /// نص المشاركة (يُختبر وحدوياً): شرح البرنامج + رابط المتجر.
  static String shareText() =>
      'ادعُ صديقك لدار زخم للعطور — يسجّل حساباً ويكسب 25 نقطة، '
      'وتكسب أنت 25 نقطة عند تسليم أول طلب له.\n$_storeUrl';

  /// نص مشاركة رابط الدعوة (يُختبر وحدوياً): البرنامج + الكود
  /// الشخصي + رابط الدعوة الكامل.
  static String referralShareText(ReferralCode referral) =>
      'ادعُ صديقك لدار زخم للعطور — يسجّل حساباً ويكسب 25 نقطة، '
      'وتكسب أنت 25 نقطة عند تسليم أول طلب له.\n'
      'كود الدعوة: ${referral.code}\n${referral.link}';

  @override
  State<ReferralPage> createState() => _ReferralPageState();
}

enum _ReferralState { loading, loaded, guest, error }

class _ReferralPageState extends State<ReferralPage> {
  var _state = _ReferralState.loading;
  ReferralCode? _referral;
  String _errorMessage = '';
  var _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _state = _ReferralState.loading;
      _errorMessage = '';
    });
    try {
      final referral =
          await context.read<CustomerProvider>().fetchReferralCode();
      if (!mounted) return;
      setState(() {
        _referral = referral;
        _state = _ReferralState.loaded;
      });
    } on AuthRequiredException {
      if (!mounted) return;
      setState(() => _state = _ReferralState.guest);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _state = _ReferralState.error;
      });
    }
  }

  Future<void> _shareStore() async {
    await SharePlus.instance.share(
      ShareParams(text: ReferralPage.shareText(), subject: 'ادعُ صديق لدار زخم'),
    );
  }

  Future<void> _shareReferral() async {
    final referral = _referral;
    if (referral == null) return;
    await SharePlus.instance.share(
      ShareParams(
        text: ReferralPage.referralShareText(referral),
        subject: 'ادعُ صديق لدار زخم',
      ),
    );
  }

  Future<void> _copyCode() async {
    final referral = _referral;
    if (referral == null) return;
    await Clipboard.setData(ClipboardData(text: referral.code));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم نسخ كود الدعوة.')),
    );
  }

  Future<void> _openLogin() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const CustomerLoginPage()),
    );
    if (!mounted) return;
    // بعد عودة الضيف من الدخول يُعاد الجلب: إن سجّل دخوله يظهر
    // كوده، وإن رجع بلا دخول تبقى حالة الضيف.
    await _load();
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(title: const Text('ادعُ صديق')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 26),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.surfaceCard,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: context.hairline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.group_add_outlined,
                            color: context.goldText, size: 22),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'ادعُ صديق واكسبا معاً',
                            style: TextStyle(
                              color: context.ink,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'شارك دار زخم مع أصدقائك — صديقك يكسب 25 نقطة عند تسجيل حسابه، وأنت تكسب 25 نقطة عند تسليم أول طلب له.',
                      style: TextStyle(
                          color: context.subdued, fontSize: 13, height: 1.8),
                    ),
                    const SizedBox(height: 12),
                    _rule(context, 'صديقك يكسب 25 نقطة عند التسجيل.'),
                    const SizedBox(height: 6),
                    _rule(context, 'أنت تكسب 25 نقطة عند تسليم أول طلب له.'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _codeCard(context),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _shareStore,
                icon: const Icon(Icons.share_outlined, size: 20),
                label: const Text('شارك رابط المتجر'),
              ),
            ],
          ),
        ),
      );

  Widget _codeCard(BuildContext context) {
    switch (_state) {
      case _ReferralState.loading:
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.surfaceCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.hairline),
          ),
          child: const Center(child: CircularProgressIndicator()),
        );
      case _ReferralState.loaded:
        final referral = _referral!;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: gold.withOpacity(.10),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: gold.withOpacity(.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'كود الدعوة الخاص بك',
                style: TextStyle(
                  color: context.ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      referral.code,
                      textDirection: TextDirection.ltr,
                      style: TextStyle(
                        color: context.goldText,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonalIcon(
                    onPressed: _copyCode,
                    icon: const Icon(Icons.copy_outlined, size: 18),
                    label: const Text('نسخ الكود'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SelectableText(
                referral.link,
                textDirection: TextDirection.ltr,
                style: TextStyle(
                    color: context.subdued, fontSize: 12, height: 1.6),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _shareReferral,
                icon: const Icon(Icons.share_outlined, size: 20),
                label: const Text('شارك رابط الدعوة'),
              ),
            ],
          ),
        );
      case _ReferralState.guest:
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.surfaceCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'سجّل الدخول لعرض كود الدعوة الخاص بك.',
                style: TextStyle(
                    color: context.ink, fontSize: 13, height: 1.8),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _openLogin,
                icon: const Icon(Icons.login, size: 20),
                label: const Text('تسجيل الدخول'),
              ),
            ],
          ),
        );
      case _ReferralState.error:
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.surfaceCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _errorMessage.isEmpty
                    ? 'تعذّر تحميل كود الدعوة حالياً.'
                    : _errorMessage,
                style: TextStyle(
                    color: context.ink, fontSize: 13, height: 1.8),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh, size: 20),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        );
    }
  }

  Widget _rule(BuildContext context, String text) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle_outline,
              color: context.goldText, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style:
                  TextStyle(color: context.ink, fontSize: 13, height: 1.7),
            ),
          ),
        ],
      );
}
