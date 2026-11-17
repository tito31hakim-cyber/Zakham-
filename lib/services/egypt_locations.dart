import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import 'secure_http.dart';

/// قائمة المحافظات والمدن المعتمدة من الخادم (GET /api/locations/eg).
///
/// نفس القائمة التي يستخدمها المتجر الحي في إتمام الطلب؛ الخادم يرفض
/// (422 invalid_city) أي مدينة ليست فيها، لذلك لا يُرسل التطبيق مدينة
/// إلا من هذه القائمة أو من عنوان محفوظ سبق قبوله. عند فشل الجلب
/// تُستخدم النسخة المحفوظة، وعند غيابها تماماً يبقى حقل المدينة نصاً
/// حراً كما في المتجر (ويتحقق الخادم منه عند الإرسال).
class EgyptLocationsData {
  const EgyptLocationsData({required this.citiesByGovernorate});

  final Map<String, List<String>> citiesByGovernorate;

  List<String> get governorates =>
      citiesByGovernorate.keys.toList(growable: false);

  List<String> citiesFor(String governorate) =>
      citiesByGovernorate[governorate] ?? const <String>[];

  bool get isEmpty => citiesByGovernorate.isEmpty;

  factory EgyptLocationsData.fromJson(Map<String, dynamic> json) {
    final result = <String, List<String>>{};
    final raw = json['governorates'];
    if (raw is List) {
      for (final entry in raw) {
        if (entry is! Map) continue;
        final name = '${entry['governorate'] ?? ''}'.trim();
        if (name.isEmpty) continue;
        final cities = entry['cities'];
        if (cities is List) {
          result[name] = cities
              .map((city) => '$city'.trim())
              .where((city) => city.isNotEmpty)
              .toList(growable: false);
        }
      }
    }
    return EgyptLocationsData(citiesByGovernorate: result);
  }
}

class EgyptLocations {
  EgyptLocations({Future<String?> Function()? fetcher})
      : _fetcher = fetcher ?? _defaultFetch;

  static const _cacheKey = 'zakham_locations_eg_v1';

  final Future<String?> Function() _fetcher;

  static Future<String?> _defaultFetch() async {
    try {
      final response = await SecureHttp.client
          .get(AppConfig.locationsEgUri)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200 && response.body.isNotEmpty) {
        return response.body;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// يجلب القائمة من الخادم ويحفظها؛ عند أي فشل يعيد المحفوظة،
  /// وعند غيابها يعيد قائمة فارغة (لا يرمي أبداً).
  Future<EgyptLocationsData> load() async {
    final raw = await _fetcher();
    if (raw != null && raw.isNotEmpty) {
      try {
        final data = EgyptLocationsData.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
        if (!data.isEmpty) {
          await _saveCache(raw);
          return data;
        }
      } catch (_) {}
    }
    final cached = await _loadCache();
    if (cached != null) return cached;
    return const EgyptLocationsData(citiesByGovernorate: {});
  }

  Future<void> _saveCache(String raw) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, raw);
    } catch (_) {}
  }

  Future<EgyptLocationsData?> _loadCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null || raw.isEmpty) return null;
      final data =
          EgyptLocationsData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      return data.isEmpty ? null : data;
    } catch (_) {
      return null;
    }
  }
}
