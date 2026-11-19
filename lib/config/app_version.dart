/// Version identity of the running app (Priority 1 — pin the source).
///
/// The version name stays V1.1 (1.1.0) — the version is one, not
/// thirty-two. The Codemagic build number (32) is only a label from
/// the release tag v1.1.0-build32, NOT the version.
/// Rule before every release: bump versionCode in pubspec by 1 and tag
/// the release v<versionName>-build<CodemagicBuildNumber>.
class AppVersion {
  AppVersion._();

  /// Version name from pubspec.yaml (1.1.0).
  static const versionName = '1.1.0';

  /// Flutter build number from pubspec.yaml (the +3 in 1.1.0+3).
  static const versionCode = 3;

  /// Codemagic build number of the published release (label only,
  /// from the release tag v1.1.0-build32).
  static const codemagicBuild = 32;

  /// Short commit SHA of the source this build was made from.
  ///
  /// Codemagic passes `--dart-define=ZAKHAM_COMMIT=<sha>` at build time;
  /// the fallback is the tagged commit of the published build 32
  /// (GitHub Release v1.1.0-build32). Update the fallback at each
  /// release so a build without the define still reports its source.
  static const commit = String.fromEnvironment(
    'ZAKHAM_COMMIT',
    defaultValue: 'ad26699',
  );

  /// نص التذييل للعميل — الإصدار فقط، بلا رقم بناء وبلا Commit:
  /// «الإصدار 1.1.0». التفاصيل للتشخيص فقط (انظر [display]).
  static String get customerDisplay => 'الإصدار $versionName';

  /// نص التشخيص الكامل (رقم البناء والـ Commit) — لا يظهر في واجهة
  /// العميل أبداً؛ يظهر فقط بضغطة مطولة على تذييل صفحة الحساب،
  /// مثال: «الإصدار 1.1.0 (3) — بناء Codemagic 32 — Commit ad26699».
  static String get display =>
      'الإصدار $versionName ($versionCode) — بناء Codemagic $codemagicBuild — Commit $commit';
}
