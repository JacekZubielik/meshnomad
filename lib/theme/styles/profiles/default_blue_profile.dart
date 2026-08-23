import '../../../models/custom_style_overrides.dart';
import '../theme_definition.dart';

/// "Blue" — the preserved ex-`default` look: renders
/// `MeshTokens.defaultTokens` (today's shipped blue palette) except where a
/// seed override below says otherwise.
const defaultBlueProfile = ColorProfileSeed(
  id: 'blue',
  displayName: 'Blue',
  overrides: CustomStyleOverrides(
    colorOverrides: {
      'secondary': 0xFF06B6D4, // operator-set 2026-08-23 (cyan accent)
    },
  ),
);
