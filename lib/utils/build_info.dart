/// Compile-time build provenance, injected with `--dart-define` by
/// `tool/build_apk.sh` (local builds) and the release workflow (CI builds).
/// A build made with plain `flutter build` carries no defines and reports
/// everything as unknown — the About screen then hides the detail rows it
/// cannot back up.
class BuildInfo {
  BuildInfo._();

  static const String gitSha = String.fromEnvironment(
    'GIT_SHA',
    defaultValue: 'unknown',
  );
  static const String gitBranch = String.fromEnvironment(
    'GIT_BRANCH',
    defaultValue: 'unknown',
  );
  static const bool gitDirty = bool.fromEnvironment('GIT_DIRTY');
  static const String buildTime = String.fromEnvironment(
    'BUILD_TIME',
    defaultValue: 'unknown',
  );

  /// 'local' or 'ci'.
  static const String buildSource = String.fromEnvironment(
    'BUILD_SOURCE',
    defaultValue: 'local',
  );

  static const bool hasDetails = gitSha != 'unknown';
  static bool get isCi => buildSource == 'ci';
}
