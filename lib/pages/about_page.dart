import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'contact_page.dart';

/// هوية زخم — محتوى صفحة /about-zakham من المتجر نفسه حرفياً:
/// معنى الاسم، والأبعاد الثلاثة، ووعد الدار. بلا أي ادعاء جديد.
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('هوية زخم')),
        body: ListView(
          padding: const EdgeInsets.all(22),
          children: [
            Text(
              'THE ZAKHAM IDENTITY · دار زخم',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: context.goldText,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'حضورٌ له أثره.',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: context.ink,
                fontSize: 30,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            _body(
              context,
              'في دار زخم، نرى العطر أكثر من رائحة؛ إنه توقيعٌ شخصي يسبق '
              'الكلام، ويمنح اللحظة نبرةً تبقى في الذاكرة.',
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: const [
                _WordChip('ذوق'),
                _WordChip('هوية'),
                _WordChip('أثر'),
              ],
            ),
            const SizedBox(height: 28),
            Text(
              'ZAKHAM HOUSE · THE ART OF PRESENCE',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: context.goldText,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'من أول نفحة، تبدأ الحكاية.',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: context.ink,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            _body(
              context,
              'نصوغ تجربة عطرية معاصرة تستلهم مكانة العطر في ثقافتنا '
              'العربية، وتمنحك مساحة لاختيار النغمة التي تعبّر عن حضورك.',
            ),
            const SizedBox(height: 8),
            _body(
              context,
              'تبدأ التجربة من اكتشاف التشكيلة، وتمتد إلى تفاصيل التقديم '
              'والتواصل؛ بذوقٍ هادئ يترك للعطر أن يتحدث.',
            ),
            const SizedBox(height: 28),
            _sectionTitle(context, 'ما معنى زخم؟'),
            const SizedBox(height: 4),
            Text(
              'زَخْم · ZAKHAM',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: context.goldText,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            _body(
              context,
              'لغويًا، الزخم هو قوة الدفع التي تمنح الحركة اندفاعها '
              'واستمرارها. وفي هوية الدار، نقرأه مجازًا لحضورٍ واثق: لافتٌ '
              'بلا صخب، ومتزنٌ بلا مبالغة، وأثرٌ لا يمرّ عابرًا.',
            ),
            const SizedBox(height: 8),
            _body(
              context,
              'هكذا نريد لزخم أن يكون؛ عطرًا يعبّر عنك، ويترك في الذاكرة '
              'ما هو أعمق من الانطباع الأول.',
            ),
            const SizedBox(height: 28),
            _sectionTitle(context, 'ثلاثة أبعاد، هوية واحدة.'),
            const SizedBox(height: 8),
            _body(
              context,
              'تفاصيل صغيرة تصنع إحساسًا كاملًا — من الرائحة التي تختارها '
              'إلى الطريقة التي تصل بها إليك.',
            ),
            const SizedBox(height: 16),
            _dimension(
              context,
              '01 / SIGNATURE',
              'لكلّ عطر شخصية',
              'نمنح كل نغمة مساحتها، ونترك لك حرية اختيار ما يشبه ذوقك '
              'ويواكب لحظتك.',
            ),
            _dimension(
              context,
              '02 / PRESENCE',
              'حضورٌ بلا مبالغة',
              'الفخامة عندنا توازنٌ في الإحساس، ووضوحٌ في التفاصيل، '
              'وثقةٌ لا تحتاج إلى ضجيج.',
            ),
            _dimension(
              context,
              '03 / EXPERIENCE',
              'التجربة امتداد للعطر',
              'من اكتشاف التشكيلة إلى الإهداء والتواصل، نعتني بانسجام '
              'التجربة مع هوية زخم.',
            ),
            const SizedBox(height: 28),
            _sectionTitle(context, 'تفاصيلٌ تُختار بعناية، وأثرٌ يستحق البقاء.'),
            const SizedBox(height: 8),
            _body(
              context,
              'اكتشف عالم زخم، واختر العطر الذي يعبّر عنك — أو تواصل معنا '
              'لنساعدك في اختيار هدية تليق بلحظتها.',
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _trustChip(
                  context,
                  Icons.local_shipping_outlined,
                  'شحن سريع لجميع محافظات الجمهورية',
                ),
                _trustChip(
                  context,
                  Icons.payment_outlined,
                  'دفع إلكتروني متاح',
                ),
                _trustChip(
                  context,
                  Icons.verified_outlined,
                  'الضمان الذهبي لنقاء الزيوت والجودة',
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: gold,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ContactPage(),
                  ),
                ),
                child: const Text(
                  'تواصل مع دار زخم',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'دار عطور عربية فاخرة — زيوت عطرية نقية بتغليف ملكي وشحن '
              'سريع لجميع محافظات مصر.',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.subdued, height: 1.7),
            ),
            const SizedBox(height: 4),
            Text(
              'صُنع بحب من أجل إظهار الفخامة والهيبة',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.goldText, height: 1.7),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String text) => Text(
        text,
        textAlign: TextAlign.right,
        style: TextStyle(
          color: context.ink,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      );

  Widget _body(BuildContext context, String text) => Text(
        text,
        textAlign: TextAlign.right,
        style: TextStyle(color: context.subdued, height: 1.7),
      );

  Widget _dimension(
    BuildContext context,
    String eyebrow,
    String title,
    String body,
  ) =>
      Card(
        color: context.surfaceCard,
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                eyebrow,
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: context.goldText,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                title,
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: context.ink,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              _body(context, body),
            ],
          ),
        ),
      );

  Widget _trustChip(BuildContext context, IconData icon, String label) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: context.surfaceCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.hairline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: context.goldText),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(color: context.ink, fontSize: 12),
              ),
            ),
          ],
        ),
      );
}

class _WordChip extends StatelessWidget {
  const _WordChip(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: gold.withOpacity(.6)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: context.goldText,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
}
