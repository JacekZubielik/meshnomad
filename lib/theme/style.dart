import 'package:flutter/material.dart';

/// One selectable visual style: a display name plus its single [ThemeData]
/// (carrying a [MeshTokens] via [ThemeData.extensions]). Brightness is
/// baked into [theme] — it is a property of the style, not a separate
/// runtime toggle (design spec 2026-08-12).
class MeshStyle {
  MeshStyle({required this.id, required this.displayName, required this.theme});

  /// Stable identifier — see StyleRegistry / AppSettings.activeProfileId.
  final String id;
  final String displayName;
  final ThemeData theme;
}
