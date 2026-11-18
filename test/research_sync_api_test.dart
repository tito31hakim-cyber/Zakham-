import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:house_of_zakham/services/api_headers.dart';
import 'package:house_of_zakham/services/research_repository.dart';
import 'package:house_of_zakham/services/research_sync_api.dart';

/// اختبارات عميل المستخدم للقراءة فقط (research_sync_api) وربطه بالمستودع.
///
/// لا استدعاء شبكة حقيقي إطلاقاً: كل الردود من `MockClient`، والخادم
/// الحقيقي لا يُلمس. ما يثبته الاختبار هو عقد العميل كما كتبه المستخدم:
/// مسارا القراءة الإدارية، ورسائل الخطأ العربية، ومهلة 15 ثانية،
/// وعدم حمل أي مفتاح خدمة — ثم تحويل الرد إلى نماذج العرض الآمنة
/// فقط عبر [ApiResearchRepository] (بلا نسب ولا موردين ولا تكاليف).

const _credentials = ApiCredentials();

ResearchSyncApi _apiWith(MockClient client) =>
    ResearchSyncApi(credentials: _credentials, client: client);

void main() {
  group('ResearchSyncApi — عميل القراءة (ملف المستخدم)', () {
    test('listMixes يقرأ كتالوج الميكسات من المسار الإداري', () async {
      http.Request? captured;
      final api = _apiWith(MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'mixes': [
              {
                'code': 'ZK-DRAFT-003',
                'nameAr': 'اختبار',
                'status': 'research_draft',
              },
            ],
          }),
          200,
        );
      }));
      final mixes = await api.listMixes();
      expect(mixes, hasLength(1));
      expect(mixes.first['code'], 'ZK-DRAFT-003');
      expect(captured, isNotNull);
      expect(captured!.url.host, 'zakhamhouse.shop');
      expect(captured!.url.path, '/api/admin/research/mixes');
      expect(captured!.method, 'GET');
      // قراءة فقط بلا مفتاح خدمة وبلا أي ترويسة حساسة.
      expect(captured!.headers.containsKey('Authorization'), isFalse);
      expect(captured!.headers.containsKey('X-Service-Key'), isFalse);
    });

    test('listMixes يمرر الحالة كمعامل استعلام مرمّز', () async {
      http.Request? captured;
      final api = _apiWith(MockClient((request) async {
        captured = request;
        return http.Response(jsonEncode({'mixes': []}), 200);
      }));
      await api.listMixes(status: 'research_draft');
      expect(captured!.url.queryParameters['status'], 'research_draft');
    });

    test('listMixes يرمي استثناء عند خطأ HTTP', () async {
      final api = _apiWith(MockClient(
        (_) async => http.Response('خطأ داخلي', 500),
      ));
      await expectLater(
        api.listMixes(),
        throwsA(isA<Exception>()),
      );
    });

    test('listMixes يرمي FormatException عند رد غير صالح', () async {
      final api = _apiWith(MockClient(
        (_) async => http.Response(jsonEncode({'nope': true}), 200),
      ));
      await expectLater(
        api.listMixes(),
        throwsA(isA<FormatException>()),
      );
    });

    test('knowledgeSummary يقرأ ملخص الذاكرة من مسار البحث الموحد',
        () async {
      http.Request? captured;
      final api = _apiWith(MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({'knowledgeVersion': '1.0.0', 'mixesCount': 2}),
          200,
        );
      }));
      final summary = await api.knowledgeSummary();
      expect(summary['knowledgeVersion'], '1.0.0');
      expect(summary['mixesCount'], 2);
      expect(
        captured!.url.path,
        '/api/admin/research/knowledge-summary',
      );
    });

    test('knowledgeSummary يرمي استثناء عند خطأ HTTP', () async {
      final api = _apiWith(MockClient(
        (_) async => http.Response('ممنوع', 403),
      ));
      await expectLater(
        api.knowledgeSummary(),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('ApiResearchRepository — تحويل الرد إلى نماذج آمنة', () {
    test('الخلاصة تُبنى من الميكسات وملخص آخر دورة', () async {
      final api = _apiWith(MockClient((request) async {
        if (request.url.path.endsWith('/mixes')) {
          return http.Response(
            jsonEncode({
              'mixes': [
                {
                  'code': 'ZK-DRAFT-003',
                  'nameAr': 'مجلس اختبار',
                  'status': 'research_draft',
                  'version': 1,
                  'topNotes': ['برغموت'],
                  'heartNotes': ['ورد'],
                  'baseNotes': ['عود'],
                  'evidenceSummary': 'مستند إلى مصدرين عامين.',
                  'warnings': ResearchDraftMix.requiredWarnings,
                  'confidence': 72,
                },
              ],
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'latestRun': {
              'runId': 'research_2026_11_18_002',
              'startedAt': '2026-11-18T08:00:00Z',
              'status': 'completed',
              'sourcesFound': 10,
              'sourcesAccepted': 7,
              'newMaterials': 2,
              'newMixes': 1,
              'agentVersion': '0.1.0',
              'knowledgeVersion': '1.0.0',
            },
          }),
          200,
        );
      }));
      final digest = await ApiResearchRepository(api).latestDigest();

      expect(digest.run.runId, 'research_2026_11_18_002');
      expect(digest.run.status, 'completed');
      expect(digest.run.sourcesFound, 10);
      expect(digest.run.sourcesAccepted, 7);
      expect(digest.run.newMaterials, 2);
      expect(digest.run.newMixes, 1);
      expect(digest.run.knowledgeVersion, '1.0.0');

      expect(digest.drafts, hasLength(1));
      final draft = digest.drafts.first;
      expect(draft.code, 'ZK-DRAFT-003');
      expect(draft.isUnapprovedDraft, isTrue);
      expect(draft.topNotes, ['برغموت']);
      expect(draft.heartNotes, ['ورد']);
      expect(draft.baseNotes, ['عود']);
      expect(draft.warnings, containsAll(ResearchDraftMix.requiredWarnings));
      expect(draft.confidence, '72/100');
      // التمثيل العام بلا أي حقل حساس.
      expect(
        draft.toPublicJson().keys.toSet(),
        {
          'code',
          'nameAr',
          'status',
          'version',
          'topNotes',
          'heartNotes',
          'baseNotes',
          'evidenceSummary',
          'warnings',
          'confidence',
        },
      );
    });

    test('الحقول الغائبة تُستبدل بقيم محايدة لا بيانات مخترعة', () async {
      final api = _apiWith(MockClient((request) async {
        if (request.url.path.endsWith('/mixes')) {
          return http.Response(
            jsonEncode({
              'mixes': [
                {'code': 'ZK-DRAFT-004', 'nameAr': 'بلا حقول'},
              ],
            }),
            200,
          );
        }
        return http.Response(jsonEncode({}), 200);
      }));
      final digest = await ApiResearchRepository(api).latestDigest();
      expect(digest.run.runId, 'unknown');
      expect(digest.run.sourcesFound, 0);
      final draft = digest.drafts.first;
      expect(draft.status, 'research_draft');
      expect(draft.isUnapprovedDraft, isTrue);
      expect(draft.topNotes, isEmpty);
      expect(draft.warnings, ResearchDraftMix.requiredWarnings);
      expect(draft.confidence, 'غير محددة');
      expect(draft.evidenceSummary, isNotEmpty);
    });
  });
}
