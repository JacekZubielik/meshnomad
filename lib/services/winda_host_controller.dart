import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../widgets/winda_message.dart';

/// Shared across the whole app (registered once in `MaterialApp.navigatorObservers`
/// in `main.dart`) so [MeshScreenScaffold] can tell "a dialog/bottom sheet opened
/// over me" (a `PopupRoute`, does NOT fire `didPushNext`) apart from "a different
/// screen was pushed over me" (a `PageRoute`, DOES fire `didPushNext`) — see
/// `MeshScreenScaffold`'s doc comment and
/// docs/superpowers/specs/2026-09-01-winda-message-system-design.md's "Root
/// overlay" section (second revision) for why `ModalRoute.of(context)?.isCurrent`
/// cannot make this distinction (it goes `false` for both cases identically).
final windaRouteObserver = RouteObserver<PageRoute<dynamic>>();

/// Single app-wide registry for the message winda. Constructed once in
/// `main()` and provided via the root `MultiProvider`, same pattern as every
/// other app-wide service (`AppSettingsService`, etc.).
///
/// Exactly one screen's messages are shown at a time — whichever screen last
/// called [register]. [MeshScreenScaffold] is the only expected caller.
class WindaHostController extends ChangeNotifier {
  List<WindaMessage> _messages = const [];
  double _appBarHeight = 0;

  List<WindaMessage> get messages => _messages;
  double get appBarHeight => _appBarHeight;

  void register({
    required List<WindaMessage> messages,
    required double appBarHeight,
  }) {
    if (listEquals(_messages, messages) && _appBarHeight == appBarHeight) {
      return;
    }
    _messages = messages;
    _appBarHeight = appBarHeight;
    notifyListeners();
  }

  void unregister() {
    if (_messages.isEmpty) return;
    _messages = const [];
    notifyListeners();
  }
}
