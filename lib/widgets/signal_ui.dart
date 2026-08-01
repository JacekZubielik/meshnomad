import 'package:flutter/material.dart';
import '../theme/mesh_tokens.dart';

class SignalUi {
  final IconData icon;
  final Color color;

  const SignalUi({required this.icon, required this.color});
}

SignalUi signalUiForStrengthTier(BuildContext context, int tier) {
  switch (tier) {
    case 0:
      return SignalUi(
        icon: Icons.signal_cellular_4_bar,
        color: MeshTokens.of(context).signal,
      );
    case 1:
      return SignalUi(
        icon: Icons.signal_cellular_alt,
        color: MeshTokens.of(context).signalDim,
      );
    case 2:
      return SignalUi(
        icon: Icons.signal_cellular_alt_2_bar,
        color: MeshTokens.of(context).warn,
      );
    case 3:
      return SignalUi(
        icon: Icons.signal_cellular_alt_1_bar,
        color: MeshTokens.of(context).warnDim,
      );
    default:
      return SignalUi(
        icon: Icons.signal_cellular_alt_1_bar,
        color: MeshTokens.of(context).alert,
      );
  }
}
