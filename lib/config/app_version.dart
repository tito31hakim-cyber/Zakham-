/// Version identity of the running app (Priority 1 — pin the source).
///
/// The published build 29 is version 1.1.0+2 from commit 9291408.
/// Note the two different "build" numbers, kept explicit on purpose:
/// - [versionCode] is the Flutter build number from pubspec.yaml (the +2).
/// - [codemagicBuild] is the Codemagic build counter (29 for the published
///   build). They are not the same number and must not be confused.
class AppVersion {
  AppVersion._();

  /// Version name from pubspec.yaml (1.1.0).
  static const versionName = '1.1.0';

  /// Flutter build number from pubspec.yaml (the +2 in 1.1.0+2).
  static const versionCode = 2;

  /// Codemagic build counter of the published build (29).
  static const codemagicBuild = 29;

  /// Short commit SHA of the source this build was made from.
  ///
  /// Codemagic passes `--dart-define=ZAKHAM_COMMIT=<sha>` at build time;
  /// the fallback is the tagged commit of the published build 29
  /// (GitHub Release v1.1.0-build29).
  static const commit = String.fromEnvironment(
    'ZAKHAM_COMMIT',
    defaultValue: '9291408',
  );

  /// One-line display string for the account page footer, e.g.
  /// «الإصدار 1.1.0 (2) — بناء Codemagic 29 — Commit 9291408».
  static String get display =>
      'الإصدار $versionName ($versionCode) — بناء Codemagic $codemagicBuild — Commit $commit';
}
