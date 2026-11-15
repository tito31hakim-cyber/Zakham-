import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class QuizPage extends StatefulWidget {
  const QuizPage({super.key});

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  int step = 0;
  final questions = const [
    ('ما الأجواء التي تفضلها؟', ['دافئة وشرقية', 'نظيفة ومنعشة', 'ناعمة وزهرية']),
    ('متى سترتدي عطرك؟', ['في المناسبات', 'كل يوم', 'في المساء']),
    ('ما الانطباع الذي تريده؟', ['حضور قوي', 'أناقة هادئة', 'غموض لافت']),
  ];

  void next() {
    if (step < questions.length - 1) {
      setState(() => step++);
      return;
    }
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ترشيح زخم'),
        content: const Text('نرشح لك زَخَم رويال. سيتم تحسين الترشيحات مع اكتمال بيانات المنتجات.'),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('0${step + 1} / 03', style: const TextStyle(color: gold)),
              const SizedBox(height: 25),
              Text(question.$1, style: const TextStyle(color: cream, fontSize: 27, fontWeight: FontWeight.w600)),
              const SizedBox(height: 25),
              ...question.$2.map((option) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SizedBox(width: double.infinity, child: OutlinedButton(onPressed: next, child: Text(option, style: const TextStyle(color: cream)))),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
