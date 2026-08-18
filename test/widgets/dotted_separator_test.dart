import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meshnomad/widgets/dotted_separator.dart';

void main() {
  testWidgets('DottedSeparator paints with the caller-provided color', (
    tester,
  ) async {
    const color = Color(0xFFF0F9FF);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: DottedSeparator(color: color)),
      ),
    );

    final paint = tester.widget<CustomPaint>(
      find.descendant(
        of: find.byType(DottedSeparator),
        matching: find.byType(CustomPaint),
      ),
    );
    expect((paint.painter as dynamic).color, color);
  });

  testWidgets('DottedSeparator stretches to the parent width at 1px height', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 200,
            child: DottedSeparator(color: Colors.white),
          ),
        ),
      ),
    );

    final size = tester.getSize(find.byType(DottedSeparator));
    expect(size.width, 200);
    expect(size.height, 1);
  });
}
