import 'dart:ui' show PlatformDispatcher;

import 'package:intl/intl.dart';

/// Chat-bubble timestamp shared by the direct and channel chats.
///
/// Formats follow the device's region ([locale], e.g. `pl_PL` → `4.09 12:57`,
/// `en_GB` → `04/09 12:57`, `en_US` → `9/4 12:57 PM`), not the app's UI
/// language — the app only ships en/pl, so `Localizations.localeOf` gave a
/// Polish phone with English UI the US date order (2026-09-05).
/// The date prefix appears for messages from a different calendar day than
/// [now]. Requires `initializeDateFormatting()` to have run for locales
/// outside the app's own (see `main()`).
String formatMessageTimestamp(
  DateTime time, {
  required String locale,
  DateTime? now,
}) {
  final formats = _formatsFor(locale);
  final reference = now ?? DateTime.now();
  // CLDR puts a narrow no-break space (U+202F) before AM/PM; the caption
  // is mono, where that glyph is a gamble — a plain space reads the same.
  final clock = formats.time
      .format(time)
      .replaceAll(' ', ' ')
      .replaceAll(' ', ' ');
  final sameDay =
      time.year == reference.year &&
      time.month == reference.month &&
      time.day == reference.day;
  return sameDay ? clock : '${formats.date.format(time)} $clock';
}

/// The device's first preferred locale as an intl tag (`pl_PL`), independent
/// of the app's language override.
String deviceLocaleTag() {
  final locale = PlatformDispatcher.instance.locales.firstOrNull;
  return locale?.toString() ?? 'en_US';
}

const _fallbackLocale = 'en_US';

final Map<String, ({DateFormat date, DateFormat time})> _cache = {};

({DateFormat date, DateFormat time}) _formatsFor(String locale) {
  return _cache.putIfAbsent(locale, () {
    final verified =
        Intl.verifiedLocale(
          locale,
          DateFormat.localeExists,
          onFailure: (_) => _fallbackLocale,
        ) ??
        _fallbackLocale;
    return (date: DateFormat.Md(verified), time: DateFormat.jm(verified));
  });
}
