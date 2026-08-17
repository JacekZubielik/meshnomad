import 'package:flutter/foundation.dart';

import '../models/packet_observation.dart';

/// Keeps a bounded, in-memory log of observed radio packets.
///
/// Nothing is persisted: the log starts empty on every launch and is capped at
/// [maxObservations]. Once the cap is hit the oldest entries are dropped and
/// [trimmedCount] starts counting, so consumers can tell the user that
/// session-wide figures no longer cover the whole session.
class PacketObservationService extends ChangeNotifier {
  PacketObservationService({DateTime? startedAt, this.maxObservations = 20000})
    : sessionStartedAt = startedAt ?? DateTime.now();

  /// Upper bound on retained observations.
  final int maxObservations;

  /// When this session began; the lower bound of the 'session' window.
  final DateTime sessionStartedAt;

  final List<PacketObservation> _observations = <PacketObservation>[];

  int _totalObserved = 0;
  int _trimmedCount = 0;

  /// Retained observations, oldest first.
  List<PacketObservation> get observations =>
      List<PacketObservation>.unmodifiable(_observations);

  /// Every packet seen this session, including ones since dropped.
  int get totalObserved => _totalObserved;

  /// How many observations were dropped because the cap was reached.
  int get trimmedCount => _trimmedCount;

  /// Whether the retained log still covers the whole session.
  bool get coversWholeSession => _trimmedCount == 0;

  void record(PacketObservation observation) {
    _observations.add(observation);
    _totalObserved++;
    if (_observations.length > maxObservations) {
      final excess = _observations.length - maxObservations;
      _observations.removeRange(0, excess);
      _trimmedCount += excess;
    }
    notifyListeners();
  }

  /// Observations at or after [start], oldest first.
  List<PacketObservation> since(DateTime start) {
    return _observations
        .where((o) => !o.observedAt.isBefore(start))
        .toList(growable: false);
  }

  void clear() {
    _observations.clear();
    _totalObserved = 0;
    _trimmedCount = 0;
    notifyListeners();
  }
}
