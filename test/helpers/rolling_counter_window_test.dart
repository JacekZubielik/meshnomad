import 'package:flutter_test/flutter_test.dart';
import 'package:meshnomad/helpers/rolling_counter_window.dart';

void main() {
  final t0 = DateTime(2026, 8, 6, 12);

  test('empty window reports zero usage', () {
    final w = RollingCounterWindow();
    expect(w.usedIn(t0), 0);
  });

  test('usage is delta between latest and earliest sample in window', () {
    final w = RollingCounterWindow();
    w.add(t0, 1000);
    w.add(t0.add(const Duration(minutes: 10)), 1040);
    w.add(t0.add(const Duration(minutes: 20)), 1142);
    expect(w.usedIn(t0.add(const Duration(minutes: 20))), 142);
  });

  test('samples older than the window are pruned but one baseline is kept', () {
    final w = RollingCounterWindow();
    // Two old samples: only the newer of them should remain as baseline.
    w.add(t0, 500);
    w.add(t0.add(const Duration(minutes: 30)), 800);
    // 90 minutes later both are outside the 1 h window except as baseline.
    final now = t0.add(const Duration(minutes: 90));
    w.add(now, 1000);
    // Baseline = sample at t0+30 (value 800), not the t0 one (500).
    expect(w.usedIn(now), 200);
  });

  test('counter reset (device reboot) falls back to latest value', () {
    final w = RollingCounterWindow();
    w.add(t0, 1800);
    w.add(t0.add(const Duration(minutes: 5)), 12);
    expect(w.usedIn(t0.add(const Duration(minutes: 5))), 12);
  });

  test('duplicate timestamps are collapsed', () {
    final w = RollingCounterWindow();
    w.add(t0, 100);
    w.add(t0, 100);
    w.add(t0.add(const Duration(minutes: 1)), 130);
    expect(w.usedIn(t0.add(const Duration(minutes: 1))), 30);
  });

  test('clear resets usage to zero', () {
    final w = RollingCounterWindow();
    w.add(t0, 100);
    w.add(t0.add(const Duration(minutes: 1)), 200);
    w.clear();
    expect(w.usedIn(t0.add(const Duration(minutes: 1))), 0);
  });
}
