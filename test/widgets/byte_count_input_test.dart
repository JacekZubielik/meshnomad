import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:meshcore_open/widgets/byte_count_input.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  testWidgets('hidden byte counter reserves no space below the field', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _wrap(ByteCountedTextField(maxBytes: 160, controller: controller)),
    );
    await tester.pump();

    // Empty field: no counter row at all, so the widget is exactly as tall
    // as the text field and centers cleanly next to the send/GIF icons.
    expect(find.text('0 / 160'), findsNothing);
    final fieldHeight = tester.getSize(find.byType(TextField)).height;
    final widgetHeight = tester
        .getSize(find.byType(ByteCountedTextField))
        .height;
    expect(widgetHeight, fieldHeight);
  });

  testWidgets('counter appears once the user types', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _wrap(ByteCountedTextField(maxBytes: 160, controller: controller)),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'abc');
    await tester.pump();

    expect(find.text('3 / 160'), findsOneWidget);
  });
}
