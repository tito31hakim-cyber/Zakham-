/// Version identity of the running app (Priority 1 — pin the source).
///
/// The version name stays V1.1 (1.1.0) — the version is one, not
/// thirty-eight. The Codemagic build number (38) is only a label from
/// the release tag v1.1.0-build38, NOT the version.
/// Rule before every release: bump versionCode in pubspec by 1 and tag
/// the release v<versionName>-build<CodemagicBuildNumber>.
class AppVersion {
  AppVersion._();

  /// Version name from pubspec.yaml (1.1.0).
  static const versionName = '1.1.0';

  /// Flutter build number from pubspec.yaml (the +8 in 1.1.0+8).
  static const versionCode = 8;

  /// Codemagic build number of the published release (label only,
  /// from the release tag v1.1.0-build38).
  static const codemagicBuild = 38;

  /// Short commit SHA of the source this build was made from.
  ///
  /// Codemagic passes `--dart-define=ZAKHAM_COMMIT=<sha>` at build time;
  /// the fallback is the tagged commit of the published build 38
  /// (GitHub Release v1.1.0-build38). Update the fallback at each
  /// release so a build without the define still reports its source.
  static const commit = String.fromEnvironment(
    'ZAKHAM_COMMIT',
    defaultValue: 'c7e0343',
  );

  /// نص التذييل للعميل — الإصدار فقط، بلا رقم بناء وبلا Commit:
  /// «الإصدار 1.1.0». التفاصيل للتشخيص فقط (انظر [display]).
  static String get customerDisplay => 'الإصدار $versionName';

  /// نص التشخيص الكامل (رقم البناء والـ Commit) — لا يظهر في واجهة
  /// العميل أبداً؛ يظهر فقط بضغطة مطولة على تذييل صفحة الحساب،
  /// مثال: «الإصدار 1.1.0 (5) — بناء Codemagic 35 — Commit fb1c6e2».
  static String get display =>
      'الإصدار $versionName ($versionCode) — بناء Codemagic $codemagicBuild — Commit $commit';
}
