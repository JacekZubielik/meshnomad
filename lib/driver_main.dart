// flutter_driver is a dev_dependency on purpose — this entry point is never
// used by the normal `lib/main.dart` release path, only by explicit
// `flutter run -t lib/driver_main.dart` debug sessions.
// ignore_for_file: depend_on_referenced_packages
import 'package:flutter_driver/driver_extension.dart';

import 'main.dart' as app;

/// Entry point for agent/driver-controlled UI sessions (tap, scroll,
/// screenshot via `flutter_driver_command` over the Dart MCP server). Run
/// with `flutter run -t lib/driver_main.dart` instead of the normal
/// `lib/main.dart` — the regular entry point stays untouched so release
/// builds never link in `flutter_driver`. See skill
/// flutter-ui-testing-meshcore for the full live-driving workflow.
void main() {
  enableFlutterDriverExtension();
  app.main();
}
