/// Pure functions deriving the "variant" [MeshTokens] fields (dim shades,
/// alpha-blended backgrounds/lines, and surface/text/divider layers) from
/// the small set of base colors a user can actually edit in the custom
/// style editor (`bg`, `ink`, `line`, `primary`, `secondary`, `warn`,
/// `alert`, `signal`). See decisions A5/A6 in
/// `docs/superpowers/notes/2026-08-04-custom-style-decisions-todo.md`.
///
/// The HSL shift/ratio constants below were measured from today's
/// hand-picked [MeshPalette] pairs (e.g. `primary` → `primaryDim`) so that,
/// applied to the *default* base colors, they reproduce the exact existing
/// ARGB values bit-for-bit (see `test/theme/mesh_derived_test.dart`).
/// Applied to a user-customized base, they produce a consistent shift in
/// the same style rather than an arbitrary one.
library;

import 'package:flutter/material.dart';

/// Rotates/scales [base] in HSL space and returns the resulting [Color].
/// Shared by every "single dim shade" deriver below.
Color _deriveHsl(
  Color base, {
  required double hueShiftDegrees,
  required double saturationRatio,
  required double lightnessRatio,
}) {
  final hsl = HSLColor.fromColor(base);
  return HSLColor.fromAHSL(
    hsl.alpha,
    (hsl.hue + hueShiftDegrees) % 360.0,
    (hsl.saturation * saturationRatio).clamp(0.0, 1.0),
    (hsl.lightness * lightnessRatio).clamp(0.0, 1.0),
  ).toColor();
}

/// Returns [base] with its alpha channel replaced — used for the `*Bg`/
/// `*Line` alpha-blended variants, which are just the base hue at a fixed
/// opacity (measured from `MeshPalette.primaryBg`/`primaryLine` etc.).
Color _withAlphaByte(Color base, int alphaByte) {
  return base.withAlpha(alphaByte);
}

// ── Primary (measured from MeshPalette.primary/primaryDim/primaryBg/primaryLine) ──
const double _kPrimaryDimHueShift = 1.7759543842570338;
const double _kPrimaryDimSaturationRatio = 1.1054090279197621;
const double _kPrimaryDimLightnessRatio = 0.8137651821862348;
const int _kPrimaryBgAlpha = 0x29;
const int _kPrimaryLineAlpha = 0x80;

/// Derives `primaryDim`/`primaryBg`/`primaryLine` from the base `primary`.
({Color primaryDim, Color primaryBg, Color primaryLine}) derivePrimaryVariants(
  Color primary,
) {
  return (
    primaryDim: _deriveHsl(
      primary,
      hueShiftDegrees: _kPrimaryDimHueShift,
      saturationRatio: _kPrimaryDimSaturationRatio,
      lightnessRatio: _kPrimaryDimLightnessRatio,
    ),
    primaryBg: _withAlphaByte(primary, _kPrimaryBgAlpha),
    primaryLine: _withAlphaByte(primary, _kPrimaryLineAlpha),
  );
}

// ── Secondary (measured from MeshPalette.secondaryBg/secondaryLine) ──
const int _kSecondaryBgAlpha = 0x1C;
const int _kSecondaryLineAlpha = 0x47;

/// Derives `secondaryBg`/`secondaryLine` from the base `secondary`. There is
/// no `secondaryDim` today (only `primary` has a dim shade).
({Color secondaryBg, Color secondaryLine}) deriveSecondaryVariants(
  Color secondary,
) {
  return (
    secondaryBg: _withAlphaByte(secondary, _kSecondaryBgAlpha),
    secondaryLine: _withAlphaByte(secondary, _kSecondaryLineAlpha),
  );
}

// ── Warn (measured from MeshPalette.warn/warnDim/warnBg/warnLine) ──
const double _kWarnDimHueShift = -5.559606270506748;
const double _kWarnDimSaturationRatio = 1.0270591391667625;
const double _kWarnDimLightnessRatio = 0.87109375;
const int _kWarnBgAlpha = 0x1F;
const int _kWarnLineAlpha = 0x66;

/// Derives `warnDim`/`warnBg`/`warnLine` from the base `warn`.
({Color warnDim, Color warnBg, Color warnLine}) deriveWarnVariants(Color warn) {
  return (
    warnDim: _deriveHsl(
      warn,
      hueShiftDegrees: _kWarnDimHueShift,
      saturationRatio: _kWarnDimSaturationRatio,
      lightnessRatio: _kWarnDimLightnessRatio,
    ),
    warnBg: _withAlphaByte(warn, _kWarnBgAlpha),
    warnLine: _withAlphaByte(warn, _kWarnLineAlpha),
  );
}

// ── Alert (measured from MeshPalette.alertBg/alertLine) ──
const int _kAlertBgAlpha = 0x1F;
const int _kAlertLineAlpha = 0x66;

/// Derives `alertBg`/`alertLine` from the base `alert`. There is no
/// `alertDim` today.
({Color alertBg, Color alertLine}) deriveAlertVariants(Color alert) {
  return (
    alertBg: _withAlphaByte(alert, _kAlertBgAlpha),
    alertLine: _withAlphaByte(alert, _kAlertLineAlpha),
  );
}

// ── Signal (measured from MeshPalette.signal/signalDim) ──
const double _kSignalDimHueShift = 0.041770003915928555;
const double _kSignalDimSaturationRatio = 1.0801193831868676;
const double _kSignalDimLightnessRatio = 0.8008658008658008;

/// Derives `signalDim` from the base `signal`.
Color deriveSignalDim(Color signal) {
  return _deriveHsl(
    signal,
    hueShiftDegrees: _kSignalDimHueShift,
    saturationRatio: _kSignalDimSaturationRatio,
    lightnessRatio: _kSignalDimLightnessRatio,
  );
}

// ── Surface layers (measured from MeshPalette.bg/bg1/bg2/bg3/bg4) ──
const double _kBg1HueShift = 2.2222222222222285;
const double _kBg1SaturationRatio = 0.9699248120300756;
const double _kBg1LightnessRatio = 1.3255813953488371;
const double _kBg2HueShift = -0.6896551724137794;
const double _kBg2SaturationRatio = 0.8134377038486632;
const double _kBg2LightnessRatio = 1.6976744186046508;
const double _kBg3HueShift = -2.7586206896551744;
const double _kBg3SaturationRatio = 0.6672017121455328;
const double _kBg3LightnessRatio = 2.069767441860465;
const double _kBg4HueShift = -4.70588235294116;
const double _kBg4SaturationRatio = 0.511904761904762;
const double _kBg4LightnessRatio = 3.1627906976744184;

/// Derives the `bg1`/`bg2`/`bg3`/`bg4` surface layers from the base `bg`.
({Color bg1, Color bg2, Color bg3, Color bg4}) deriveBgLayers(Color bg) {
  return (
    bg1: _deriveHsl(
      bg,
      hueShiftDegrees: _kBg1HueShift,
      saturationRatio: _kBg1SaturationRatio,
      lightnessRatio: _kBg1LightnessRatio,
    ),
    bg2: _deriveHsl(
      bg,
      hueShiftDegrees: _kBg2HueShift,
      saturationRatio: _kBg2SaturationRatio,
      lightnessRatio: _kBg2LightnessRatio,
    ),
    bg3: _deriveHsl(
      bg,
      hueShiftDegrees: _kBg3HueShift,
      saturationRatio: _kBg3SaturationRatio,
      lightnessRatio: _kBg3LightnessRatio,
    ),
    bg4: _deriveHsl(
      bg,
      hueShiftDegrees: _kBg4HueShift,
      saturationRatio: _kBg4SaturationRatio,
      lightnessRatio: _kBg4LightnessRatio,
    ),
  );
}

// ── Text layers (measured from MeshPalette.ink/ink2/ink3/ink4) ──
const double _kInk2HueShift = 2.9999999999997726;
const double _kInk2SaturationRatio = 0.7812499999999939;
const double _kInk2LightnessRatio = 0.8919999999999999;
const double _kInk3HueShift = 4.28571428571405;
const double _kInk3SaturationRatio = 0.49295774647887;
const double _kInk3LightnessRatio = 0.736;
const double _kInk4HueShift = 6.36363636363609;
const double _kInk4SaturationRatio = 0.38018433179723227;
const double _kInk4LightnessRatio = 0.586;

/// Derives the `ink2`/`ink3`/`ink4` text layers from the base `ink`.
({Color ink2, Color ink3, Color ink4}) deriveInkLayers(Color ink) {
  return (
    ink2: _deriveHsl(
      ink,
      hueShiftDegrees: _kInk2HueShift,
      saturationRatio: _kInk2SaturationRatio,
      lightnessRatio: _kInk2LightnessRatio,
    ),
    ink3: _deriveHsl(
      ink,
      hueShiftDegrees: _kInk3HueShift,
      saturationRatio: _kInk3SaturationRatio,
      lightnessRatio: _kInk3LightnessRatio,
    ),
    ink4: _deriveHsl(
      ink,
      hueShiftDegrees: _kInk4HueShift,
      saturationRatio: _kInk4SaturationRatio,
      lightnessRatio: _kInk4LightnessRatio,
    ),
  );
}

// ── Divider layers (measured from MeshPalette.line/line2/line3) ──
const double _kLine2HueShift = -1.578947368421069;
const double _kLine2SaturationRatio = 0.7820512820512818;
const double _kLine2LightnessRatio = 1.278688524590164;
const double _kLine3HueShift = -4.365325077399405;
const double _kLine3SaturationRatio = 0.5403856175091194;
const double _kLine3LightnessRatio = 1.655737704918033;

/// Derives the `line2`/`line3` divider layers from the base `line`.
({Color line2, Color line3}) deriveLineLayers(Color line) {
  return (
    line2: _deriveHsl(
      line,
      hueShiftDegrees: _kLine2HueShift,
      saturationRatio: _kLine2SaturationRatio,
      lightnessRatio: _kLine2LightnessRatio,
    ),
    line3: _deriveHsl(
      line,
      hueShiftDegrees: _kLine3HueShift,
      saturationRatio: _kLine3SaturationRatio,
      lightnessRatio: _kLine3LightnessRatio,
    ),
  );
}

// ── Light-variant layer derivers (pkt 17) ──────────────────────────────────
// The dark constants above are directional (bg layers LIGHTEN the base); on a
// light base (lightness ≈0.965) they clamp to white. These constants were
// measured 2026-08-07 from the light ramp
// lightBg → lightBg1 → lightBg2 → lightBg3 → lightBg4,
// lightInk → lightInk2 → lightInk3 → lightInk4,
// lightLine1 → lightLine2 → lightLine3,
// the same way the dark ones were (bit-for-bit reproduction — see
// test/theme/mesh_derived_light_test.dart). Accent derivers above stay shared
// between brightnesses (dim = darken works on light accents too).

const double _kBg1LightHueShift = -1.1368683772161603e-13;
const double _kBg1LightSaturationRatio = 1.0588235294117656;
const double _kBg1LightLightnessRatio = 0.967479674796748;
const double _kBg2LightHueShift = -2.727272727272805;
const double _kBg2LightSaturationRatio = 0.9339622641509433;
const double _kBg2LightLightnessRatio = 0.928861788617886;
const double _kBg3LightHueShift = -1.9999999999999716;
const double _kBg3LightSaturationRatio = 0.9000000000000015;
const double _kBg3LightLightnessRatio = 0.8841463414634146;
const double _kBg4LightHueShift = 0.0;
const double _kBg4LightSaturationRatio = 0.8437500000000012;
const double _kBg4LightLightnessRatio = 0.8414634146341463;

/// Light-variant `bg1..bg4` — layers get DARKER as they stack on a light base.
({Color bg1, Color bg2, Color bg3, Color bg4}) deriveBgLayersLight(Color bg) {
  return (
    bg1: _deriveHsl(
      bg,
      hueShiftDegrees: _kBg1LightHueShift,
      saturationRatio: _kBg1LightSaturationRatio,
      lightnessRatio: _kBg1LightLightnessRatio,
    ),
    bg2: _deriveHsl(
      bg,
      hueShiftDegrees: _kBg2LightHueShift,
      saturationRatio: _kBg2LightSaturationRatio,
      lightnessRatio: _kBg2LightLightnessRatio,
    ),
    bg3: _deriveHsl(
      bg,
      hueShiftDegrees: _kBg3LightHueShift,
      saturationRatio: _kBg3LightSaturationRatio,
      lightnessRatio: _kBg3LightLightnessRatio,
    ),
    bg4: _deriveHsl(
      bg,
      hueShiftDegrees: _kBg4LightHueShift,
      saturationRatio: _kBg4LightSaturationRatio,
      lightnessRatio: _kBg4LightLightnessRatio,
    ),
  );
}

const double _kInk2LightHueShift = 1.4229249011858087;
const double _kInk2LightSaturationRatio = 0.6287349014621744;
const double _kInk2LightLightnessRatio = 3.325581395348837;
const double _kInk3LightHueShift = -2.727272727272691;
const double _kInk3LightSaturationRatio = 0.370689655172414;
const double _kInk3LightLightnessRatio = 5.395348837209302;
const double _kInk4LightHueShift = -4.772727272727366;
const double _kInk4LightSaturationRatio = 0.23337856173677074;
const double _kInk4LightLightnessRatio = 8.744186046511627;

/// Light-variant `ink2..ink4` — secondary text gets LIGHTER on a light base.
({Color ink2, Color ink3, Color ink4}) deriveInkLayersLight(Color ink) {
  return (
    ink2: _deriveHsl(
      ink,
      hueShiftDegrees: _kInk2LightHueShift,
      saturationRatio: _kInk2LightSaturationRatio,
      lightnessRatio: _kInk2LightLightnessRatio,
    ),
    ink3: _deriveHsl(
      ink,
      hueShiftDegrees: _kInk3LightHueShift,
      saturationRatio: _kInk3LightSaturationRatio,
      lightnessRatio: _kInk3LightLightnessRatio,
    ),
    ink4: _deriveHsl(
      ink,
      hueShiftDegrees: _kInk4LightHueShift,
      saturationRatio: _kInk4LightSaturationRatio,
      lightnessRatio: _kInk4LightLightnessRatio,
    ),
  );
}

const double _kLine2LightHueShift = -4.072398190045334;
const double _kLine2LightSaturationRatio = 0.825242718446603;
const double _kLine2LightLightnessRatio = 0.9146067415730338;
const double _kLine3LightHueShift = -7.044534412955528;
const double _kLine3LightSaturationRatio = 0.6934306569343068;
const double _kLine3LightLightnessRatio = 0.8382022471910113;

/// Light-variant `line2`/`line3` — dividers get DARKER on a light base.
({Color line2, Color line3}) deriveLineLayersLight(Color line) {
  return (
    line2: _deriveHsl(
      line,
      hueShiftDegrees: _kLine2LightHueShift,
      saturationRatio: _kLine2LightSaturationRatio,
      lightnessRatio: _kLine2LightLightnessRatio,
    ),
    line3: _deriveHsl(
      line,
      hueShiftDegrees: _kLine3LightHueShift,
      saturationRatio: _kLine3LightSaturationRatio,
      lightnessRatio: _kLine3LightLightnessRatio,
    ),
  );
}
