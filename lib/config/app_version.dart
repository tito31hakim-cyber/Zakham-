/// Version identity of the running app (Priority 1 — pin the source).
///
/// The version name stays V1.1 (1.1.0) — the version is one, not
/// twenty-nine. The Codemagic build number (29) is only a label from
/// the release tag v1.1.0-build29, NOT the version.
/// Rule before every release: bump versionCode in pubspec by 1 and tag
/// the release v<versionName>-build<CodemagicBuildNumber>.
class AppVersion {
  AppVersion._();

  /// Version name from pubspec.yaml (1.1.0).
  static const versionName = '1.1.0';

  /// Flutter build number from pubspec.yaml (the +2 in 1.1.0+2).
  static const versionCode = 2;

  /// Codemagic build number of the published release (label only,
  /// from the release tag v1.1.0-build29).
  static const codemagicBuild = 29;

  /// Short commit SHA of the source this build was made from.
  ///
  /// Codemagic passes `--dart-define=ZAKHAM_COMMIT=<sha>` at build time;
  /// the fallback is the tagged commit of the published build 29
  /// (GitHub Release v1.1.0-build29). Update the fallback at each
  /// release so a build without the define still reports its source.
  static const commit = String.fromEnvironment(
    'ZAKHAM_COMMIT',
    defaultValue: '9291408',
  );

  /// One-line display string for the account page footer, e.g.
  /// «الإصدار 1.1.0 (2) — بناء Codemagic 29 — Commit 9291408».
  static String get display =>
      'الإصدار $versionName ($versionCode) — بناء Codemagic $codemagicBuild — Commit $commit';
}
