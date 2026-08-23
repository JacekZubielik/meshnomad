import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:meshnomad/models/custom_style_overrides.dart';
import 'package:meshnomad/theme/styles/custom_style.dart';

void main() {
  Future<Material> pumpFilledButtonMaterial(
    WidgetTester tester,
    CustomStyleOverrides overrides,
  ) async {
    final style = buildCustomStyle(overrides);
    await tester.pumpWidget(
      MaterialApp(
        theme: style.theme,
        home: Scaffold(
          body: FilledButton(onPressed: () {}, child: const Text('X')),
        ),
      ),
    );
    // The Material that actually paints the button's shape/border is the
    // one directly wrapping the InkWell — find it by its shape being an
    // OutlinedBorder (the Scaffold/MaterialApp also produce Material
    // ancestors with no shape).
    final materials = tester.widgetList<Material>(find.byType(Material));
    return materials.firstWhere((m) => m.shape is OutlinedBorder);
  }

  testWidgets(
    'a real FilledButton actually receives the themed border shape at '
    'runtime (buttonBorder: solid)',
    (tester) async {
      final material = await pumpFilledButtonMaterial(
        tester,
        const CustomStyleOverrides(buttonBorder: 'solid'),
      );
      final shape = material.shape! as RoundedRectangleBorder;
      expect(shape.side, isNot(BorderSide.none));
      expect(shape.side.style, BorderStyle.solid);
    },
  );

  testWidgets(
    'a real FilledButton actually receives the themed dashed border shape '
    'at runtime (buttonBorder: dotted)',
    (tester) async {
      final material = await pumpFilledButtonMaterial(
        tester,
        const CustomStyleOverrides(buttonBorder: 'dotted'),
      );
      expect(material.shape, isA<OutlinedBorder>());
      expect(
        material.shape.runtimeType.toString(),
        'DashedRoundedRectangleBorder',
      );
    },
  );

  testWidgets('no buttonBorder override -> no border reaches the real widget', (
    tester,
  ) async {
    final material = await pumpFilledButtonMaterial(
      tester,
      const CustomStyleOverrides(),
    );
    final shape = material.shape! as RoundedRectangleBorder;
    expect(shape.side, BorderSide.none);
  });

  // Regression guards for the buttonBorder scoping rule (2026-08-23, user
  // spec): none/solid/dotted styles ONLY the ACTIVE button of a selection
  // group. OutlinedButton is the inactive/aux state in this design language
  // (_SelectableChipButton renders FilledButton when selected, OutlinedButton
  // otherwise), so a real OutlinedButton must stay borderless for EVERY
  // buttonBorder value — mesh_theme.dart's base `side: BorderSide.none` must
  // win over the themed shape's embedded side at render time. An earlier
  // change wired `side: buttonSide` into outlinedButtonTheme as a supposed
  // bug fix, which put borders on every inactive group button; these tests
  // pin the corrected behavior at the real-widget level (theme-only checks
  // can't see the side/shape merge ButtonStyleButton does at render time).
  Future<Material> pumpOutlinedButtonMaterial(
    WidgetTester tester,
    CustomStyleOverrides overrides,
  ) async {
    final style = buildCustomStyle(overrides);
    await tester.pumpWidget(
      MaterialApp(
        theme: style.theme,
        home: Scaffold(
          body: OutlinedButton(onPressed: () {}, child: const Text('X')),
        ),
      ),
    );
    return tester.widget<Material>(
      find.descendant(
        of: find.byType(OutlinedButton),
        matching: find.byType(Material),
      ),
    );
  }

  testWidgets(
    'a real OutlinedButton stays borderless under buttonBorder: solid '
    '(border is for the active button only)',
    (tester) async {
      final material = await pumpOutlinedButtonMaterial(
        tester,
        const CustomStyleOverrides(buttonBorder: 'solid'),
      );
      final shape = material.shape! as OutlinedBorder;
      expect(shape.side.style, BorderStyle.none);
    },
  );

  testWidgets(
    'a real OutlinedButton stays borderless under buttonBorder: dotted '
    '(dashed shape may be inherited but must paint no side)',
    (tester) async {
      final material = await pumpOutlinedButtonMaterial(
        tester,
        const CustomStyleOverrides(buttonBorder: 'dotted'),
      );
      // DashedRoundedRectangleBorder.paint() returns early for
      // BorderStyle.none, so side.style is what decides whether anything
      // is drawn — the shape type itself may legitimately stay dashed.
      final shape = material.shape! as OutlinedBorder;
      expect(shape.side.style, BorderStyle.none);
    },
  );
}
