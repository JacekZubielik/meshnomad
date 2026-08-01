import 'package:flutter/material.dart';

/// One selectable visual style: a display name plus the light/dark
/// [ThemeData] pair (each carrying a [MeshTokens] via [ThemeData.extensions]).
class MeshStyle {
  MeshStyle({
    required this.id,
    required this.displayName,
    required this.light,
    required this.dark,
  });

  /// Stable identifier persisted in `AppSettings.styleId`. Never rename an
  /// existing id — that silently resets users to the `default` fallback
  /// (see `StyleRegistry.byId`).
  final String id;

  final String displayName;
  final ThemeData light;
  final ThemeData dark;
}
