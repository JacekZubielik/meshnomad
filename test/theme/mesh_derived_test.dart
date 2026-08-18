import 'package:flutter_test/flutter_test.dart';
import 'package:meshnomad/theme/mesh_derived.dart';
import 'package:meshnomad/theme/mesh_tokens.dart';

void main() {
  group('mesh_derived parity with MeshTokens.defaultTokens', () {
    final defaults = MeshTokens.defaultTokens;

    test('primary variants match at default base', () {
      final derived = derivePrimaryVariants(defaults.primary);
      expect(derived.primaryDim, defaults.primaryDim);
      expect(derived.primaryBg, defaults.primaryBg);
      expect(derived.primaryLine, defaults.primaryLine);
    });

    test('secondary variants match at default base', () {
      final derived = deriveSecondaryVariants(defaults.secondary);
      expect(derived.secondaryBg, defaults.secondaryBg);
      expect(derived.secondaryLine, defaults.secondaryLine);
    });

    test('warn variants match at default base', () {
      final derived = deriveWarnVariants(defaults.warn);
      expect(derived.warnDim, defaults.warnDim);
      expect(derived.warnBg, defaults.warnBg);
      expect(derived.warnLine, defaults.warnLine);
    });

    test('alert variants match at default base', () {
      final derived = deriveAlertVariants(defaults.alert);
      expect(derived.alertBg, defaults.alertBg);
      expect(derived.alertLine, defaults.alertLine);
    });

    test('signal dim matches at default base', () {
      expect(deriveSignalDim(defaults.signal), defaults.signalDim);
    });

    test('bg layers match at default base', () {
      final derived = deriveBgLayers(defaults.bg);
      expect(derived.bg1, defaults.bg1);
      expect(derived.bg2, defaults.bg2);
      expect(derived.bg3, defaults.bg3);
      expect(derived.bg4, defaults.bg4);
    });

    test('ink layers match at default base', () {
      final derived = deriveInkLayers(defaults.ink);
      expect(derived.ink2, defaults.ink2);
      expect(derived.ink3, defaults.ink3);
      expect(derived.ink4, defaults.ink4);
    });

    test('line layers match at default base', () {
      final derived = deriveLineLayers(defaults.line);
      expect(derived.line2, defaults.line2);
      expect(derived.line3, defaults.line3);
    });
  });
}
