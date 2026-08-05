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
