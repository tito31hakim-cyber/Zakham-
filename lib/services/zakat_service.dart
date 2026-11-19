import 'package:shared_preferences/shared_preferences.dart';

/// زكاة التجارة — حساب تقديري محلي فقط.
///
/// القاعدة: 2.5% من صافي أموال التجارة الخاضعة للزكاة:
///   نقدية + قيمة المخزون بسعر السوق + مستحقات للدار − ديون عليها
/// وتُستحق عند بلوغ النصاب وتمام الحول (سنة هجرية من تاريخ البداية).
///
/// كل الأرقام يدخلها المالك بنفسه وتُحفظ على الجهاز فقط
/// (SharedPreferences)؛ لا تُرسل لأي خادم ولا تظهر في أي تقرير.
/// الحساب تقديري ويراجعه المالك بنفسه؛ والزكاة ليست على الإيرادات
/// فلا تُحسب من المبيعات.
class ZakatInputs {
  const ZakatInputs({
    required this.cash,
    required this.inventoryValue,
    required this.receivables,
    required this.debts,
    required this.hawlStart,
    required this.nisab,
  });

  /// النقدية المتوفرة للتجارة (جنيه).
  final double cash;

  /// قيمة المخزون بسعر السوق الحالي (جنيه).
  final double inventoryValue;

  /// مستحقات للدار على الغير (جنيه).
  final double receivables;

  /// ديون على الدار للغير (جنيه).
  final double debts;

  /// تاريخ بداية الحول.
  final DateTime hawlStart;

  /// قيمة النصاب التي يحددها المالك (جنيه).
  final double nisab;

  /// صافي الأموال الخاضعة للزكاة.
  double get zakatableBase => cash + inventoryValue + receivables - debts;

  Map<String, dynamic> toJson() => {
        'cash': cash,
        'inventoryValue': inventoryValue,
        'receivables': receivables,
        'debts': debts,
        'hawlStart': hawlStart.toIso8601String(),
        'nisab': nisab,
      };

  static ZakatInputs? fromJson(Map<String, dynamic> json) {
    final cash = (json['cash'] as num?)?.toDouble();
    final inventory = (json['inventoryValue'] as num?)?.toDouble();
    final receivables = (json['receivables'] as num?)?.toDouble();
    final debts = (json['debts'] as num?)?.toDouble();
    final nisab = (json['nisab'] as num?)?.toDouble();
    final hawlStart = DateTime.tryParse('${json['hawlStart'] ?? ''}');
    if (cash == null ||
        inventory == null ||
        receivables == null ||
        debts == null ||
        nisab == null ||
        hawlStart == null) {
      return null;
    }
    return ZakatInputs(
      cash: cash,
      inventoryValue: inventory,
      receivables: receivables,
      debts: debts,
      hawlStart: hawlStart,
      nisab: nisab,
    );
  }
}

/// نتيجة حساب زكاة التجارة.
class ZakatResult {
  const ZakatResult({
    required this.inputs,
    required this.base,
    required this.hawlEnd,
    required this.hawlComplete,
    required this.nisabReached,
    required this.due,
  });

  final ZakatInputs inputs;

  /// صافي الأموال الخاضعة.
  final double base;

  /// تاريخ تمام الحول.
  final DateTime hawlEnd;

  /// هل تم الحول؟
  final bool hawlComplete;

  /// هل بلغ الصافي النصاب؟
  final bool nisabReached;

  /// الزكاة المستحقة (جنيه) — صفر ما لم يبلغ النصاب ويتم الحول.
  final double due;

  bool get isDue => due > 0;
}

/// حاسبة زكاة التجارة — دالة خالصة بلا أي حالة، قابلة للاختبار مباشرة.
class ZakatCalculator {
  /// نسبة الزكاة: 2.5%.
  static const double rate = 0.025;

  /// طول السنة الهجرية بالتقريب (354.367 يوماً).
  static const double hawlDays = 354.367;

  static Duration get hawlDuration => Duration(
        milliseconds:
            (hawlDays * Duration.millisecondsPerDay).round(),
      );

  /// يحسب الزكاة المستحقة من [inputs] عند لحظة [now]
  /// (الآن افتراضياً — تُمرَّر في الاختبارات فقط).
  ///
  /// يرمي [ArgumentError] عند مبلغ سالب أو نصاب غير موجب أو
  /// تاريخ بداية حول في المستقبل.
  static ZakatResult calculate(ZakatInputs inputs, {DateTime? now}) {
    final moment = now ?? DateTime.now();
    if (inputs.cash < 0 ||
        inputs.inventoryValue < 0 ||
        inputs.receivables < 0 ||
        inputs.debts < 0) {
      throw ArgumentError('المبالغ لا تكون سالبة.');
    }
    if (inputs.nisab <= 0) {
      throw ArgumentError('قيمة النصاب يجب أن تكون أكبر من صفر.');
    }
    if (inputs.hawlStart.isAfter(moment)) {
      throw ArgumentError('تاريخ بداية الحول لا يكون في المستقبل.');
    }
    final base = inputs.zakatableBase;
    final hawlEnd = inputs.hawlStart.add(hawlDuration);
    final hawlComplete = !moment.isBefore(hawlEnd);
    final nisabReached = base >= inputs.nisab;
    final due = nisabReached && hawlComplete ? base * rate : 0.0;
    return ZakatResult(
      inputs: inputs,
      base: base,
      hawlEnd: hawlEnd,
      hawlComplete: hawlComplete,
      nisabReached: nisabReached,
      due: due,
    );
  }
}

/// حفظ مدخلات الزكاة على الجهاز فقط (SharedPreferences) — بلا خادم.
class ZakatService {
  ZakatService({SharedPreferences? prefs})
      : _prefsFuture =
            prefs == null ? SharedPreferences.getInstance() : Future.value(prefs);

  final Future<SharedPreferences> _prefsFuture;

  static const _cashKey = 'zakat_cash';
  static const _inventoryKey = 'zakat_inventory';
  static const _receivablesKey = 'zakat_receivables';
  static const _debtsKey = 'zakat_debts';
  static const _hawlStartKey = 'zakat_hawl_start';
  static const _nisabKey = 'zakat_nisab';

  /// المدخلات المحفوظة، أو null إن لم يُحفظ شيء بعد.
  Future<ZakatInputs?> load() async {
    final prefs = await _prefsFuture;
    if (!prefs.containsKey(_cashKey)) return null;
    return ZakatInputs.fromJson({
      'cash': prefs.getDouble(_cashKey),
      'inventoryValue': prefs.getDouble(_inventoryKey),
      'receivables': prefs.getDouble(_receivablesKey),
      'debts': prefs.getDouble(_debtsKey),
      'hawlStart': prefs.getString(_hawlStartKey),
      'nisab': prefs.getDouble(_nisabKey),
    });
  }

  Future<void> save(ZakatInputs inputs) async {
    final prefs = await _prefsFuture;
    await prefs.setDouble(_cashKey, inputs.cash);
    await prefs.setDouble(_inventoryKey, inputs.inventoryValue);
    await prefs.setDouble(_receivablesKey, inputs.receivables);
    await prefs.setDouble(_debtsKey, inputs.debts);
    await prefs.setString(_hawlStartKey, inputs.hawlStart.toIso8601String());
    await prefs.setDouble(_nisabKey, inputs.nisab);
  }

  Future<void> clear() async {
    final prefs = await _prefsFuture;
    await prefs.remove(_cashKey);
    await prefs.remove(_inventoryKey);
    await prefs.remove(_receivablesKey);
    await prefs.remove(_debtsKey);
    await prefs.remove(_hawlStartKey);
    await prefs.remove(_nisabKey);
  }
}
