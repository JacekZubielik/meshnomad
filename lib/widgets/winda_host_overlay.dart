import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/winda_host_controller.dart';
import 'winda_message.dart';
import 'winda_overlay.dart';

/// The single, app-wide host for the message winda. Placed above the
/// `Navigator` in `main.dart`'s `MaterialApp.builder`, inside a `Stack`
/// alongside the Navigator's own content — ordinary `Stack` child paint
/// order (later children paint on top) is what guarantees this renders
/// above every route/dialog/bottom sheet the `Navigator` ever shows,
/// independent of insertion timing. See [WindaHostController] and
/// `MeshScreenScaffold` for how a screen registers its messages here.
class WindaHostOverlay extends StatelessWidget {
  const WindaHostOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<WindaHostController>();
    final topInset = MediaQuery.paddingOf(context).top;
    // Collapse while a dropdown menu is open (WindaMenuRouteObserver) — the
    // winda paints above the ENTIRE Navigator, so an open ⋮ menu would
    // otherwise end up partially underneath it (2026-09-02 feedback: the
    // menu must always be the topmost visible layer). Dialogs/sheets are
    // unaffected — validation messages still show over them, per the spec.
    final WindaMessage? message =
        (controller.menuOpen || controller.messages.isEmpty)
        ? null
        : controller.messages.first;

    return Positioned(
      top: topInset + controller.appBarHeight,
      left: 0,
      right: 0,
      // This subtree lives ABOVE the Navigator (MaterialApp.builder's
      // Stack), so it has NO Material ancestor — without one, Flutter
      // renders every Text in its "you forgot Material" fallback style:
      // yellow DOUBLE underline. That fallback was the "two stray lines in
      // an off-palette color" under the winda text that resisted several
      // wrong root-cause guesses (variable font, SelectionArea,
      // monoBody's fontFeatures) before being identified on 2026-09-02.
      // MaterialType.transparency contributes no visuals of its own — it
      // only restores the proper DefaultTextStyle context.
      child: Material(
        type: MaterialType.transparency,
        child: WindaOverlay(
          child: message == null ? null : WindaMessageContent(message: message),
        ),
      ),
    );
  }
}
