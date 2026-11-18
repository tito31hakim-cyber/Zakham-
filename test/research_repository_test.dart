import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:house_of_zakham/services/research_repository.dart';

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
}
