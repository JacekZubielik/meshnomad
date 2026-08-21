import 'package:characters/characters.dart';

/// [name] with every emoji cluster removed (and edges trimmed) — used by
/// AvatarCircle's per-name hue hash so adding an emoji to a name never
/// shifts the avatar's tint (2026-08-21 fix).
String stripEmoji(String name) {
  final buffer = StringBuffer();
  for (final cluster in name.characters) {
    if (!_containsEmoji(cluster)) buffer.write(cluster);
  }
  return buffer.toString().trim();
}

String? firstEmoji(String name) {
  if (name.isEmpty) return null;
  for (final cluster in name.characters) {
    if (_containsEmoji(cluster)) {
      return cluster;
    }
  }
  return null;
}

bool _containsEmoji(String cluster) {
  for (final rune in cluster.runes) {
    if (_isEmojiRune(rune)) return true;
  }
  return false;
}

bool _isEmojiRune(int rune) {
  if (rune == 0x00A9 || rune == 0x00AE) return true;
  if (rune == 0x203C || rune == 0x2049) return true;
  if (rune == 0x2122 || rune == 0x2139) return true;
  if (rune >= 0x2194 && rune <= 0x21AA) return true;
  if (rune >= 0x2300 && rune <= 0x23FF) return true;
  if (rune >= 0x2460 && rune <= 0x24FF) return true;
  if (rune >= 0x25A0 && rune <= 0x27BF) return true;
  if (rune >= 0x2900 && rune <= 0x297F) return true;
  if (rune >= 0x2B00 && rune <= 0x2BFF) return true;
  if (rune >= 0x1F000 && rune <= 0x1FAFF) return true;
  if (rune >= 0x1FC00 && rune <= 0x1FFFD) return true;
  return false;
}
