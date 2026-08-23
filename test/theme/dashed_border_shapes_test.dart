import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:meshnomad/theme/dashed_rounded_border.dart';

// Regression coverage for the exact bug class that made 'dotted' buttons
// silently render as solid (2026-08-23, root-caused in
// dashed_rounded_border.dart's doc comment): a ShapeBorder subclass that
// doesn't override copyWith/lerpFrom/lerpTo loses its identity the moment
// anything calls those inherited methods, even though every other property
// (including a WidgetStateProperty.resolve() at the theme level) stays
// correct. These are unit-level checks; button_border_rendering_test.dart
// covers the same class end-to-end through a real widget tree.
void main() {
  group('DashedRoundedRectangleBorder', () {
    test('copyWith preserves the subclass and dash/gap', () {
      const border = DashedRoundedRectangleBorder(
        side: BorderSide(color: Colors.red),
        dash: 5,
        gap: 2,
      );
      final copy = border.copyWith(side: const BorderSide(color: Colors.blue));
      expect(copy, isA<DashedRoundedRectangleBorder>());
      expect(copy.dash, 5);
      expect(copy.gap, 2);
      expect(copy.side.color, Colors.blue);
    });

    test('lerpFrom/lerpTo preserve the subclass', () {
      const border = DashedRoundedRectangleBorder();
      expect(
        border.lerpFrom(const RoundedRectangleBorder(), 0.5),
        isA<DashedRoundedRectangleBorder>(),
      );
      expect(
        border.lerpTo(const RoundedRectangleBorder(), 0.5),
        isA<DashedRoundedRectangleBorder>(),
      );
    });
  });

  group('DashedCircleBorder', () {
    test('copyWith preserves the subclass and dash/gap', () {
      const border = DashedCircleBorder(
        side: BorderSide(color: Colors.red),
        dash: 5,
        gap: 2,
      );
      final copy = border.copyWith(side: const BorderSide(color: Colors.blue));
      expect(copy, isA<DashedCircleBorder>());
      expect(copy.dash, 5);
      expect(copy.gap, 2);
      expect(copy.side.color, Colors.blue);
    });

    test('lerpFrom/lerpTo preserve the subclass', () {
      const border = DashedCircleBorder();
      expect(
        border.lerpFrom(const CircleBorder(), 0.5),
        isA<DashedCircleBorder>(),
      );
      expect(
        border.lerpTo(const CircleBorder(), 0.5),
        isA<DashedCircleBorder>(),
      );
    });
  });
}
