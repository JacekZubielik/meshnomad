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
    final WindaMessage? message = controller.messages.isEmpty
        ? null
        : controller.messages.first;

    return Positioned(
      top: topInset + controller.appBarHeight,
      left: 0,
      right: 0,
      child: WindaOverlay(
        child: message == null ? null : WindaMessageContent(message: message),
      ),
    );
  }
}
