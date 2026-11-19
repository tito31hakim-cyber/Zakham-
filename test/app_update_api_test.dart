import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:house_of_zakham/services/app_update_api.dart';

/// اختبارات عميل أحدث إصدار (app_update_api) — البناء 35.
///
/// لا استدعاء شبكة حقيقي إطلاقاً: كل الردود من `MockClient`.
/// ما يثبته الاختبار هو عقد العميل: GET عام بلا أي مصادقة إلى
/// /api/app/latest، وتحليل الرد الصالح، ورجوع null بصمت عند أي
/// فشل (بلا استثناء يصل إلى الواجهة)، وقاعدتا المقارنة والفحص
/// اليومي.

http.Response _jsonResponse(Object body, int status) =>
    http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

const _latestBody = {
  'ok': true,
  'versionCode': 5,
  'versionName': '1.1.0',
  'downloadUrl': 'https://zakhamhouse.shop/downloads/zakhamhouse.apk',
  'updatedAt': '2026-11-20',
};

void main() {
  group('AppUpdateApi — أحدث إصدار', () {
    test('fetchLatest يجلب GET العام بلا مصادقة ويحلل الرد', () async {
      http.Request? captured;
      final api = AppUpdateApi(
        client: MockClient((request) async {
          captured = request;
          return _jsonResponse(_latestBody, 200);
        }),
      );
      final info = await api.fetchLatest();
      expect(info, isNotNull);
      expect(info!.versionCode, 5);
      expect(info.versionName, '1.1.0');
      expect(
        info.downloadUrl,
        'https://zakhamhouse.shop/downloads/zakhamhouse.apk',
      );
      expect(info.updatedAt, '2026-11-20');
      expect(captured, isNotNull);
      expect(captured!.url.host, 'zakhamhouse.shop');
      expect(captured!.url.path, '/api/app/latest');
      expect(captured!.method, 'GET');
      // بلا أي مصادقة: لا تفويض ولا كوكي ولا CSRF.
      expect(captured!.headers.containsKey('Authorization'), isFalse);
      expect(captured!.headers.containsKey('Cookie'), isFalse);
      expect(captured!.headers.containsKey('X-CSRF-Token'), isFalse);
    });

    test('fetchLatest يرجع null عند 404 (النقطة غير منشورة بعد)', () async {
      final api = AppUpdateApi(
        client: MockClient(
          (_) async => _jsonResponse({'ok': false}, 404),
        ),
      );
      expect(await api.fetchLatest(), isNull);
    });

    test('fetchLatest يرجع null عند ok=false', () async {
      final api = AppUpdateApi(
        client: MockClient(
          (_) async => _jsonResponse({'ok': false}, 200),
        ),
      );
      expect(await api.fetchLatest(), isNull);
    });

    test('fetchLatest يرجع null عند جسم غير JSON', () async {
      final api = AppUpdateApi(
        client: MockClient(
          (_) async => http.Response('not json', 200),
        ),
      );
      expect(await api.fetchLatest(), isNull);
    });

    test('fetchLatest يرجع null عند نقص الحقول', () async {
      for (final body in [
        {'ok': true, 'versionName': '1.1.0', 'downloadUrl': 'https://x/y.apk'},
        {'ok': true, 'versionCode': '5', 'versionName': '1.1.0', 'downloadUrl': 'https://x/y.apk'},
        {'ok': true, 'versionCode': 0, 'versionName': '1.1.0', 'downloadUrl': 'https://x/y.apk'},
        {'ok': true, 'versionCode': 5, 'versionName': '', 'downloadUrl': 'https://x/y.apk'},
        {'ok': true, 'versionCode': 5, 'versionName': '1.1.0', 'downloadUrl': 'ftp://x/y.apk'},
        {'ok': true, 'versionCode': 5, 'versionName': '1.1.0', 'downloadUrl': ''},
      ]) {
        final api = AppUpdateApi(
          client: MockClient((_) async => _jsonResponse(body, 200)),
        );
        expect(await api.fetchLatest(), isNull, reason: '$body');
      }
    });

    test('fetchLatest يرجع null عند خطأ الشبكة', () async {
      final api = AppUpdateApi(
        client: MockClient((_) async => throw Exception('offline')),
      );
      expect(await api.fetchLatest(), isNull);
    });
  });

  group('isUpdateAvailable — مقارنة الإصدارات', () {
    test('الأحدث أكبر يتوفر تحديث', () {
      expect(
        isUpdateAvailable(latestVersionCode: 5, installedVersionCode: 4),
        isTrue,
      );
    });

    test('المساوي أو الأصغر لا تحديث', () {
      expect(
        isUpdateAvailable(latestVersionCode: 4, installedVersionCode: 4),
        isFalse,
      );
      expect(
        isUpdateAvailable(latestVersionCode: 3, installedVersionCode: 4),
        isFalse,
      );
    });
  });

  group('shouldCheckForUpdateToday — مرة في اليوم', () {
    final now = DateTime(2026, 11, 20, 10, 30);

    test('بلا فحص سابق يُفحص', () {
      expect(
        shouldCheckForUpdateToday(lastCheck: null, now: now),
        isTrue,
      );
    });

    test('فحص اليوم نفسه لا يُعاد', () {
      expect(
        shouldCheckForUpdateToday(
          lastCheck: DateTime(2026, 11, 20, 8, 0),
          now: now,
        ),
        isFalse,
      );
    });

    test('فحص أمس يُعاد اليوم', () {
      expect(
        shouldCheckForUpdateToday(
          lastCheck: DateTime(2026, 11, 19, 23, 59),
          now: now,
        ),
        isTrue,
      );
    });
  });
}
