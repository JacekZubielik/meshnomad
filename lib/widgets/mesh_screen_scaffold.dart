import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/winda_host_controller.dart';
import 'winda_message.dart';

/// Scaffold wrapper that registers [messages] with the app-wide
/// [WindaHostController], which a single [WindaHostOverlay] (hosted above
/// the `Navigator` in `main.dart`) renders. A winda hosted inside the
/// `Navigator`'s own `Overlay` — via `OverlayPortal`, tried first — cannot
/// reliably paint above a dialog opened afterward, regardless of which
/// named overlay location it targets; hosting above the `Navigator`
/// entirely is what actually guarantees this. See
/// docs/superpowers/specs/2026-09-01-winda-message-system-design.md's
/// "Root overlay" section (revised) for the full account of why the first
/// attempt didn't work.
///
/// Only one message is shown at a time (`messages.first`); further entries
/// queue and appear once the current one is removed from the list by the
/// owning screen's state.
///
/// **Coverage tracking uses `RouteAware`/[windaRouteObserver], NOT
/// `ModalRoute.of(context)?.isCurrent`.** An earlier version of this widget
/// used `isCurrent`, on the assumption that only full-screen navigation would
/// flip it — that's wrong: `Route.isCurrent` means "top of the Navigator's
/// stack," and a dialog pushed via `showDialog` genuinely becomes the new top
/// of the *same* Navigator's stack, so `isCurrent` goes `false` the instant a
/// dialog opens — unregistering the message at exactly the moment it's
/// supposed to stay visible. `windaRouteObserver` (a
/// `RouteObserver<PageRoute>`) only fires `didPushNext()` when the route
/// pushed on top is itself a `PageRoute` — a `DialogRoute`/
/// `ModalBottomSheetRoute` is a `PopupRoute`, not a `PageRoute`, so opening
/// one does not fire it at all, and registration correctly stays intact.
class MeshScreenScaffold extends StatefulWidget {
  final PreferredSizeWidget? appBar;
  final Widget body;
  final List<WindaMessage> messages;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;

  const MeshScreenScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.messages = const [],
    this.floatingActionButton,
    this.bottomNavigationBar,
  });

  @override
  State<MeshScreenScaffold> createState() => _MeshScreenScaffoldState();
}

class _MeshScreenScaffoldState extends State<MeshScreenScaffold>
    with RouteAware {
  // Cached in didChangeDependencies (safe place to read an InheritedWidget-
  // backed value) rather than doing a fresh context.read() in dispose(),
  // which throws ("Looking up a deactivated widget's ancestor is unsafe")
  // once the widget is deactivated.
  WindaHostController? _controller;
  PageRoute<dynamic>? _subscribedRoute;
  bool _coveredByAnotherPage = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller = context.read<WindaHostController>();

    final route = ModalRoute.of(context);
    if (route is PageRoute<dynamic> && route != _subscribedRoute) {
      if (_subscribedRoute != null) {
        windaRouteObserver.unsubscribe(this);
      }
      windaRouteObserver.subscribe(this, route);
      _subscribedRoute = route;
    }

    _syncRegistration();
  }

  @override
  void didUpdateWidget(covariant MeshScreenScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncRegistration();
  }

  @override
  void didPushNext() {
    // A different PageRoute (a different screen) was pushed on top of this
    // one — this screen is no longer what the user sees, so give up the
    // display slot. A dialog/bottom sheet does NOT trigger this (it's a
    // PopupRoute, not a PageRoute) — see the class doc comment.
    _coveredByAnotherPage = true;
    _controller?.unregister();
  }

  @override
  void didPopNext() {
    // The page that was covering this one was popped — this screen is
    // visible again, so resume registering (messages may have changed
    // while covered).
    _coveredByAnotherPage = false;
    _syncRegistration();
  }

  @override
  void dispose() {
    windaRouteObserver.unsubscribe(this);
    // Deferred (not called synchronously here): unregistering directly can
    // run during a parent's build pass in some teardown orderings and hit
    // "setState()/markNeedsBuild() called during build" against
    // WindaHostOverlay, which lives in a different branch of the tree
    // (above the Navigator) and isn't covered by Flutter's "dirty
    // descendant during build" exception. mounted is false by the time this
    // runs, but _controller was cached while still valid, so this is safe.
    final controller = _controller;
    if (controller != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.unregister();
      });
    }
    super.dispose();
  }

  void _syncRegistration() {
    final controller = _controller;
    if (controller == null) return;
    // Deferred for the same reason as dispose() above: this can run during
    // a parent's build pass (didChangeDependencies/didUpdateWidget both
    // can), and WindaHostOverlay is not a descendant of whatever triggered
    // that build, so a synchronous notifyListeners() here throws.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_coveredByAnotherPage) {
        controller.unregister();
      } else {
        controller.register(
          messages: widget.messages,
          appBarHeight: widget.appBar?.preferredSize.height ?? 0,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.appBar,
      body: widget.body,
      floatingActionButton: widget.floatingActionButton,
      bottomNavigationBar: widget.bottomNavigationBar,
    );
  }
}
