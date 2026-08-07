import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meshcore_open/theme/mesh_derived.dart';
import 'package:meshcore_open/theme/mesh_theme.dart';
import 'package:meshcore_open/theme/mesh_tokens.dart';

void main() {
  group('mesh_derived parity with MeshTokens.defaultTokensLight', () {
    final defaults = MeshTokens.defaultTokensLight;

    test('bg layers match at light default base', () {
      final derived = deriveBgLayersLight(defaults.bg);
      expect(derived.bg1, defaults.bg1);
      expect(derived.bg2, defaults.bg2);
      expect(derived.bg3, defaults.bg3);
      expect(derived.bg4, defaults.bg4);
    });

    test('ink layers match at light default base', () {
      final derived = deriveInkLayersLight(defaults.ink);
      expect(derived.ink2, defaults.ink2);
      expect(derived.ink3, defaults.ink3);
      expect(derived.ink4, defaults.ink4);
    });

    test('line layers match at light default base', () {
      final derived = deriveLineLayersLight(defaults.line);
      expect(derived.line2, defaults.line2);
      expect(derived.line3, defaults.line3);
    });

    test('bg layers get darker (not lighter) on a light base', () {
      final derived = deriveBgLayersLight(defaults.bg);
      final l0 = HSLColor.fromColor(defaults.bg).lightness;
      final l1 = HSLColor.fromColor(derived.bg1).lightness;
      final l2 = HSLColor.fromColor(derived.bg2).lightness;
      final l3 = HSLColor.fromColor(derived.bg3).lightness;
      final l4 = HSLColor.fromColor(derived.bg4).lightness;
      expect(l1, lessThan(l0));
      expect(l2, lessThan(l1));
      expect(l3, lessThan(l2));
      expect(l4, lessThan(l3));
    });

    test('ink layers get lighter (not darker) on a light base', () {
      final derived = deriveInkLayersLight(defaults.ink);
      final l0 = HSLColor.fromColor(defaults.ink).lightness;
      final l2 = HSLColor.fromColor(derived.ink2).lightness;
      final l3 = HSLColor.fromColor(derived.ink3).lightness;
      final l4 = HSLColor.fromColor(derived.ink4).lightness;
      expect(l2, greaterThan(l0));
      expect(l3, greaterThan(l2));
      expect(l4, greaterThan(l3));
    });

    test('accent dims stay consistent with the shared derivers', () {
      expect(
        derivePrimaryVariants(defaults.primary).primaryDim,
        defaults.primaryDim,
      );
      expect(
        derivePrimaryVariants(defaults.primary).primaryBg,
        defaults.primaryBg,
      );
      expect(
        derivePrimaryVariants(defaults.primary).primaryLine,
        defaults.primaryLine,
      );
      expect(
        deriveSecondaryVariants(defaults.secondary).secondaryBg,
        defaults.secondaryBg,
      );
      expect(
        deriveSecondaryVariants(defaults.secondary).secondaryLine,
        defaults.secondaryLine,
      );
      expect(deriveWarnVariants(defaults.warn).warnDim, defaults.warnDim);
      expect(deriveWarnVariants(defaults.warn).warnBg, defaults.warnBg);
      expect(deriveWarnVariants(defaults.warn).warnLine, defaults.warnLine);
      expect(deriveAlertVariants(defaults.alert).alertBg, defaults.alertBg);
      expect(deriveAlertVariants(defaults.alert).alertLine, defaults.alertLine);
      expect(deriveSignalDim(defaults.signal), defaults.signalDim);
    });

    test('map/los/radii/mono fields are shared with the dark tokens', () {
      final dark = MeshTokens.defaultTokens;
      expect(defaults.mapOnline, dark.mapOnline);
      expect(defaults.losTerrain, dark.losTerrain);
      expect(defaults.lg, dark.lg);
      expect(defaults.pill, dark.pill);
      expect(defaults.monoCaptionSize, dark.monoCaptionSize);
      expect(defaults.monoBodySize, dark.monoBodySize);
    });

    test('light base tokens match MeshPalette.light* constants', () {
      expect(defaults.bg, MeshPalette.lightBg);
      expect(defaults.ink, MeshPalette.lightInk);
      expect(defaults.line, MeshPalette.lightLine1);
      expect(defaults.primary, MeshPalette.lightBlue);
    });
  });
}
