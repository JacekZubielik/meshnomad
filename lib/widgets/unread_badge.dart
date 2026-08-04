import 'package:flutter/material.dart';

import '../theme/mesh_tokens.dart';

class UnreadBadge extends StatelessWidget {
  final int count;

  const UnreadBadge({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    final display = count > 9999 ? '9999+' : count.toString();
    return Container(
      constraints: const BoxConstraints(minWidth: 20),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: MeshTokens.of(context).alert,
        borderRadius: BorderRadius.circular(MeshTokens.of(context).pill),
      ),
      child: Text(
        display,
        style: MeshTokens.of(context)
            .monoCaption(color: Colors.white)
            .copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}
