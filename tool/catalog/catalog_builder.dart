/// Pure catalog-building logic for the Flasher firmware catalog.
///
/// This is the ONLY layer in the project that understands GitHub release
/// JSON. The app itself never talks to api.github.com — it consumes the
/// generated catalog (see tool/generate_flasher_catalog.dart and the
/// flasher-catalog CI workflow).
library;

const int flashOffsetFullReset = 0x00000;
const int flashOffsetUpdate = 0x10000;
const int maxVersionsPerRomType = 20;

class CatalogRomTypeSpec {
  const CatalogRomTypeSpec({
    required this.id,
    required this.displayName,
    required this.tagPrefix,
  });

  final String id;
  final String displayName;
  final String tagPrefix;
}

class CatalogSourceSpec {
  const CatalogSourceSpec({
    required this.id,
    required this.displayName,
    required this.repo,
    required this.romTypes,
    required this.boardTokenIsSubstring,
  });

  final String id;
  final String displayName;
  final String repo; // "owner/repo"
  final List<CatalogRomTypeSpec> romTypes; // empty == single release stream
  // MeshCore: board token is a filename PREFIX. MeshCore-Solo:
  // solo-v<ver>-<Board>[-merged].bin — token is a mid-string SUBSTRING.
  final bool boardTokenIsSubstring;
}

const List<CatalogSourceSpec> catalogSources = [
  CatalogSourceSpec(
    id: 'meshcore',
    displayName: 'MeshCore',
    // Official org repo. The old ripplebiz/MeshCore address is a redirect
    // and must never be used.
    repo: 'meshcore-dev/MeshCore',
    boardTokenIsSubstring: false,
    romTypes: [
      CatalogRomTypeSpec(
        id: 'companion',
        displayName: 'Companion',
        tagPrefix: 'companion-',
      ),
      CatalogRomTypeSpec(
        id: 'repeater',
        displayName: 'Repeater',
        tagPrefix: 'repeater-',
      ),
      CatalogRomTypeSpec(
        id: 'room_server',
        displayName: 'Room Server',
        tagPrefix: 'room-server-',
      ),
    ],
  ),
  CatalogSourceSpec(
    id: 'meshcore_solo',
    displayName: 'MeshCore-Solo',
    repo: 'MarekZegare4/MeshCore-Solo',
    boardTokenIsSubstring: true,
    romTypes: [],
  ),
];

// Synthetic stream used for single-stream sources so every board uniformly
// carries romTypes; the UI hides the ROM-type chips when there is only one.
const CatalogRomTypeSpec singleStreamRomType = CatalogRomTypeSpec(
  id: 'firmware',
  displayName: 'Firmware',
  tagPrefix: '',
);

String? extractBoardToken(String fileName, {required bool tokenIsSubstring}) {
  if (!fileName.endsWith('.bin')) return null;
  if (tokenIsSubstring) {
    final match = RegExp(
      r'^.+?-v[\d.]+-(.+?)(?:-merged)?\.bin$',
    ).firstMatch(fileName);
    return match?.group(1);
  }
  final match = RegExp(
    r'^(.+?)(?:_companion_radio_(?:ble|usb))?-v\d.*\.bin$',
  ).firstMatch(fileName);
  return match?.group(1);
}

bool fileMatchesBoard(
  String fileName,
  String boardToken, {
  required bool tokenIsSubstring,
}) {
  if (!fileName.endsWith('.bin')) return false;
  // Case-insensitive: release streams spell the same board inconsistently.
  final lowerName = fileName.toLowerCase();
  final lowerToken = boardToken.toLowerCase();
  return tokenIsSubstring
      ? lowerName.contains(lowerToken)
      : lowerName.startsWith(lowerToken);
}

int offsetForFileName(String fileName) =>
    fileName.contains('-merged') || fileName.contains('_merged')
    ? flashOffsetFullReset
    : flashOffsetUpdate;

/// Builds the catalog map from raw GitHub `/releases` JSON (newest-first,
/// as GitHub returns it — this function must NOT re-sort releases).
Map<String, dynamic> buildCatalog({
  required String generatedAt,
  required Map<String, List<Map<String, dynamic>>> releasesByRepo,
}) {
  final sources = <Map<String, dynamic>>[];
  for (final spec in catalogSources) {
    final releases = releasesByRepo[spec.repo] ?? const [];
    final streams = spec.romTypes.isEmpty
        ? const [singleStreamRomType]
        : spec.romTypes;

    // Board discovery: union of tokens found in the NEWEST release of each
    // stream, deduped case-insensitively (first-seen spelling wins).
    final boardByKey = <String, String>{};
    for (final stream in streams) {
      Map<String, dynamic>? newest;
      for (final release in releases) {
        if ((release['tag_name'] as String).startsWith(stream.tagPrefix)) {
          newest = release;
          break;
        }
      }
      if (newest == null) continue;
      for (final asset
          in (newest['assets'] as List).cast<Map<String, dynamic>>()) {
        final token = extractBoardToken(
          asset['name'] as String,
          tokenIsSubstring: spec.boardTokenIsSubstring,
        );
        if (token != null) {
          boardByKey.putIfAbsent(token.toLowerCase(), () => token);
        }
      }
    }
    final boardTokens = boardByKey.values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    final boards = <Map<String, dynamic>>[];
    for (final board in boardTokens) {
      final romTypes = <Map<String, dynamic>>[];
      for (final stream in streams) {
        final versions = <Map<String, dynamic>>[];
        for (final release in releases) {
          if (!(release['tag_name'] as String).startsWith(stream.tagPrefix)) {
            continue;
          }
          final files = <Map<String, dynamic>>[];
          for (final asset
              in (release['assets'] as List).cast<Map<String, dynamic>>()) {
            final name = asset['name'] as String;
            if (!fileMatchesBoard(
              name,
              board,
              tokenIsSubstring: spec.boardTokenIsSubstring,
            )) {
              continue;
            }
            files.add({
              'name': name,
              'url': asset['browser_download_url'] as String,
              'offset': offsetForFileName(name),
            });
          }
          if (files.isEmpty) continue;
          versions.add({'tag': release['tag_name'] as String, 'files': files});
          if (versions.length >= maxVersionsPerRomType) break;
        }
        if (versions.isNotEmpty) {
          romTypes.add({
            'id': stream.id,
            'displayName': stream.displayName,
            'versions': versions,
          });
        }
      }
      if (romTypes.isNotEmpty) {
        boards.add({'name': board, 'romTypes': romTypes});
      }
    }
    sources.add({
      'id': spec.id,
      'displayName': spec.displayName,
      'boards': boards,
    });
  }
  return {'schema': 1, 'generated': generatedAt, 'sources': sources};
}
