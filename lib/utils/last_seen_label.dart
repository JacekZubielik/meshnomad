import 'package:flutter/widgets.dart';

import '../l10n/l10n.dart';

/// Relative "last seen / last message" label shared by the contact card's
/// TIME badge and the channel card's TIME badge (2026-08-29: the channel
/// pill must format time EXACTLY like the contact card — same thresholds,
/// same l10n strings, no exceptions; replaces the channel screen's old
/// private "now/Xm/Xh/Xd" formatter).
String formatLastSeenLabel(BuildContext context, DateTime lastSeen) {
  final now = DateTime.now();
  final diff = now.difference(lastSeen);

  if (diff.isNegative || diff.inMinutes < 5) {
    return context.l10n.contacts_lastSeenNow;
  }
  if (diff.inMinutes < 60) {
    return context.l10n.contacts_lastSeenMinsAgo(diff.inMinutes);
  }
  if (diff.inHours < 24) {
    final hours = diff.inHours;
    return hours == 1
        ? context.l10n.contacts_lastSeenHourAgo
        : context.l10n.contacts_lastSeenHoursAgo(hours);
  }
  final days = diff.inDays;
  return days == 1
      ? context.l10n.contacts_lastSeenDayAgo
      : context.l10n.contacts_lastSeenDaysAgo(days);
}
