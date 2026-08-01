import 'package:flutter/material.dart';

import '../helpers/chat_scroll_controller.dart';
import '../theme/mesh_tokens.dart';

class JumpToBottomButton extends StatelessWidget {
  final ChatScrollController scrollController;

  const JumpToBottomButton({super.key, required this.scrollController});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
                  border: Border.all(color: scheme.outlineVariant, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
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
