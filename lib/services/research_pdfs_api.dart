import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'api_headers.dart';

/// حالة ملف PDF مرفوع لذاكرة البحث.
enum ResearchPdfStatus {
  /// قيد المراجعة — لم يدخل المعرفة بعد.
  underReview,

  /// أُدخل — دخلت حقائقه قاعدة المعرفة بعد مراجعة بشرية.
  entered,

  /// مرفوض — رُفض بعد المراجعة ولم يدخل المعرفة.
  rejected;

  static ResearchPdfStatus fromRaw(String? raw) => switch (raw) {
        'entered' => entered,
        'rejected' => rejected,
        _ => underReview,
      };

  /// التسمية العربية المعروضة في التطبيق.
  String get label => switch (this) {
        underReview => 'قيد المراجعة',
        entered => 'أُدخل',
        rejected => 'مرفوض',
      };
}

/// ملف PDF واحد مرفوع لذاكرة البحث.
class ResearchPdfFile {
  const ResearchPdfFile({
    required this.id,
    required this.filename,
    required this.sizeBytes,
    required this.status,
    this.uploadedAt,
  });

  final String id;
  final String filename;
  final int sizeBytes;
  final ResearchPdfStatus status;
  final DateTime? uploadedAt;

  factory ResearchPdfFile.fromJson(Map<String, dynamic> json) {
    final uploadedRaw = json['uploadedAt'] as String?;
    return ResearchPdfFile(
      id: '${json['id'] ?? ''}',
      filename: '${json['filename'] ?? ''}',
      sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
      status: ResearchPdfStatus.fromRaw(json['status'] as String?),
      uploadedAt:
          uploadedRaw == null ? null : DateTime.tryParse(uploadedRaw),
    );
  }

  /// الحجم بصيغة مقروءة (KB/MB).
  String get sizeLabel {
    if (sizeBytes >= 1024 * 1024) {
      return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (sizeBytes >= 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(0)} KB';
    }
    return '$sizeBytes B';
  }
}

/// عميل رفع ملفات PDF لذاكرة البحث فوق جلسة الإدارة الحالية
/// (POST/GET /api/admin/research/pdfs).
///
/// الملفات تُرفع إلى الخادم وتُحفظ خارج public_html، ولا تدخل ذاكرة
/// المستشار إلا بعد مراجعة بشرية — الرفع وحده لا يعلّم المستشار
/// شيئاً. حد الملف الواحد 10MB، والصيغة PDF فقط.
class ResearchPdfsApi {
  ResearchPdfsApi({
    required this.credentials,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final ApiCredentials credentials;

  /// حد حجم الملف الواحد (10MB).
  static const maxFileBytes = 10 * 1024 * 1024;

  /// ترويسات الإدارة: كوكي الجلسة + X-CSRF-Token (mutating: true)،
  /// مثل مسارات البحث الإدارية — بلا أي مفتاح خدمة. بلا Content-Type
  /// في الرفع: MultipartRequest يضع ترويسته الخاصة مع الحد الفاصل.
  Map<String, String> get _headers =>
      ApiHeaders.build(credentials: credentials, mutating: true);

  /// يرفع ملف PDF واحداً ويعيد بياناته كما سجّلها الخادم.
  ///
  /// يبلّغ [onProgress] بنسبة الرفع (0..1) أثناء إرسال البايتات،
  /// عبر تقسيم الملف إلى أجزاء 64KB. مهلة 120 ثانية لأن الرفع قد
  /// يكون بطيئاً على الشبكات الضعيفة.
  Future<ResearchPdfFile> uploadPdf({
    required String filename,
    required List<int> bytes,
    void Function(double progress)? onProgress,
  }) async {
    final name = filename.trim();
    if (!name.toLowerCase().endsWith('.pdf')) {
      throw const FormatException('اختر ملف PDF فقط.');
    }
    if (bytes.isEmpty) {
      throw const FormatException('الملف المختار فارغ.');
    }
    if (bytes.length > maxFileBytes) {
      throw const FormatException('حجم الملف يتجاوز 10MB — اختر ملفاً أصغر.');
    }
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${AppConfig.apiBaseUrl}${AppConfig.adminResearchPdfsPath}'),
    );
    request.headers.addAll(_headers);
    request.files.add(
      http.MultipartFile(
        'pdf',
        _chunked(bytes, onProgress),
        bytes.length,
        filename: name,
      ),
    );
    final streamed = await _client
        .send(request)
        .timeout(const Duration(seconds: 120));
    final response = await http.Response.fromStream(streamed);
    final data = _decode(response.body);
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw Exception('انتهت جلسة الإدارة — سجّل الدخول مجدداً.');
    }
    if (response.statusCode == 404) {
      throw Exception(
        'نقطة رفع ملفات البحث غير منشورة على الخادم بعد (404) — ستتوفر قريباً.',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        (data['message'] as String?)?.trim().isNotEmpty == true
            ? data['message']
            : 'تعذّر رفع الملف.',
      );
    }
    final file = data['file'];
    if (file is! Map<String, dynamic>) {
      throw const FormatException('استجابة رفع الملف غير صالحة.');
    }
    onProgress?.call(1);
    return ResearchPdfFile.fromJson(file);
  }

  /// يعيد قائمة الملفات المرفوعة مع حالتها.
  Future<List<ResearchPdfFile>> listPdfs() async {
    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}${AppConfig.adminResearchPdfsPath}',
    );
    final response = await _client
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 15));
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw Exception('انتهت جلسة الإدارة — سجّل الدخول مجدداً.');
    }
    if (response.statusCode == 404) {
      throw Exception(
        'نقطة ملفات البحث غير منشورة على الخادم بعد (404) — ستتوفر قريباً.',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('تعذر تحميل قائمة الملفات (${response.statusCode}).');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map || decoded['files'] is! List) {
      throw const FormatException('استجابة قائمة الملفات غير صالحة.');
    }
    return List<ResearchPdfFile>.from(
      (decoded['files'] as List).whereType<Map>().map(
            (item) => ResearchPdfFile.fromJson(
              Map<String, dynamic>.from(item),
            ),
          ),
    );
  }

  /// يبث البايتات في أجزاء 64KB ويبلّغ بالتقدم بعد كل جزء.
  Stream<List<int>> _chunked(
    List<int> bytes,
    void Function(double progress)? onProgress,
  ) async* {
    const chunk = 64 * 1024;
    var sent = 0;
    while (sent < bytes.length) {
      final end = (sent + chunk).clamp(0, bytes.length);
      yield bytes.sublist(sent, end);
      sent = end;
      onProgress?.call(sent / bytes.length);
    }
  }

  Map<String, dynamic> _decode(String raw) {
    if (raw.trim().isEmpty) return <String, dynamic>{};
    try {
      final value = jsonDecode(raw);
      return value is Map<String, dynamic> ? value : <String, dynamic>{};
    } catch (_) {
      throw Exception('الخادم أعاد استجابة غير صالحة.');
    }
  }
}
