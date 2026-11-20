import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../theme/app_theme.dart';

/// صفحة «ادعُ صديق» — برنامج الدعوة كما حدده صاحب الدار:
/// - المدعو يكسب 25 نقطة عند تسجيل حسابه.
/// - الداعي يكسب 25 نقطة عند تسليم أول طلب للمدعو.
/// - كود الدعوة الفريد لكل عميل (ZK + 6 أحرف/أرقام) يظهر في حسابه
///   على متجر زخم (صفحة الحساب على الموقع).
///
/// قيد موثّق: التطبيق لا يعرض الكود الشخصي بعد — لا حقل له في
/// نموذج العميل (Customer) ولا نقطة خادم تعيده للتطبيق (تحقّق
/// 2026-11-20: لا أثر لـ referral في lib/ كلها). الصفحة تعرض
/// البرنامج وتشارك رابط المتجر، ولا تخترع كوداً ولا نقطة خادم؛
/// عرض الكود الشخصي هنا يحتاج نقطة خادم جديدة (قرار صاحب الدار).

class ReferralPage extends StatelessWidget {
  const ReferralPage({super.key});

  static const _storeUrl = 'https://zakhamhouse.shop';

  /// نص المشاركة (يُختبر وحدوياً): شرح البرنامج + رابط المتجر.
  static String shareText() =>
      'ادعُ صديقك لدار زخم للعطور — يسجّل حساباً ويكسب 25 نقطة، '
      'وتكسب أنت 25 نقطة عند تسليم أول طلب له.\n$_storeUrl';

  Future<void> _share() async {
    await SharePlus.instance.share(
      ShareParams(text: shareText(), subject: 'ادعُ صديق لدار زخم'),
    );
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
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: gold.withOpacity(.10),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: gold.withOpacity(.35)),
                ),
                child: Text(
                  'كود الدعوة الخاص بك يظهر في حسابك على متجر زخم — انسخه من هناك وشاركه مع أصدقائك عند التسجيل.',
                  style: TextStyle(
                      color: context.ink, fontSize: 13, height: 1.8),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _share,
                icon: const Icon(Icons.share_outlined, size: 20),
                label: const Text('شارك رابط المتجر'),
              ),
            ],
          ),
        ),
      );

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
