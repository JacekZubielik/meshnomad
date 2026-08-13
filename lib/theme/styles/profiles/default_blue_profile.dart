import '../../../models/custom_style_overrides.dart';
import '../theme_definition.dart';

/// "Blue" — the preserved ex-`default` look. Empty overrides: renders
/// exactly `MeshTokens.defaultTokens` (today's shipped blue palette).
const defaultBlueProfile = ColorProfileSeed(
  id: 'blue',
  displayName: 'Blue',
  overrides: CustomStyleOverrides(),
);
