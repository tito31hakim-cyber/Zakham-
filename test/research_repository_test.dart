import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:house_of_zakham/services/api_headers.dart';
import 'package:house_of_zakham/services/research_repository.dart';
import 'package:house_of_zakham/services/research_sync_api.dart';

http.Response _jsonResponse(Object body, int status) =>
    http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

void main() {
  group('MockResearchRepository — خلاصة بحث وابتكار', () {
    test('الملخص يحمل حقول الدورة كاملة', () async {
      final digest = await const MockResearchRepository().latestDigest();
      expect(digest.run.runId, 'research_2026_11_18_001');
      expect(digest.run.status, 'completed');
      expect(digest.run.sourcesFound, greaterThanOrEqualTo(digest.run.sourcesAccepted));
      expect(digest.run.sourcesAccepted, greaterThan(0));
      expect(digest.run.newMaterials, greaterThanOrEqualTo(0));
      expect(digest.run.newMixes, digest.drafts.length);
      expect(digest.run.agentVersion, isNotEmpty);
      expect(digest.run.knowledgeVersion, '1.0.0');
    });

    test('كل مسودة موسومة «مسودة تجريبية غير معتمدة»', () async {
      final digest = await const MockResearchRepository().latestDigest();
      expect(digest.drafts, isNotEmpty);
      for (final draft in digest.drafts) {
        expect(draft.status, 'research_draft');
        expect(draft.isUnapprovedDraft, isTrue);
        expect(ResearchDraftMix.unapprovedTag, 'مسودة تجريبية غير معتمدة');
      }
    });

    test('كل مسودة تحمل التحذيرات الإلزامية الثلاثة', () async {
      final digest = await const MockResearchRepository().latestDigest();
      for (final draft in digest.drafts) {
        expect(draft.warnings, containsAll(ResearchDraftMix.requiredWarnings));
        expect(draft.warnings, contains('لم تتم مراجعة IFRA'));
        expect(draft.warnings, contains('لم يتم اختبار الثبات'));
        expect(draft.warnings, contains('غير جاهز للإنتاج'));
      }
    });

    test('كل مسودة تحمل هرماً عطرياً وملخص أدلة ودرجة ثقة', () async {
      final digest = await const MockResearchRepository().latestDigest();
      for (final draft in digest.drafts) {
        expect(draft.topNotes, isNotEmpty);
        expect(draft.heartNotes, isNotEmpty);
        expect(draft.baseNotes, isNotEmpty);
        expect(draft.evidenceSummary, isNotEmpty);
        expect(draft.confidence, isNotEmpty);
        expect(draft.code, startsWith('ZK-DRAFT-'));
        expect(draft.version, isNotEmpty);
      }
    });

    test('التمثيل العام لا يحمل أي حقل حساس', () async {
      const allowedKeys = {
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
      };
      final digest = await const MockResearchRepository().latestDigest();
      for (final draft in digest.drafts) {
        final json = draft.toPublicJson();
        expect(json.keys.toSet(), allowedKeys);
        // لا نسب ولا موردون ولا دفعات ولا COA/SDS ولا تكاليف — حتى
        // كسلسلة نصية داخل الترميز الكامل.
        final encoded = jsonEncode(json).toLowerCase();
        // لا حقل حساس كمفتاح في التمثيل — حتى لو ذُكرت COA/SDS
        // نصاً داخل ملخص الأدلة («بلا COA أو SDS بعد») فهي ليست حقلاً.
        for (final forbiddenKey in [
          '"percentagebyweight"',
          '"supplier"',
          '"batchnumber"',
          '"cost"',
          '"coa"',
          '"sds"',
        ]) {
          expect(encoded, isNot(contains(forbiddenKey)));
        }
      }
    });

    test('أكواد المسودات فريدة', () async {
      final digest = await const MockResearchRepository().latestDigest();
      final codes = digest.drafts.map((d) => d.code).toList();
      expect(codes.toSet().length, codes.length);
    });
  });

  group('ApiResearchRepository — كتلة v3 (البناء 40)', () {
    ApiResearchRepository _repoWith(Map<String, dynamic> summary) {
      final api = ResearchSyncApi(
        credentials: const ApiCredentials(),
        client: MockClient((request) async {
          if (request.url.path.endsWith('/mixes')) {
            return _jsonResponse({'mixes': []}, 200);
          }
          if (request.url.path.endsWith('/knowledge-summary')) {
            return _jsonResponse(summary, 200);
          }
          return http.Response('', 404);
        }),
      );
      return ApiResearchRepository(api);
    }

    Map<String, dynamic> _feeding003Summary({bool withV3 = true}) => {
          'lastRun': {
            'run_key': 'zakham-feeding-2026-11-20-003',
            'started_at': '2026-11-20T23:31:00Z',
            'status': 'review',
            'sources_found': 0,
            'sources_accepted': 0,
            'new_materials': 0,
            'new_mixes': 0,
            'agent_version': '0.1.0',
          },
          if (withV3)
            'v3': {
              'runs': 4,
              'status': 'review',
              'newCompanies': 113,
              'newMaterials': 5,
              'newPrices': 247,
              'newIfraLimits': 9,
              'newMixes': 0,
              'sourcesFound': 0,
              'latestStartedAt': '2026-11-20T23:31:00Z',
            },
        };

    test('كتلة v3 تُحلَّل 113/5/247/9 بدل أصفار آخر دورة', () async {
      final digest =
          await _repoWith(_feeding003Summary()).latestDigest();
      // آخر دورة (تغذية 003) أصفار فعلاً.
      expect(digest.run.newMaterials, 0);
      expect(digest.run.newMixes, 0);
      final v3 = digest.v3;
      expect(v3, isNotNull);
      expect(v3!.runs, 4);
      expect(v3.status, 'review');
      expect(v3.newCompanies, 113);
      expect(v3.newMaterials, 5);
      expect(v3.newPrices, 247);
      expect(v3.newIfraLimits, 9);
      expect(v3.newMixes, 0);
      expect(v3.sourcesFound, 0);
    });

    test('غياب كتلة v3 يعيد null — توافق رجعي مع خادم قديم', () async {
      final digest = await _repoWith(
        _feeding003Summary(withV3: false),
      ).latestDigest();
      expect(digest.v3, isNull);
      expect(digest.run.runId, 'zakham-feeding-2026-11-20-003');
    });
  });
}
