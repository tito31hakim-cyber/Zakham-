import 'package:flutter/material.dart';

import '../data/fragrance_cards.dart';
import '../theme/app_theme.dart';

/// أشرطة المحاور الخمسة — من درجات البطاقة العطرية (`extra.stats`)،
/// نفس مصدر صفحة «البطاقات العطرية» وبالترتيب نفسه
/// (الثبات، الفوحان، الدفء، الانتعاش، الهيبة).
///
/// بلا أي قيم مخترعة هنا: الدرجات كما هي في بيانات البطاقات؛ وإن
/// كانت قيماً افتراضية لعطر من العطور الثلاثة الجديدة (ليل، إلكسير،
/// سلطان) يُمرَّر `valuesAreDefaults: true` فيظهر التنويه.
class IdentityAxes extends StatelessWidget {
  const IdentityAxes({
    super.key,
    required this.stats,
    this.valuesAreDefaults = false,
  });

  final List<int> stats;

  /// الدرجات المعروضة افتراضية من نصوص المتجر (بانتظار اعتماد الدار).
  final bool valuesAreDefaults;

  @override
  Widget build(BuildContext context) {
    final values = List<int>.from(stats);
    while (values.length < radarAxes.length) {
      values.add(0);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < radarAxes.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 64,
                  child: Text(
                    radarAxes[i],
                    style: TextStyle(color: context.ink, fontSize: 13),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: (values[i].clamp(0, 100)) / 100,
                      minHeight: 7,
                      color: context.goldText,
                      backgroundColor: context.hairline,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 28,
                  child: Text(
                    '${values[i]}',
                    textAlign: TextAlign.left,
                    style: TextStyle(color: context.subdued, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        if (valuesAreDefaults)
          Text(
            'درجات المحاور لهذا العطر قيم افتراضية من نصوص المتجر، بانتظار اعتماد الدار.',
            style: TextStyle(color: context.subdued, fontSize: 12, height: 1.6),
          ),
      ],
    );
  }
}
