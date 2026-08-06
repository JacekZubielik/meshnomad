/// Rolling usage of a monotonic cumulative counter (e.g. radio TX airtime
/// seconds) over a sliding time window.
///
/// Samples are (timestamp, cumulative value). Usage in the window is the
/// delta between the newest sample and a baseline: the newest sample at or
/// before the window start (kept during pruning so the delta spans the full
/// window). A counter that goes backwards (device reboot) restarts the
/// baseline at zero, so usage falls back to the latest raw value.
class RollingCounterWindow {
  RollingCounterWindow({this.window = const Duration(hours: 1)});

  final Duration window;
  final List<({DateTime time, int value})> _samples = [];

  void add(DateTime time, int cumulative) {
    if (_samples.isNotEmpty && !time.isAfter(_samples.last.time)) return;
    _samples.add((time: time, value: cumulative));
    _prune(time);
  }

  int usedIn(DateTime now) {
    _prune(now);
    if (_samples.isEmpty) return 0;
    final latest = _samples.last.value;
    final baseline = _samples.first.value;
    return latest >= baseline ? latest - baseline : latest;
  }

  void clear() => _samples.clear();

  void _prune(DateTime now) {
    final cutoff = now.subtract(window);
    while (_samples.length >= 2 && !_samples[1].time.isAfter(cutoff)) {
      _samples.removeAt(0);
    }
  }
}
