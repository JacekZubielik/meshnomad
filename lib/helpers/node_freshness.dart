import 'package:flutter/material.dart';

import '../theme/mesh_tokens.dart';

/// How recently a node/contact was last heard from. Same thresholds as
/// map_screen.dart's private `_NodeAge`/`_ageOf` (60min/24h) — kept as a
/// separate copy rather than a shared import so the already-tested map
/// marker code stays untouched; this is the Contacts-side equivalent.
enum NodeFreshness { online, recent, stale }

NodeFreshness freshnessOf(DateTime lastSeen) {
  final diff = DateTime.now().difference(lastSeen);
  if (diff.inMinutes <= 60) return NodeFreshness.online;
  if (diff.inHours <= 24) return NodeFreshness.recent;
  return NodeFreshness.stale;
}

extension NodeFreshnessColor on NodeFreshness {
  /// Same token mapping as map_screen.dart's `_ageColor`, so "online" /
  /// "stale" mean the same color on both the map and Contacts.
  Color colorOf(MeshTokens t) {
    switch (this) {
      case NodeFreshness.online:
        return t.mapOnline;
      case NodeFreshness.recent:
        return t.mapStale;
      case NodeFreshness.stale:
        return t.mapTextMuted;
    }
  }
}
