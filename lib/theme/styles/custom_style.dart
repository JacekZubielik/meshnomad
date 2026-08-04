import 'package:flutter/material.dart';

import '../../models/custom_style_overrides.dart';
import '../mesh_tokens.dart';
import '../style.dart';
import 'default_style.dart';

/// Builds the "custom" [MeshStyle] by layering [overrides] on top of
/// [defaultStyle]'s exact values. Absent keys, or keys with no known
/// matching field, silently fall back to the default value — never throws.
MeshStyle buildCustomStyle(CustomStyleOverrides overrides) {
  MeshTokens applyColorOverrides(MeshTokens base) {
    int? colorFor(String key) => overrides.colorOverrides[key];

    return base.copyWith(
      bg: colorFor('bg') != null ? Color(colorFor('bg')!) : null,
      ink: colorFor('ink') != null ? Color(colorFor('ink')!) : null,
      line: colorFor('line') != null ? Color(colorFor('line')!) : null,
      blue: colorFor('blue') != null ? Color(colorFor('blue')!) : null,
      magenta: colorFor('magenta') != null ? Color(colorFor('magenta')!) : null,
      signal: colorFor('signal') != null ? Color(colorFor('signal')!) : null,
      warn: colorFor('warn') != null ? Color(colorFor('warn')!) : null,
      alert: colorFor('alert') != null ? Color(colorFor('alert')!) : null,
      me: colorFor('me') != null ? Color(colorFor('me')!) : null,
      meInk: colorFor('meInk') != null ? Color(colorFor('meInk')!) : null,
    );
  }

  TextTheme applyFontSizeOverrides(TextTheme base) {
    double? sizeFor(String key) => overrides.fontSizeOverrides[key];

    return base.copyWith(
      bodyMedium: sizeFor('bodyMedium') != null
          ? base.bodyMedium?.copyWith(fontSize: sizeFor('bodyMedium'))
          : null,
      bodySmall: sizeFor('bodySmall') != null
          ? base.bodySmall?.copyWith(fontSize: sizeFor('bodySmall'))
          : null,
      titleSmall: sizeFor('titleSmall') != null
          ? base.titleSmall?.copyWith(fontSize: sizeFor('titleSmall'))
          : null,
      labelSmall: sizeFor('labelSmall') != null
          ? base.labelSmall?.copyWith(fontSize: sizeFor('labelSmall'))
          : null,
      labelMedium: sizeFor('labelMedium') != null
          ? base.labelMedium?.copyWith(fontSize: sizeFor('labelMedium'))
          : null,
    );
  }

  double monoCaptionSizeFor(MeshTokens base) =>
      overrides.fontSizeOverrides['monoCaptionSize'] ?? base.monoCaptionSize;
  double monoBodySizeFor(MeshTokens base) =>
      overrides.fontSizeOverrides['monoBodySize'] ?? base.monoBodySize;

  // MeshTokens.defaultTokens is shared between light/dark (see comment on
  // that field) — still true after 01-font-role-infra.md, so one override
  // pass covers both brightness variants.
  final tokens = applyColorOverrides(MeshTokens.defaultTokens).copyWith(
    monoCaptionSize: monoCaptionSizeFor(MeshTokens.defaultTokens),
    monoBodySize: monoBodySizeFor(MeshTokens.defaultTokens),
  );

  return MeshStyle(
    id: 'custom',
    displayName: 'Custom',
    light: defaultStyle.light.copyWith(
      extensions: [tokens],
      textTheme: applyFontSizeOverrides(defaultStyle.light.textTheme),
    ),
    dark: defaultStyle.dark.copyWith(
      extensions: [tokens],
      textTheme: applyFontSizeOverrides(defaultStyle.dark.textTheme),
    ),
  );
}
