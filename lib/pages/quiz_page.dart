import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class QuizPage extends StatefulWidget {
  const QuizPage({super.key});
  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  int step = 0;
  final List<int> answers = <int>[];
  final questions = const [
    ('ما الأجواء التي تفضلها؟', ['دافئة وشرقية', 'نظيفة ومنعشة', 'ناعمة وزهرية']),
    ('متى سترتدي عطرك؟', ['في المناسبات', 'كل يوم', 'في المساء']),
    ('ما الانطباع الذي تريده؟', ['حضور قوي', 'أناقة هادئة', 'غموض لافت']),
  ];

  void answer(int choice) {
    answers.add(choice);
    if (step < questions.length - 1) {
      setState(() => step++);
      return;
    }
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('اختيارك من زخم'),
        content: Text(
          'تفضل الأجواء ${questions[0].$2[answers[0]]}، وترتدي عطرك ${questions[1].$2[answers[1]]}، وتبحث عن ${questions[2].$2[answers[2]]}. نرشح لك زَخَم رويال كبداية لاكتشاف التشكيلة.',
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('حسنًا'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final question = questions[step];
    return Scaffold(
      appBar: AppBar(title: const Text('اختبار العطور')),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('0${step + 1} / 03', style: TextStyle(color: context.goldText)),
            const SizedBox(height: 12),
            ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: (step + 1) / questions.length, minHeight: 5, color: context.goldText, backgroundColor: context.hairline)),
            const SizedBox(height: 28),
            Text(question.$1, style: TextStyle(color: context.ink, fontSize: 27, fontWeight: FontWeight.w600)),
            const SizedBox(height: 25),
            ...List.generate(question.$2.length, (index) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SizedBox(width: double.infinity, child: OutlinedButton(onPressed: () => answer(index), child: Text(question.$2[index], style: TextStyle(color: context.ink)))),
                )),
          ]),
        ),
      ),
    );
  }
}
