import 'dart:convert';

import '../config/app_config.dart';
import 'secure_http.dart';

/// نتيجة التحقق من الأصالة — نفس ما تعرضه صفحة الموقع `/verify`.
///
/// نقطة التحقق اكتُشفت من صفحة الموقع نفسها (لا يوجد مسار `/api/verify`
/// في `api.php`): POST على نفس صفحة التحقق
/// `https://zakhamhouse.shop/verify?api=verify`
/// بجسم `application/x-www-form-urlencoded` وحقل `code` واحد، والرد JSON.
class VerifyResult {
  const VerifyResult({
    required this.authentic,
    required this.title,
    required this.message,
    required this.rows,
    required this.status,
  });

  /// هل الكرت أصلي (بما فيه `checksum_ok`: البصمة مطابقة لكن سجل
  /// المبيعات غير متاح مؤقتاً)؟
  final bool authentic;

  /// عنوان النتيجة كما في الموقع (مثل «قطعة أصلية · زخم رويال»).
  final String title;

  /// رسالة التوضيح.
  final String message;

  /// صفوف التفاصيل (تسمية، قيمة) — العطر، الرقم، المعرّف، الدفعة،
  /// تاريخ الإصدار، تاريخ البيع، مرات الفحص، المالك، الهاتف.
  final List<MapEntry<String, String>> rows;

  /// الحالة الخام من الخادم (`ok`/`valid`/`authentic`/`repeat`/
  /// `checksum_ok`/`not_found`/`revoked`/`bad_format`/`blocked`/`error`).
  final String status;
}

/// زوج تسمية/قيمة في نتيجة التحقق.
typedef VerifyRow = MapEntry<String, String>;

class VerifyService {
  VerifyService({String? baseUrl})
      : _baseUrl = baseUrl ?? AppConfig.apiBaseUrl;

  final String _baseUrl;

  /// الحالات التي تعني «أصلي» في صفحة الموقع.
  static const Set<String> okStatuses = <String>{
    'ok',
    'valid',
    'authentic',
    'repeat',
    'checksum_ok',
  };

  static const Map<String, String> _messages = <String, String>{
    'not_found':
        'الرقم صحيح الشكل لكنه غير مسجّل في سجل الدار. إن كان الكرت بحوزتك فأرسل لنا صورته ورقمه على /contact وسنتحقق يدويًا.',
    'revoked':
        'هذا الرقم صادر عن الدار لكنه أُلغي — يُرجَّح أنه أُعيد أو استُبدل. تواصل معنا لمراجعة الحالة.',
    'bad_format':
        'الرقم لا يطابق صيغة بطاقات الدار. الشكلان المقبولان: ZKH- وأربع مجموعات من أربعة، أو zh_xxx_00000 كما هو مطبوع على الكرت.',
    'blocked': 'محاولات كثيرة من نفس الشبكة. انتظر دقيقة ثم أعد المحاولة.',
    'error': 'تعذّر الوصول إلى سجل الدار الآن. أعد المحاولة بعد لحظات.',
  };

  /// يعرض الرقم بصيغة `ZKH-XXXX-XXXX-XXXX-XXXX` كما في الموقع؛
  /// صيغة `zh_...` تُعرض كما هي.
  static String prettyCode(String code) {
    final value = code.trim();
    if (value.isEmpty) return value;
    if (value.startsWith('zh_')) return value;
    var digits = value;
    if (digits.startsWith('ZKH')) digits = digits.substring(3);
    digits = digits.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    if (digits.isEmpty) return value;
    final groups = <String>[];
    for (var i = 0; i < digits.length; i += 4) {
      groups.add(
        digits.substring(i, i + 4 > digits.length ? digits.length : i + 4),
      );
    }
    return 'ZKH-${groups.join('-')}';
  }

  /// يفسّر رد التحقق JSON إلى نتيجة عرض — نفس منطق صفحة الموقع
  /// حرفياً (دالة بحتة قابلة للاختبار).
  static VerifyResult parseResult(Map<String, dynamic> data) {
    final status = '${data['status'] ?? 'error'}';
    final row = data['row'] is Map
        ? Map<String, dynamic>.from(data['row'] as Map)
        : <String, dynamic>{};

    if (status == 'checksum_ok') {
      return VerifyResult(
        authentic: true,
        title: 'بطاقة صادرة عن الدار',
        message:
            'بصمة الرقم مطابقة لبصمة الدار — الكرت أصلي. سجل المبيعات غير متاح الآن.',
        rows: <VerifyRow>[
          VerifyRow('الرقم', prettyCode('${data['code'] ?? ''}')),
          const VerifyRow('حالة السجل', 'غير متاح مؤقتًا'),
        ],
        status: status,
      );
    }

    if (!okStatuses.contains(status)) {
      if (status == 'not_found' && data['checksum'] == 'mismatch') {
        return const VerifyResult(
          authentic: false,
          title: 'الرقم غير مطابق',
          message:
              'بصمة الرقم لا تطابق بصمة الكرت. راجع الكتابة حرفًا حرفًا، أو امسح رمز QR على الكرت.',
          rows: <VerifyRow>[],
          status: 'not_found',
        );
      }
      final title = status == 'revoked'
          ? 'رقم ملغى'
          : status == 'not_found'
              ? 'غير مسجّل'
              : 'تحقّق غير مكتمل';
      return VerifyResult(
        authentic: false,
        title: title,
        message: _messages[status] ?? _messages['error']!,
        rows: const <VerifyRow>[],
        status: status,
      );
    }

    final product =
        '${data['product'] ?? data['product_name'] ?? row['product_name'] ?? ''}';
    final code = '${row['code'] ?? data['code'] ?? ''}';
    final issued = '${data['issued'] ?? row['issued_at'] ?? data['issued_at'] ?? ''}';
    final scans = data['scans'] ?? row['scan_count'] ?? 1;
    final scanCount = scans is num
        ? scans.toInt()
        : int.tryParse('$scans') ?? 1;
    final batch = '${row['batch'] ?? data['batch'] ?? ''}';
    final serial = '${row['serial_no'] ?? ''}';
    final saleDate = '${row['sale_date'] ?? ''}';
    final ownerMasked = '${data['owner_masked'] ?? ''}';
    final phoneMasked = '${data['phone_masked'] ?? ''}';

    final rows = <VerifyRow>[
      VerifyRow('العطر', product.isEmpty ? '—' : product),
      if (code.isNotEmpty) VerifyRow('الرقم', prettyCode(code)),
      if (serial.isNotEmpty) VerifyRow('المعرّف', serial),
      if (batch.isNotEmpty) VerifyRow('الدفعة', batch),
      if (issued.isNotEmpty)
        VerifyRow(
          'تاريخ الإصدار',
          issued.length >= 10 ? issued.substring(0, 10) : issued,
        ),
      if (saleDate.isNotEmpty) VerifyRow('تاريخ البيع', saleDate),
      VerifyRow('مرات الفحص', '$scanCount'),
      if (ownerMasked.isNotEmpty) VerifyRow('المالك', ownerMasked),
      if (phoneMasked.isNotEmpty) VerifyRow('الهاتف', phoneMasked),
    ];

    var message = status == 'repeat' || scanCount > 1
        ? 'الكرت مسجّل في سجل الدار وفُحص $scanCount مرة. تكرار الفحص طبيعي — لكن إن ظهر الرقم نفسه على كرت آخر أبلغنا فورًا.'
        : 'تم التحقق من الرقم في سجل الدار. الكرت أصلي وخارج من إنتاج زَخْم المباشر.';
    if (ownerMasked.isNotEmpty || phoneMasked.isNotEmpty) {
      message +=
          ' بيانات المالك مقنّعة عمدًا: تظهر أطراف الاسم والرقم فقط، لتثبت ملكيتك دون كشف بياناتك للعامة.';
    }

    return VerifyResult(
      authentic: true,
      title: 'قطعة أصلية${product.isEmpty ? '' : ' · $product'}',
      message: message,
      rows: rows,
      status: status,
    );
  }

  /// يتحقق من رقم بطاقة (ZKH-... أو zh_...) لدى سجل الدار.
  /// أي عطل في الشبكة أو رد غير JSON يُرجع نتيجة `error` بدلاً من
  /// رمي استثناء — صفحة التحقق لا تنهار أبداً.
  Future<VerifyResult> verify(String code) async {
    final value = code.trim();
    if (value.isEmpty) {
      return const VerifyResult(
        authentic: false,
        title: 'أدخل رقم الكرت',
        message: 'الرقم مطبوع على كرت العطر المرفق بالزجاجة.',
        rows: <VerifyRow>[],
        status: 'bad_format',
      );
    }
    try {
      final uri = Uri.parse('$_baseUrl/verify?api=verify');
      final response = await SecureHttp.client
          .post(
            uri,
            headers: <String, String>{
              'Content-Type': 'application/x-www-form-urlencoded',
              'Accept': 'application/json',
            },
            body: 'code=${Uri.encodeQueryComponent(value)}',
          )
          .timeout(const Duration(seconds: 20));
      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        return parseResult(Map<String, dynamic>.from(decoded));
      }
      return _errorResult();
    } catch (_) {
      return _errorResult();
    }
  }

  VerifyResult _errorResult() => const VerifyResult(
        authentic: false,
        title: 'تعذّر الاتصال',
        message: 'تعذّر الوصول إلى سجل الدار الآن. أعد المحاولة بعد لحظات.',
        rows: <VerifyRow>[],
        status: 'error',
      );
}
