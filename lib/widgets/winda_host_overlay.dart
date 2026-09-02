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
///
/// Renders every entry in [WindaHostController.messages] (not just the
/// first) stacked top-to-bottom — e.g. a blocking stall error stays put
/// while later toasts queue up as further windas below it, rather than
/// being swallowed while the blocking one is showing (2026-09-02
/// feedback). Only the topmost card needs [windaShadowOverlap] — it's the
/// one sitting directly under whatever real screen content (search field,
/// progress card) is above the whole stack; none of the windas below it
/// cast a shadow of their own (`WindaOverlay`'s doc comment), so there's
/// nothing for the rest of the stack to cover.
class WindaHostOverlay extends StatelessWidget {
  const WindaHostOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<WindaHostController>();
    final topInset = MediaQuery.paddingOf(context).top;
    final scheme = Theme.of(context).colorScheme;
    // Collapse while a dropdown menu is open (WindaMenuRouteObserver) — the
    // winda paints above the ENTIRE Navigator, so an open ⋮ menu would
    // otherwise end up partially underneath it (2026-09-02 feedback: the
    // menu must always be the topmost visible layer). Dialogs/sheets are
    // unaffected — validation messages still show over them, per the spec.
    final List<WindaMessage> visible = (controller.menuOpen)
        ? const []
        : controller.messages;

    return Positioned(
      // Shifted up by windaShadowOverlap (only when something is actually
      // shown) so the topmost card's own background extends into the
      // search/progress card's shadow bleed instead of leaving it exposed
      // above the winda — see windaShadowOverlap's doc comment.
      top:
          topInset +
          controller.appBarHeight -
          (visible.isEmpty ? 0 : windaShadowOverlap),
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
        child: visible.isEmpty
            ? const WindaOverlay(child: null)
            : ClipRect(
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOut,
                  alignment: Alignment.topCenter,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < visible.length; i++)
                        ColoredBox(
                          key: ValueKey(visible[i]),
                          color: scheme.surface,
                          child: Padding(
                            padding: i == 0
                                ? const EdgeInsets.only(top: windaShadowOverlap)
                                : EdgeInsets.zero,
                            child: WindaMessageContent(message: visible[i]),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
