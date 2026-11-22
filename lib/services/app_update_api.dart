import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'api_headers.dart';

/// معلومات أحدث إصدار معلن من المتجر (GET /api/app/latest).
class AppUpdateInfo {
  const AppUpdateInfo({
    required this.versionCode,
    required this.versionName,
    required this.downloadUrl,
    this.updatedAt,
    this.releaseNotes,
  });

  /// رقم البناء (versionCode) المعلن — يُقارن بـ AppVersion.versionCode.
  final int versionCode;

  /// اسم الإصدار المعلن (1.1.0).
  final String versionName;

  /// رابط تحميل الـ APK من المتجر.
  final String downloadUrl;

  /// تاريخ إعلان الإصدار (اختياري).
  final String? updatedAt;

  /// ملاحظات الإصدار (اختياري).
  final String? releaseNotes;

  /// يحلل جسم نقطة /api/app/latest؛ يرجع null عند أي نقص أو شكل
  /// غير صالح — فالحوار لا يظهر إلا على بيانات مكتملة موثوقة.
  static AppUpdateInfo? fromJson(Map<String, dynamic> data) {
    final versionCode = data['versionCode'];
    final versionName = (data['versionName'] as String?)?.trim() ?? '';
    final downloadUrl = (data['downloadUrl'] as String?)?.trim() ?? '';
    if (versionCode is! int || versionCode <= 0) return null;
    if (versionName.isEmpty) return null;
    final uri = Uri.tryParse(downloadUrl);
    if (uri == null ||
        !(uri.scheme == 'http' || uri.scheme == 'https') ||
        uri.host.isEmpty) {
      return null;
    }
    final updatedAt = (data['updatedAt'] as String?)?.trim();
    final releaseNotes = (data['releaseNotes'] as String?)?.trim();
    return AppUpdateInfo(
      versionCode: versionCode,
      versionName: versionName,
      downloadUrl: downloadUrl,
      updatedAt: updatedAt?.isEmpty == true ? null : updatedAt,
      releaseNotes: releaseNotes?.isEmpty == true ? null : releaseNotes,
    );
  }
}

/// عميل نقطة أحدث إصدار العامة (GET /api/app/latest) — بلا مصادقة.
///
/// التطبيق ليس على Google Play والتحديث لن يتم تلقائياً أبداً،
/// فهذا الفحص هو ما ينبّه المستخدمين بوجود إصدار أحدث ويوجّههم
/// لتثبيته يدوياً من المتجر.
///
/// أي فشل (شبكة، مهلة، حالة غير 2xx، جسم غير صالح) يرجع null
/// بصمت: فحص التحديث تنبيه اختياري لا يعطّل الإطلاق أبداً.
class AppUpdateApi {
  AppUpdateApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// مهلة الفحص — النقطة قراءة ملف صغير فلا تحتاج أكثر.
  static const timeout = Duration(seconds: 10);

  /// ترويسات النقطة العامة: بلا كوكي جلسة وبلا CSRF وبلا أي تفويض.
  Map<String, String> get _headers => ApiHeaders.build();

  /// يجلب أحدث إصدار معلن؛ null عند أي خطأ أو رد غير صالح.
  Future<AppUpdateInfo?> fetchLatest() async {
    try {
      final response = await _client
          .get(
            Uri.parse('${AppConfig.apiBaseUrl}${AppConfig.appLatestPath}'),
            headers: _headers,
          )
          .timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      final value = jsonDecode(response.body);
      if (value is! Map<String, dynamic>) return null;
      if (value['ok'] != true) return null;
      return AppUpdateInfo.fromJson(value);
    } catch (_) {
      return null;
    }
  }
}

/// هل الإصدار المعلن أحدث من المثبَّت؟ المقارنة برقم البناء فقط.
bool isUpdateAvailable({
  required int latestVersionCode,
  required int installedVersionCode,
}) =>
    latestVersionCode > installedVersionCode;
