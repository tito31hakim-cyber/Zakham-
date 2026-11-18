/// مستودع بيانات «بحث وابتكار» — قراءة فقط.
///
/// البيانات الحقيقية تأتي لاحقاً من API دار زخم بعد إنشاء قاعدة البيانات
/// السحابية ونقطة المزامنة الداخلية (انظر عقد المزامنة
/// research-sync-contract-v1.md):
///
/// ```text
/// GET  /api/admin/research/runs      (ملخص آخر دورة)
/// GET  /api/admin/research/mixes     (مسودات الميكسات)
/// GET  /api/admin/research/knowledge-summary  (ملخص مكتبة المعرفة)
/// ```
///
/// وحتى ذلك الحين يعمل التطبيق على [MockResearchRepository] ببيانات
/// تجريبية محلية بنفس شكل حمولة العقد، وبلا أي استدعاء شبكة حقيقي.
///
/// قاعدة أمنية: نماذج العرض هنا لا تحمل الحقول الحساسة أصلاً — لا نسب
/// كاملة، ولا موردين، ولا أرقام دفعات، ولا ملفات COA/SDS، ولا تكاليف.
/// تلك البيانات للمالك أو مسؤول التركيبات فقط عبر لوحة الإدارة، فالإخفاء
/// يكون بغياب الحقل لا بتصفيته في الواجهة.
//
// TODO(research-api): استبدل MockResearchRepository بـ ApiResearchRepository
//   فوق ResearchSyncApi (lib/services/research_sync_api.dart — عميل المستخدم)
//   عند نشر مسارات الإدارة GET /api/admin/research/mixes
//   وGET /api/admin/research/knowledge-summary؛ وحافظ على قائمة الحقول
//   الآمنة كما هي (انظر [ResearchDraftMix.toPublicJson]) ولا تضف إليها
//   حقلاً حساساً.

import 'research_sync_api.dart';

/// ملخص آخر دورة بحث أسبوعية — كما يرده `GET /api/admin/research/runs`.
class ResearchRunSummary {
  const ResearchRunSummary({
    required this.runId,
    required this.startedAt,
    required this.status,
    required this.sourcesFound,
    required this.sourcesAccepted,
    required this.newMaterials,
    required this.newMixes,
    required this.agentVersion,
    required this.knowledgeVersion,
  });

  /// معرّف الدورة، مثال: research_2026_11_18_001.
  final String runId;

  /// وقت بدء الدورة.
  final DateTime startedAt;

  /// حالة الدورة: completed | failed | partial.
  final String status;

  /// مصادر وُجدت / قُبلت في الدورة.
  final int sourcesFound;
  final int sourcesAccepted;

  /// مواد وميكسات جديدة أنشأتها الدورة.
  final int newMaterials;
  final int newMixes;

  /// إصدار الوكيل وإصدار مكتبة المعرفة المستخدم في الدورة.
  final String agentVersion;
  final String knowledgeVersion;
}

/// مسودة ميكس مقترحة من وكيل البحث — للمراجعة البشرية فقط.
///
/// تحمل عمداً الحقول الآمنة فقط (الاسم، الحالة، الإصدار، الهرم العطري،
/// ملخص الأدلة، التحذيرات، درجة الثقة). لا توجد هنا نسب ولا موردون
/// ولا تكاليف — انظر [toPublicJson].
class ResearchDraftMix {
  const ResearchDraftMix({
    required this.code,
    required this.nameAr,
    required this.status,
    required this.version,
    required this.topNotes,
    required this.heartNotes,
    required this.baseNotes,
    required this.evidenceSummary,
    required this.warnings,
    required this.confidence,
  });

  /// الوسم الإلزامي على كل مسودة — يظهر في الواجهة بلا استثناء.
  static const String unapprovedTag = 'مسودة تجريبية غير معتمدة';

  /// التحذيرات الإلزامية في كل ميكس وارد من الوكيل (من عقد المزامنة).
  static const List<String> requiredWarnings = [
    'لم تتم مراجعة IFRA',
    'لم يتم اختبار الثبات',
    'غير جاهز للإنتاج',
  ];

  final String code;
  final String nameAr;

  /// حالة الميكس؛ المسودات المعروضة هنا دائماً `research_draft`.
  final String status;
  final String version;

  /// الهرم العطري: افتتاحية / قلب / قاعدة.
  final List<String> topNotes;
  final List<String> heartNotes;
  final List<String> baseNotes;

  /// ملخص الأدلة: عدد المصادر وأنواعها، لا روابط حساسة.
  final String evidenceSummary;

  /// تحذيرات السلامة والجاهزية (تشمل التحذيرات الإلزامية الثلاثة).
  final List<String> warnings;

  /// درجة الثقة بالاقتراح (مثال: منخفضة — مسودة أولية).
  final String confidence;

  /// المسودة غير معتمدة ما دامت في حالة بحث أولية.
  bool get isUnapprovedDraft => status == 'research_draft';

  /// التمثيل العام الآمن للمسودة — الحقول المسموح بها في التطبيق فقط.
  /// أي حقل حساس (نسب، موردون، دفعات، COA/SDS، تكاليف) لا يوجد
  /// في هذه الخريطة أصلاً.
  Map<String, dynamic> toPublicJson() => {
        'code': code,
        'nameAr': nameAr,
        'status': status,
        'version': version,
        'topNotes': List<String>.unmodifiable(topNotes),
        'heartNotes': List<String>.unmodifiable(heartNotes),
        'baseNotes': List<String>.unmodifiable(baseNotes),
        'evidenceSummary': evidenceSummary,
        'warnings': List<String>.unmodifiable(warnings),
        'confidence': confidence,
      };
}

/// خلاصة «بحث وابتكار» المعروضة في مركز الذكاء.
class ResearchDigest {
  const ResearchDigest({
    required this.run,
    required this.drafts,
    required this.generatedAt,
  });

  final ResearchRunSummary run;
  final List<ResearchDraftMix> drafts;
  final DateTime generatedAt;
}

/// واجهة قراءة بيانات البحث — تُستبدل بتنفيذ API حقيقي لاحقاً.
abstract class ResearchRepository {
  Future<ResearchDigest> latestDigest();
}

/// مزود تجريبي محلي — بيانات ثابتة بنفس شكل حمولة عقد المزامنة،
/// موسومة بوضوح كتجريبية في الواجهة. بلا أي استدعاء شبكة.
class MockResearchRepository implements ResearchRepository {
  const MockResearchRepository();

  @override
  Future<ResearchDigest> latestDigest() async => ResearchDigest(
        run: ResearchRunSummary(
          runId: 'research_2026_11_18_001',
          startedAt: _mockRunDate,
          status: 'completed',
          sourcesFound: 14,
          sourcesAccepted: 9,
          newMaterials: 3,
          newMixes: 2,
          agentVersion: '0.1.0',
          knowledgeVersion: '1.0.0',
        ),
        drafts: const [
          ResearchDraftMix(
            code: 'ZK-DRAFT-001',
            nameAr: 'مجلس عربي بعد المطر',
            status: 'research_draft',
            version: '1.0',
            topNotes: ['برغموت', 'هيل'],
            heartNotes: ['ورد', 'عنبر'],
            baseNotes: ['عود', 'مسك'],
            evidenceSummary:
                'مستند إلى مرجعين عامين: وثيقة IFRA متاحة ومقال تقني منشور؛ بلا نسب منشورة معتمدة بعد.',
            warnings: ResearchDraftMix.requiredWarnings,
            confidence: 'منخفضة — مسودة أولية',
          ),
          ResearchDraftMix(
            code: 'ZK-DRAFT-002',
            nameAr: 'فجر شتوي دافئ',
            status: 'research_draft',
            version: '1.0',
            topNotes: ['زعفران', 'ليمون'],
            heartNotes: ['عنبر', 'ورد'],
            baseNotes: ['مسك', 'خشب الصندل'],
            evidenceSummary:
                'مستند إلى مقال تقني منشور وصفحة مورد عامة؛ بلا COA أو SDS بعد.',
            warnings: ResearchDraftMix.requiredWarnings,
            confidence: 'منخفضة — مسودة أولية',
          ),
        ],
        generatedAt: _mockRunDate,
      );

  // تاريخ ثابت للدورة التجريبية حتى تبقى اللقطات والاختبارات حتمية.
  static final _mockRunDate = DateTime.utc(2026, 11, 18, 8, 0);
}

/// تنفيذ API الحقيقي فوق [ResearchSyncApi] (عميل المستخدم للقراءة فقط).
///
/// يقرأ مسارات الإدارة الموجودة في العميل فقط:
/// `GET /api/admin/research/mixes` و`GET /api/admin/research/knowledge-summary`.
/// لا يُستخدم حتى تُنشر مسارات الإدارة على الخادم؛ وحتى ذلك الحين
/// تبقى الصفحة على [MockResearchRepository].
///
/// التحويل دفاعي عمداً: رد الخادم قد يحمل الحقول بصيغة camelCase
/// (مخطط الحمولة) أو snake_case (قاعدة البيانات)؛ وأي حقل غائب
/// يُستبدل بقيمة آمنة محايدة، لا ببيانات مخترعة. والحقول الحساسة
/// (النسب، الموردون، الدفعات، COA/SDS، التكاليف) لا تُقرأ أصلاً —
/// نماذج العرض لا تحملها، فالإخفاء بغياب الحقل لا بتصفيته.
class ApiResearchRepository implements ResearchRepository {
  ApiResearchRepository(this._api);

  final ResearchSyncApi _api;

  @override
  Future<ResearchDigest> latestDigest() async {
    final results = await Future.wait([
      _api.listMixes(),
      _api.knowledgeSummary(),
    ]);
    final mixes = results[0] as List<Map<String, dynamic>>;
    final summary = results[1] as Map<String, dynamic>;
    return ResearchDigest(
      run: _parseRun(summary),
      drafts: mixes.map(_parseDraft).toList(),
      generatedAt: DateTime.now(),
    );
  }

  static ResearchRunSummary _parseRun(Map<String, dynamic> summary) {
    final rawRun = summary['latestRun'];
    final run =
        rawRun is Map<String, dynamic> ? rawRun : <String, dynamic>{};
    return ResearchRunSummary(
      runId: (run['runId'] ?? summary['runId'] ?? 'unknown').toString(),
      startedAt: DateTime.tryParse(
            (run['startedAt'] ?? summary['startedAt'] ?? '').toString(),
          ) ??
          DateTime.now(),
      status: (run['status'] ?? summary['status'] ?? 'unknown').toString(),
      sourcesFound: _asInt(run['sourcesFound'] ?? summary['sourcesFound']),
      sourcesAccepted:
          _asInt(run['sourcesAccepted'] ?? summary['sourcesAccepted']),
      newMaterials: _asInt(run['newMaterials'] ?? summary['newMaterials']),
      newMixes: _asInt(run['newMixes'] ?? summary['newMixes']),
      agentVersion:
          (run['agentVersion'] ?? summary['agentVersion'] ?? '').toString(),
      knowledgeVersion:
          (run['knowledgeVersion'] ?? summary['knowledgeVersion'] ?? '')
              .toString(),
    );
  }

  static ResearchDraftMix _parseDraft(Map<String, dynamic> raw) {
    final warnings = _asStringList(raw['warnings']);
    return ResearchDraftMix(
      code: (raw['code'] ?? '').toString(),
      nameAr: (raw['nameAr'] ?? raw['name_ar'] ?? '').toString(),
      status: (raw['status'] ?? 'research_draft').toString(),
      version: (raw['version'] ?? '1').toString(),
      topNotes: _asStringList(raw['topNotes'] ?? raw['top_notes']),
      heartNotes: _asStringList(raw['heartNotes'] ?? raw['heart_notes']),
      baseNotes: _asStringList(raw['baseNotes'] ?? raw['base_notes']),
      evidenceSummary: (raw['evidenceSummary'] ??
              raw['evidence_summary'] ??
              'ملخص الأدلة غير متوفر بعد من الخادم.')
          .toString(),
      warnings:
          warnings.isEmpty ? ResearchDraftMix.requiredWarnings : warnings,
      confidence: _confidenceLabel(raw['confidence']),
    );
  }

  static String _confidenceLabel(dynamic value) {
    if (value is num) return '${value.toString()}/100';
    if (value is String && value.trim().isNotEmpty) return value;
    return 'غير محددة';
  }

  static int _asInt(dynamic value) => value is num ? value.toInt() : 0;

  static List<String> _asStringList(dynamic value) => value is List
      ? value.map((e) => e.toString()).toList()
      : const <String>[];
}
