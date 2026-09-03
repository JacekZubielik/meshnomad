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

/// Tracks whether a dropdown menu (a barrier-less [PopupRoute] — popup menus
/// don't dim the screen behind them, dialogs/bottom sheets do) is currently
/// open, so [WindaHostController] can hide the message winda for the
/// duration (2026-09-02 feedback: an open ⋮ menu must never be covered by
/// the winda; the winda is structurally ABOVE the entire Navigator, so the
/// only way to keep the menu unobstructed is to yield while one is open).
/// The `barrierColor == null` test is what keeps the spec's core scenario
/// intact: dialogs and sheets have a dim barrier, so validation messages
/// shown OVER an open dialog keep working exactly as designed.
class WindaMenuRouteObserver extends NavigatorObserver {
  WindaMenuRouteObserver(this._controller);

  final WindaHostController _controller;
  int _openMenus = 0;

  bool _isMenu(Route<dynamic>? route) =>
      route is PopupRoute && route.barrierColor == null;

  void _bump(int delta) {
    _openMenus = (_openMenus + delta).clamp(0, 1 << 30);
    _controller.setMenuOpen(_openMenus > 0);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_isMenu(route)) _bump(1);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_isMenu(route)) _bump(-1);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_isMenu(route)) _bump(-1);
  }
}

/// Single app-wide registry for the message winda. Constructed once in
/// `main()` and provided via the root `MultiProvider`, same pattern as every
/// other app-wide service (`AppSettingsService`, etc.).
///
/// Exactly one screen's messages are shown at a time — whichever screen last
/// called [register]. [MeshScreenScaffold] is the only expected caller.
/// [WindaHostOverlay] renders every entry in [messages] stacked, not just
/// the first (2026-09-02) — a blocking message no longer swallows later
/// ones.
class WindaHostController extends ChangeNotifier {
  List<WindaMessage> _messages = const [];
  double _appBarHeight = 0;
  bool _menuOpen = false;

  List<WindaMessage> get messages => _messages;
  double get appBarHeight => _appBarHeight;

  /// True while a dropdown menu is open (see [WindaMenuRouteObserver]) —
  /// [WindaHostOverlay] collapses the winda for the duration so the menu is
  /// never covered.
  bool get menuOpen => _menuOpen;

  void setMenuOpen(bool value) {
    if (_menuOpen == value) return;
    _menuOpen = value;
    notifyListeners();
  }

  void register({
    required List<WindaMessage> messages,
    required double appBarHeight,
  }) {
    if (listEquals(_messages, messages) && _appBarHeight == appBarHeight) {
      return;
    }
    // Defensive copy — never alias the caller's list. A screen that passes
    // its own mutable field (Channels' `_toastMessages`, 2026-09-03) and
    // later mutates it in place would otherwise mutate OUR list too, making
    // the next listEquals compare the list with itself and skip the notify.
    _messages = List.unmodifiable(messages);
    _appBarHeight = appBarHeight;
    notifyListeners();
  }

  void unregister() {
    if (_messages.isEmpty) return;
    _messages = const [];
    notifyListeners();
  }
}
