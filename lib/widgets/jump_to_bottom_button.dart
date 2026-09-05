import 'package:flutter/material.dart';

import '../helpers/chat_scroll_controller.dart';
import '../theme/mesh_tokens.dart';

class JumpToBottomButton extends StatelessWidget {
  final ChatScrollController scrollController;

  const JumpToBottomButton({super.key, required this.scrollController});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = MeshTokens.of(context);
    return ValueListenableBuilder<bool>(
      valueListenable: scrollController.showJumpToBottom,
      builder: (context, show, _) {
        if (!show) return const SizedBox.shrink();
        return Positioned(
          right: 16,
          bottom: 16,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: scrollController.jumpToBottom,
              borderRadius: BorderRadius.circular(MeshTokens.of(context).pill),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.surfaceContainerHigh.withValues(alpha: 0.92),
                  // MeshCard rule: outline only when the style-wide shadow
                  // is off; shadow is the shared chip one (2026-09-05).
                  border: t.cardElevated
                      ? null
                      : Border.all(color: scheme.outlineVariant, width: 1),
                  boxShadow: t.labelShadow,
                ),
                child: Icon(
                  Icons.keyboard_arrow_down,
                  size: 22,
                  color: scheme.primary,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
