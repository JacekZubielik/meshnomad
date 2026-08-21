import 'package:flutter/material.dart';

import '../theme/mesh_tokens.dart';
import 'dotted_separator.dart';

/// App-wide replacement for plain separator [Divider] lines — dashed, in the
/// style's secondary accent so it follows the active color profile
/// (2026-08-21 refinement, first applied on the Settings screen).
///
/// NOT for: button/card borders, map overlay rules (own palette), the
/// danger-zone alert rule, Custom Style editor preview lines, or
/// [UnreadDivider] — those keep their dedicated colors on purpose.
///
/// [space] mirrors Divider's `height`: the total vertical footprint with the
/// 1px dashed line centered inside it.
class MeshDashedDivider extends StatelessWidget {
  final double indent;
  final double endIndent;
  final double space;

  const MeshDashedDivider({
    super.key,
    this.indent = 0,
    this.endIndent = 0,
    this.space = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: indent, right: endIndent),
      child: SizedBox(
        height: space,
        child: Center(
          child: DottedSeparator(color: MeshTokens.of(context).secondary),
        ),
      ),
    );
  }
}
