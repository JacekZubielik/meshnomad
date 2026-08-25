import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

/// One release stream within a [FirmwareGithubSource] that publishes
/// multiple interleaved streams (MeshCore: companion/repeater/room-server,
/// each its own `<tagPrefix>vX.Y.Z` tag series). A source with no role
/// split (MeshCore-Solo) has an empty [FirmwareGithubSource.romTypes] list
/// and skips this selection step entirely.
class FirmwareRomType {
  FirmwareRomType({
    required this.id,
    required this.displayName,
    required this.tagPrefix,
  });

  final String id;
  final String displayName;
  final String tagPrefix;

  factory FirmwareRomType.fromJson(Map<String, dynamic> json) =>
      FirmwareRomType(
        id: json['id'] as String,
        displayName: json['displayName'] as String,
        tagPrefix: json['tagPrefix'] as String,
      );
}

/// One built-in GitHub firmware source (repo). Board/version/asset content
/// is discovered live from the repo's releases — this class only carries
/// static structural metadata (repo location, which release streams exist,
/// and how board tokens are laid out in that repo's asset filenames).
class FirmwareGithubSource {
  FirmwareGithubSource({
    required this.id,
    required this.displayName,
    required this.repo,
    required this.romTypes,
    required this.boardTokenIsSubstring,
  });

  final String id;
  final String displayName;
  final String repo; // "owner/repo"
  final List<FirmwareRomType> romTypes; // empty == single release stream
  // MeshCore: `<Board>[_role]-v<version>-<sha>[-merged].bin` — board token
  // is a filename PREFIX. MeshCore-Solo: `solo-v<version>-<Board>[-merged].bin`
  // — version comes first, board token is a mid-string SUBSTRING. Verified
  // 2026-08-24/25 against both repos' actual release assets.
  final bool boardTokenIsSubstring;

  factory FirmwareGithubSource.fromJson(Map<String, dynamic> json) =>
      FirmwareGithubSource(
        id: json['id'] as String,
        displayName: json['displayName'] as String,
        repo: json['repo'] as String,
        romTypes: (json['romTypes'] as List<dynamic>? ?? const [])
            .map((r) => FirmwareRomType.fromJson(r as Map<String, dynamic>))
            .toList(),
        boardTokenIsSubstring: json['boardTokenIsSubstring'] as bool? ?? false,
      );
}

/// A single flashable firmware image resolved from any source, with the
/// flash offset it must be written at (ESP32 uses exactly two possible
/// offsets — 0x0 for a "-merged" full-reset image, 0x10000 for an app-only
/// update image — but a given release is NOT guaranteed to offer both).
class FirmwareAsset {
  FirmwareAsset({
    required this.label,
    required this.fetch,
    required this.flashOffset,
  });

  final String label;
  final Future<Uint8List> Function() fetch;
  final int flashOffset;
}

/// One GitHub release, with its `.bin` assets already parsed into
/// [FirmwareAsset]s — shown to the user exactly as the repo publishes them,
/// with no attempt to match against a predetermined board catalog.
class FirmwareRelease {
  FirmwareRelease({required this.tagName, required this.assets});

  final String tagName;
  final List<FirmwareAsset> assets;
}

const int flashOffsetFullReset = 0x00000;
const int flashOffsetUpdate = 0x10000;

class FirmwareSource {
  FirmwareSource({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  // The bundled catalog is static app content — it never changes at
  // runtime, so a class-level cache avoids re-reading and re-parsing the
  // same asset every time a new FirmwareSource is constructed (e.g. a
  // fresh FlasherScreen instance). Shared across all instances by design.
  static List<FirmwareGithubSource>? _cachedCatalog;

  Future<List<FirmwareGithubSource>> loadCatalog() async {
    final cached = _cachedCatalog;
    if (cached != null) return cached;
    final raw = await rootBundle.loadString('assets/flasher/boards.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final sources = json['sources'] as List<dynamic>;
    final parsed = sources
        .map((s) => FirmwareGithubSource.fromJson(s as Map<String, dynamic>))
        .toList();
    _cachedCatalog = parsed;
    return parsed;
  }

  // One /releases fetch per source per FirmwareSource instance. Without
  // this, every board/ROM-type switch refired the same request, and
  // unauthenticated api.github.com allows only 60 requests/hour per IP —
  // a normal testing session exhausted the quota and every fetch started
  // failing with 403. The response already contains every release with its
  // full asset list, so nothing is lost by reusing it. A fresh
  // FlasherScreen creates a fresh FirmwareSource, so re-entering the
  // screen naturally re-fetches (that's the refresh path).
  final Map<String, List<Map<String, dynamic>>> _releasesCache = {};

  Future<List<Map<String, dynamic>>> _fetchAllReleases(
    FirmwareGithubSource source,
  ) async {
    final cached = _releasesCache[source.repo];
    if (cached != null) return cached;
    final response = await _httpClient.get(
      Uri.parse(
        'https://api.github.com/repos/${source.repo}/releases?per_page=100',
      ),
    );
    if (response.statusCode == 403) {
      throw StateError(
        'GitHub API rate limit reached for ${source.repo} (403) — '
        'unauthenticated access allows 60 requests/hour; wait a while '
        'and try again',
      );
    }
    if (response.statusCode != 200) {
      throw StateError(
        'GitHub releases request failed for ${source.repo}: ${response.statusCode}',
      );
    }
    final parsed = (jsonDecode(response.body) as List<dynamic>)
        .cast<Map<String, dynamic>>();
    _releasesCache[source.repo] = parsed;
    return parsed;
  }

  /// Discovers the set of board tokens present in [source]'s most recent
  /// release(s) — one release per ROM type for a multi-stream source
  /// (MeshCore's companion/repeater/room-server all scanned and unioned),
  /// or just the single newest release for a single-stream source
  /// (MeshCore-Solo). This reads live repo content instead of a hardcoded
  /// board list — a board choice the user makes BEFORE picking a ROM type
  /// or version, so it must not depend on either.
  Future<List<String>> discoverBoards({
    required FirmwareGithubSource source,
  }) async {
    final all = await _fetchAllReleases(source);
    // The repo's release streams are not consistent about capitalization
    // (e.g. `Heltec_v3` in one stream, `heltec_v3` in another) — dedupe by
    // a case-insensitive key so each physical board appears exactly once,
    // keeping the first-seen spelling as the display/matching token. Asset
    // matching downstream is case-insensitive too, so which spelling wins
    // doesn't affect what the user can flash.
    final byKey = <String, String>{};
    void addAll(Iterable<String> tokens) {
      for (final token in tokens) {
        byKey.putIfAbsent(token.toLowerCase(), () => token);
      }
    }

    if (source.romTypes.isEmpty) {
      if (all.isNotEmpty) {
        addAll(_boardTokensFrom(all.first, source));
      }
    } else {
      for (final romType in source.romTypes) {
        for (final release in all) {
          if ((release['tag_name'] as String).startsWith(romType.tagPrefix)) {
            addAll(_boardTokensFrom(release, source));
            break; // newest match for this ROM type only
          }
        }
      }
    }
    final sorted = byKey.values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return sorted;
  }

  Iterable<String> _boardTokensFrom(
    Map<String, dynamic> release,
    FirmwareGithubSource source,
  ) {
    final assets = (release['assets'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    return assets
        .map((a) => a['name'] as String)
        .where((name) => name.endsWith('.bin'))
        .map((name) => _extractBoardToken(name, source))
        .nonNulls;
  }

  String? _extractBoardToken(String fileName, FirmwareGithubSource source) {
    if (source.boardTokenIsSubstring) {
      // MeshCore-Solo shape: solo-v<version>-<Board>[-merged].bin.
      final match = RegExp(
        r'^.+?-v[\d.]+-(.+?)(?:-merged)?\.bin$',
      ).firstMatch(fileName);
      return match?.group(1);
    }
    // MeshCore shape: <Board>[_companion_radio_ble|usb]-v<version>-<sha>[-merged].bin
    final match = RegExp(
      r'^(.+?)(?:_companion_radio_(?:ble|usb))?-v\d.*\.bin$',
    ).firstMatch(fileName);
    return match?.group(1);
  }

  /// Fetches up to [limit] releases for [source], newest first. When
  /// [romType] is given, filters to only that release stream's tag prefix
  /// (required for multi-stream repos like MeshCore — GitHub's `/releases`
  /// list interleaves companion/repeater/room-server releases together).
  /// When [boardToken] is given, each release's assets are filtered down to
  /// only that board's files. A single `/releases` request already returns
  /// each release's full asset list, so no per-release follow-up request is
  /// needed.
  Future<List<FirmwareRelease>> fetchReleases({
    required FirmwareGithubSource source,
    FirmwareRomType? romType,
    String? boardToken,
    int limit = 20,
  }) async {
    final all = await _fetchAllReleases(source);
    final filtered = romType == null
        ? all
        : all.where(
            (r) => (r['tag_name'] as String).startsWith(romType.tagPrefix),
          );
    return filtered
        .take(limit)
        .map((r) => _parseRelease(r, source, boardToken))
        .toList();
  }

  FirmwareRelease _parseRelease(
    Map<String, dynamic> raw,
    FirmwareGithubSource source,
    String? boardToken,
  ) {
    final tagName = raw['tag_name'] as String;
    final rawAssets = (raw['assets'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final assets = rawAssets
        .where((a) {
          final name = a['name'] as String;
          if (!name.endsWith('.bin')) return false;
          if (boardToken == null) return true;
          // Case-insensitive: the repo's streams spell the same board with
          // inconsistent capitalization (see discoverBoards).
          final lowerName = name.toLowerCase();
          final lowerToken = boardToken.toLowerCase();
          return source.boardTokenIsSubstring
              ? lowerName.contains(lowerToken)
              : lowerName.startsWith(lowerToken);
        })
        .map((a) {
          final name = a['name'] as String;
          final url = a['browser_download_url'] as String;
          final isMerged = name.contains('-merged') || name.contains('_merged');
          return FirmwareAsset(
            label: name,
            flashOffset: isMerged ? flashOffsetFullReset : flashOffsetUpdate,
            fetch: () async {
              final fileResponse = await _httpClient.get(Uri.parse(url));
              return fileResponse.bodyBytes;
            },
          );
        })
        .toList();
    return FirmwareRelease(tagName: tagName, assets: assets);
  }

  FirmwareAsset fromCustomUrl(String url, {required int flashOffset}) {
    return FirmwareAsset(
      label: url,
      flashOffset: flashOffset,
      fetch: () async {
        final response = await _httpClient.get(Uri.parse(url));
        if (response.statusCode != 200) {
          throw StateError(
            'Custom firmware URL failed: ${response.statusCode}',
          );
        }
        return response.bodyBytes;
      },
    );
  }
}
