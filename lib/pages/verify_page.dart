import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../services/verify_service.dart';
import '../theme/app_theme.dart';

/// صفحة «تحقق من الأصالة» — نفس صفحة الموقع `/verify`: إدخال رقم
/// الكرت (ZKH-... أو zh_...) أو مسح رمز QR على الكرت، والتحقق لدى
/// سجل الدار. النتيجة تعرض ما يعرضه الموقع: حالة الأصالة، العطر،
/// الرقم، المعرّف، الدفعة، تاريخ الإصدار، تاريخ البيع، مرات الفحص،
/// والمالك/الهاتف مقنّعين.
class VerifyPage extends StatefulWidget {
  const VerifyPage({super.key});
  @override
  State<VerifyPage> createState() => _VerifyPageState();
}

class _VerifyPageState extends State<VerifyPage> {
  final TextEditingController _codeController = TextEditingController();
  final VerifyService _service = VerifyService();
  VerifyResult? _result;
  bool _checking = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verify([String? code]) async {
    final value = (code ?? _codeController.text).trim();
    if (_checking) return;
    setState(() {
      _checking = true;
      _result = null;
    });
    final result = await _service.verify(value);
    if (!mounted) return;
    setState(() {
      _checking = false;
      _result = result;
    });
  }

  Future<void> _scanQr() async {
    final scanned = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const _QrScannerPage()),
    );
    if (scanned == null || scanned.isEmpty || !mounted) return;
    _codeController.text = scanned;
    await _verify(scanned);
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(title: const Text('تحقق من الأصالة')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            children: [
              Text(
                'تأكد أن عطرك أصلي',
                style: TextStyle(
                  color: context.ink,
                  fontSize: 26,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'أدخل الرقم المطبوع على كرت العطر المرفق بالزجاجة، أو امسح رمز QR على الكرت. الشكلان المقبولان: ZKH- وأربع مجموعات من أربعة، أو zh_xxx_00000 كما هو مطبوع على الكرت.',
                style: TextStyle(color: context.subdued, height: 1.8),
              ),
              const SizedBox(height: 20),
              Directionality(
                textDirection: TextDirection.ltr,
                child: TextField(
                  controller: _codeController,
                  maxLength: 24,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    hintText: 'ZKH-XXXX-XXXX-XXXX-XXXX',
                    counterText: '',
                    prefixIcon: Icon(Icons.confirmation_number_outlined),
                  ),
                  onSubmitted: (_) => _verify(),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _checking ? null : () => _verify(),
                      icon: _checking
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : const Icon(Icons.verified_outlined, size: 20),
                      label: Text(_checking ? 'جارٍ التحقق…' : 'تحقق'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _checking ? null : _scanQr,
                      icon: const Icon(Icons.qr_code_scanner_outlined),
                      label: const Text('امسح رمز QR'),
                    ),
                  ),
                ],
              ),
              if (_result != null) ...[
                const SizedBox(height: 22),
                _VerifyResultCard(result: _result!),
              ],
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.surfaceCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.hairline),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.shield_outlined, color: context.goldText),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'كل زجاجة من دار زخم تحمل كرت أصالة برقم فريد مسجّل في سجل الدار. تكرار الفحص طبيعي — لكن إن ظهر الرقم نفسه على كرت آخر أبلغنا فورًا.',
                        style: TextStyle(
                          color: context.subdued,
                          height: 1.8,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class _VerifyResultCard extends StatelessWidget {
  const _VerifyResultCard({required this.result});
  final VerifyResult result;

  @override
  Widget build(BuildContext context) {
    final ok = result.authentic;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: ok ? gold.withOpacity(.5) : Colors.redAccent.withOpacity(.5),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                ok ? Icons.verified : Icons.error_outline,
                color: ok ? context.goldText : Colors.redAccent,
                size: 28,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  result.title,
                  style: TextStyle(
                    color: context.ink,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            result.message,
            style: TextStyle(color: context.subdued, height: 1.8),
          ),
          if (result.rows.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(height: 1),
            ...result.rows.map(
              (row) => Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.key,
                      style: TextStyle(color: context.subdued, fontSize: 13),
                    ),
                    const Spacer(),
                    Flexible(
                      child: Text(
                        row.value,
                        textAlign: TextAlign.left,
                        style: TextStyle(
                          color: context.ink,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// صفحة مسح QR كاملة الشاشة — أول رمز يُقرأ يُعاد رقمه للتحقق منه.
class _QrScannerPage extends StatefulWidget {
  const _QrScannerPage();
  @override
  State<_QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<_QrScannerPage> {
  bool _handled = false;

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue?.trim();
      if (value != null && value.isNotEmpty) {
        _handled = true;
        Navigator.pop(context, value);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('امسح رمز QR')),
        body: Stack(
          children: [
            MobileScanner(
              onDetect: _onDetect,
              errorBuilder: (context, error) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'تعذر تشغيل الكاميرا على هذا الجهاز. أدخل الرقم يدوياً بدلاً من المسح.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.subdued, height: 1.8),
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                child: Text(
                  'وجّه الكاميرا نحو رمز QR على كرت العطر',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    shadows: <Shadow>[
                      Shadow(color: Colors.black, blurRadius: 6),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}
