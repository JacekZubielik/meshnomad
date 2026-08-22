import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Minimal reproduction of channel_chat_screen.dart's per-bubble gesture
/// structure: a Listener (onPointerDown/Move/Up/Cancel) wrapping each list
/// item, nested inside a scrollable ListView — matching _SwipeReplyBubble's
/// shape without needing the private class itself.
class _SwipeLikeItem extends StatefulWidget {
  const _SwipeLikeItem({required this.child});
  final Widget child;

  @override
  State<_SwipeLikeItem> createState() => _SwipeLikeItemState();
}

class _SwipeLikeItemState extends State<_SwipeLikeItem> {
  Offset? _start;
  double _offset = 0;
  bool _locked = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (e) {
        _start = e.position;
        _locked = false;
      },
      onPointerMove: (e) {
        if (_start == null) return;
        final dx = -(e.position.dx - _start!.dx);
        const axisLockThreshold = 12.0;
        if (!_locked) {
          if (dx < axisLockThreshold) return;
          _locked = true;
        }
        if (dx <= 0) return;
        setState(() => _offset = dx.clamp(0.0, 64.0));
      },
      onPointerUp: (_) {
        _start = null;
        setState(() => _offset = 0);
      },
      onPointerCancel: (_) {
        _start = null;
        setState(() => _offset = 0);
      },
      child: Transform.translate(
        offset: Offset(-_offset, 0),
        child: widget.child,
      ),
    );
  }
}

void main() {
  testWidgets(
    'a vertical drag scrolls a ListView whose items are each wrapped in a '
    'Listener-based swipe-to-reply widget (channel_chat_screen.dart shape)',
    (tester) async {
      final scrollController = ScrollController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 400,
              child: ListView.builder(
                controller: scrollController,
                itemCount: 50,
                itemBuilder: (context, index) => _SwipeLikeItem(
                  child: SizedBox(height: 60, child: Text('Item $index')),
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
            'Per-item Listener-based swipe handling must not prevent the '
            'ListView from recognizing and completing a vertical scroll.',
      );
    },
  );
}
