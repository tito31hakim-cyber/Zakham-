import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:house_of_zakham/services/admin_api.dart';

/// اختبارات الأولوية 5 — فلاتر بحث طلبات الإدارة.
///
/// لا تمس الخادم الحقيقي: MockClient يلتقط جسم الطلب ويعيد رداً
/// جاهزاً. الفلاتر تطابق ما يقبله `adminOrdersList` في الخادم
/// (محافظة LIKE، وطريقة دفع وحالة دفع حرفيتان، وتاريخا YYYY-MM-DD).

AdminApi _api(MockClient client) =>
    AdminApi(baseUrl: 'https://test.invalid', client: client);

MockClient _capturing(
  List<Map<String, dynamic>> seen, {
  Map<String, dynamic>? response,
}) =>
    MockClient((request) async {
      seen.add(jsonDecode(request.body) as Map<String, dynamic>);
      return http.Response(
        jsonEncode(response ?? {'ok': true, 'orders': []}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

void main() {
  group('بحث طلبات الإدارة — الفلاتر', () {
    test('بلا فلاتر: يرسل الصفحة وحجمها والترتيب فقط', () async {
      final seen = <Map<String, dynamic>>[];
      await _api(_capturing(seen)).orders();

      expect(seen, hasLength(1));
      final body = seen.first;
      expect(body['page'], 1);
      expect(body['pageSize'], 25);
      expect(body['sort'], 'created_desc');
      for (final key in [
        'status',
        'governorate',
        'paymentMethod',
        'paymentStatus',
        'dateFrom',
        'dateTo',
      ]) {
        expect(body.containsKey(key), isFalse, reason: key);
      }
    });

    test('كل الفلاتر تُرسل بقيمها إلى نقطة البحث', () async {
      final seen = <Map<String, dynamic>>[];
      await _api(_capturing(seen)).orders(
        status: 'pending_transfer',
        governorate: 'كفر الشيخ',
        paymentMethod: 'InstaPay | إنستاباي',
        paymentStatus: 'proof_submitted',
        dateFrom: '2026-11-01',
        dateTo: '2026-11-18',
        page: 2,
      );

      final body = seen.single;
      expect(body['status'], 'pending_transfer');
      expect(body['governorate'], 'كفر الشيخ');
      expect(body['paymentMethod'], 'InstaPay | إنستاباي');
      expect(body['paymentStatus'], 'proof_submitted');
      expect(body['dateFrom'], '2026-11-01');
      expect(body['dateTo'], '2026-11-18');
      expect(body['page'], 2);
    });

    test('قيم فارغة أو مسافات فقط تُهمل ولا تُرسل', () async {
      final seen = <Map<String, dynamic>>[];
      await _api(_capturing(seen)).orders(
        governorate: '   ',
        paymentMethod: '',
        dateFrom: ' ',
      );

      final body = seen.single;
      expect(body.containsKey('governorate'), isFalse);
      expect(body.containsKey('paymentMethod'), isFalse);
      expect(body.containsKey('dateFrom'), isFalse);
    });
  });
}
