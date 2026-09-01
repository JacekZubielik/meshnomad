import 'package:flutter/material.dart';

import 'winda_message.dart';
import 'winda_overlay.dart';

/// Scaffold wrapper that renders [messages] as a message winda in the app's
/// ROOT overlay — the same layer `showDialog`/`showModalBottomSheet` use —
/// so a message stays visible even while a dialog or bottom sheet is open
/// above this screen. A winda embedded inside a screen's own `body` cannot
/// paint above an open dialog's modal barrier; targeting the root overlay
/// is what makes that possible. See
/// docs/superpowers/specs/2026-09-01-winda-message-system-design.md.
///
/// Only one message is shown at a time (`messages.first`); further entries
/// queue and appear once the current one is removed from the list by the
/// owning screen's state.
///
/// Known limitation: if more than one screen using `MeshScreenScaffold` is
/// simultaneously mounted in the navigation stack (e.g. screen A still has
/// an active message when screen B is pushed on top), screen A's winda can
/// remain visible in the shared root overlay. Not a risk yet — this plan
/// migrates Contacts only — but must be addressed (e.g. gating visibility
/// on `ModalRoute.of(context)?.isCurrent`) before a second screen adopts
/// this widget. Tracked in issue #144.
class MeshScreenScaffold extends StatefulWidget {
  final PreferredSizeWidget? appBar;
  final Widget body;
  final List<WindaMessage> messages;
  final Widget? floatingActionButton;

  const MeshScreenScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.messages = const [],
    this.floatingActionButton,
  });

  @override
  State<MeshScreenScaffold> createState() => _MeshScreenScaffoldState();
}

class _MeshScreenScaffoldState extends State<MeshScreenScaffold> {
  final _controller = OverlayPortalController(
    debugLabel: 'MeshScreenScaffold message winda',
  );

  @override
  void initState() {
    super.initState();
    _syncVisibility();
  }

  @override
  void didUpdateWidget(covariant MeshScreenScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncVisibility();
  }

  @override
  void dispose() {
    // show()/hide() require an attached state; guard in case dispose runs
    // before the first frame attaches this controller to its OverlayPortal.
    if (_controller.isShowing) _controller.hide();
    super.dispose();
  }

  // OverlayPortalController.show()/hide() assert when called while
  // SchedulerBinding.schedulerPhase == SchedulerPhase.persistentCallbacks
  // (flutter/lib/src/widgets/overlay.dart:2067-2086). didUpdateWidget runs
  // synchronously as part of that phase once the controller is attached to
  // its OverlayPortal (any parent setState that changes `messages` reaches
  // here mid-frame) — calling show()/hide() straight from didUpdateWidget
  // trips the assertion in real use, not just under test. Deferring to a
  // post-frame callback moves the call to SchedulerPhase.postFrameCallbacks,
  // outside the guarded phase, while still being driven only from
  // initState/didUpdateWidget — never from build() itself.
  void _syncVisibility() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.messages.isEmpty) {
        if (_controller.isShowing) _controller.hide();
      } else {
        if (!_controller.isShowing) _controller.show();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final appBarHeight = widget.appBar?.preferredSize.height ?? 0;

    return OverlayPortal(
      controller: _controller,
      overlayLocation: OverlayChildLocation.rootOverlay,
      overlayChildBuilder: (context) {
        final message = widget.messages.isEmpty ? null : widget.messages.first;
        return Positioned(
          top: topInset + appBarHeight,
          left: 0,
          right: 0,
          child: WindaOverlay(
            child: message == null
                ? null
                : WindaMessageContent(message: message),
          ),
        );
      },
      child: Scaffold(
        appBar: widget.appBar,
        body: widget.body,
        floatingActionButton: widget.floatingActionButton,
      ),
    );
  }
}
