import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/mesh_tokens.dart';

class UnreadDivider extends StatelessWidget {
  const UnreadDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = scheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Container(height: 1, color: color.withValues(alpha: 0.25)),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(MeshTokens.of(context).pill),
              border: Border.all(color: color.withValues(alpha: 0.35)),
            ),
            child: Text(
              context.l10n.chat_newMessages,
              style: MeshTokens.of(
                context,
              ).monoBody(fontWeight: FontWeight.w600, color: color),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(height: 1, color: color.withValues(alpha: 0.25)),
          ),
        ],
      ),
    );
  }
}
