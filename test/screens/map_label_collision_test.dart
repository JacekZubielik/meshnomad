import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:meshnomad/screens/map_screen.dart';

/// 40x20 rect — a plausible label bubble size — anchored so its default
/// (offset-0) position sits at the given screen point.
Rect _rectAt(Offset point) => Rect.fromLTWH(
  point.dx - 20 + labelCollisionOffsets[0].dx,
  point.dy + labelCollisionOffsets[0].dy,
  40,
  20,
);

void main() {
  test('no collision: both candidates keep the default (index 0) offset', () {
    final placements = resolveLabelCollisions([
      LabelCandidate(
        nodeId: 'a',
        priority: 0,
        screenRect: _rectAt(const Offset(0, 0)),
      ),
      LabelCandidate(
        nodeId: 'b',
        priority: 0,
        screenRect: _rectAt(const Offset(500, 500)),
      ),
    ]);

    expect(placements, hasLength(2));
    expect(placements.every((p) => p.offsetIndex == 0), isTrue);
  });

  test('two equal-priority candidates colliding at the default offset: the '
      'alphabetically-first keeps offset 0, the other moves to a free offset '
      '(not hidden)', () {
    // Same point -> identical default rects -> guaranteed collision.
    final point = const Offset(100, 100);
    final placements = resolveLabelCollisions([
      LabelCandidate(nodeId: 'b', priority: 0, screenRect: _rectAt(point)),
      LabelCandidate(nodeId: 'a', priority: 0, screenRect: _rectAt(point)),
    ]);

    final a = placements.firstWhere((p) => p.nodeId == 'a');
    final b = placements.firstWhere((p) => p.nodeId == 'b');
    expect(a.offsetIndex, 0);
    expect(b.offsetIndex, isNot(0));
    expect(b.offsetIndex, isNot(-1));
  });

  test(
    'three candidates at the same point with different priorities: the '
    'highest priority keeps offset 0, the others get distinct free offsets',
    () {
      final point = const Offset(200, 200);
      final placements = resolveLabelCollisions([
        LabelCandidate(nodeId: 'low', priority: 0, screenRect: _rectAt(point)),
        LabelCandidate(
          nodeId: 'high',
          priority: 10,
          screenRect: _rectAt(point),
        ),
        LabelCandidate(nodeId: 'mid', priority: 5, screenRect: _rectAt(point)),
      ]);

      final high = placements.firstWhere((p) => p.nodeId == 'high');
      final mid = placements.firstWhere((p) => p.nodeId == 'mid');
      final low = placements.firstWhere((p) => p.nodeId == 'low');
      expect(high.offsetIndex, 0);
      expect(mid.offsetIndex, isNot(0));
      expect(low.offsetIndex, isNot(0));
      expect(mid.offsetIndex, isNot(low.offsetIndex));
      expect(mid.offsetIndex, isNot(-1));
      expect(low.offsetIndex, isNot(-1));
    },
  );

  test('a candidate surrounded on all six offsets by higher-priority labels '
      'is hidden (offsetIndex -1)', () {
    final point = const Offset(300, 300);
    // One blocker rect per candidate offset, all higher priority so they
    // get placed first and occupy every one of the six positions.
    final blockers = [
      for (var i = 0; i < labelCollisionOffsets.length; i++)
        LabelCandidate(
          nodeId: 'blocker$i',
          priority: 10,
          screenRect: _rectAt(point),
          preferredOffsetIndex: i,
        ),
    ];
    final surrounded = LabelCandidate(
      nodeId: 'boxed-in',
      priority: 0,
      screenRect: _rectAt(point),
    );

    final placements = resolveLabelCollisions([...blockers, surrounded]);

    final boxedIn = placements.firstWhere((p) => p.nodeId == 'boxed-in');
    expect(boxedIn.offsetIndex, -1);
  });

  test('stability: a preferred offset that is still collision-free is kept '
      'instead of re-deciding from the candidate list', () {
    final point = const Offset(400, 400);
    // 'moved' previously landed on offset 2; nothing else occupies offset
    // 2's rect, so the solver must keep it there rather than resetting it
    // to offset 0 just because offset 0 happens to also be free now.
    final placements = resolveLabelCollisions([
      LabelCandidate(
        nodeId: 'moved',
        priority: 0,
        screenRect: _rectAt(point),
        preferredOffsetIndex: 2,
      ),
    ]);

    expect(placements.single.offsetIndex, 2);
  });
}
