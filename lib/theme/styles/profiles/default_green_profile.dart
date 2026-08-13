import '../../../models/custom_style_overrides.dart';
import '../theme_definition.dart';

/// "Green" — the flagship terminal-green profile. Base hexes sampled from
/// the live custom theme on-device (2026-08-11); NOT hand-invented. Only
/// automat-input keys are set — bg1..bg4/ink2..ink4/line2..line3/*Dim/*Bg
/// /*Line are derived (see custom_style.dart applyColorOverrides).
const defaultGreenProfile = ColorProfileSeed(
  id: 'green',
  displayName: 'Green',
  overrides: CustomStyleOverrides(
    colorOverrides: {
      'bg': 0xFF16260A, // deep olive base — REFINE ON-DEVICE (Task 2 Step 4)
      'primary': 0xFFEAB308,
    },
  ),
);
