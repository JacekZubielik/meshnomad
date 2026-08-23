import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:meshnomad/services/chat_text_scale_service.dart';
import 'package:meshnomad/widgets/chat_zoom_wrapper.dart';

void main() {
  testWidgets('a single-finger vertical drag scrolls the wrapped list '
      '(ChatZoomWrapper must not swallow 1-pointer drags meant for scroll)', (
    tester,
  ) async {
    final scrollController = ScrollController();

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ChatTextScaleService(),
        child: MaterialApp(
          // Real chat_screen.dart/channel_chat_screen.dart wrap the whole
          // screen body in SelectionArea (see build()'s "07-selection-bugs.md"
          // comment) — reproduce that exact nesting, not just the wrapper
          // in isolation, since SelectionArea has its own drag recognizers.
          home: SelectionArea(
            child: Scaffold(
              body: SizedBox(
                height: 400,
                child: ChatZoomWrapper(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: 50,
                    itemBuilder: (context, index) =>
                        SizedBox(height: 60, child: Text('Item $index')),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(scrollController.offset, 0.0);

    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();

    expect(
      scrollController.offset,
      greaterThan(0.0),
      reason:
          'ChatZoomWrapper\'s GestureDetector (onScaleStart/onScaleUpdate) '
          'must not win the gesture arena over the ListView\'s own '
          'VerticalDragGestureRecognizer for single-finger drags.',
    );
  });
}
