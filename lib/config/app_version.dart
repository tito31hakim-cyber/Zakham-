/// Version identity of the running app (Priority 1 — pin the source).
///
/// There is exactly ONE build number: the Flutter versionCode from
/// pubspec.yaml (the +29 in 1.1.0+29). The Codemagic run counter (#30,
/// #31, ...) is NOT a build number and is never displayed anywhere.
/// Rule before every release: bump versionCode in pubspec by 1 and tag
/// the release v<versionName>-build<versionCode>.
class AppVersion {
  AppVersion._();

  /// Version name from pubspec.yaml (1.1.0).
  static const versionName = '1.1.0';

  /// THE build number: Flutter build number from pubspec.yaml
  /// (the +29 in 1.1.0+29). Codemagic passes it explicitly with
  /// --build-name/--build-number so the APK numbers always come
  /// from pubspec, never from the Codemagic run counter.
  static const versionCode = 29;

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
  /// «الإصدار 1.1.0 (29) — Commit 9291408».
  static String get display =>
      'الإصدار $versionName ($versionCode) — Commit $commit';
}
