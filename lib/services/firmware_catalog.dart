import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Flash offsets for ESP32 images: a `-merged` image carries
/// bootloader+partition table+app and is written at 0x0 (full reset); a
/// plain app image is written at 0x10000 (settings-preserving update).
const int catalogOffsetFullReset = 0x00000;
const int catalogOffsetUpdate = 0x10000;

/// Where the CI-generated catalog is published (flasher-catalog workflow;
/// CDN-served raw file — no GitHub API, no rate limits).
const String firmwareCatalogUrl =
    'https://raw.githubusercontent.com/JacekZubielik/meshnomad/flasher-catalog/catalog.json';

class CatalogFile {
  CatalogFile({required this.name, required this.url, required this.offset});

  final String name;
  final String url;
  final int offset;

  factory CatalogFile.fromJson(Map<String, dynamic> json) => CatalogFile(
    name: json['name'] as String,
    url: json['url'] as String,
    offset: json['offset'] as int,
  );
}

class CatalogVersion {
  CatalogVersion({required this.tag, required this.files});

  final String tag;
  final List<CatalogFile> files;

  factory CatalogVersion.fromJson(Map<String, dynamic> json) => CatalogVersion(
    tag: json['tag'] as String,
    files: (json['files'] as List<dynamic>)
        .map((f) => CatalogFile.fromJson(f as Map<String, dynamic>))
        .toList(),
  );
}

class CatalogRomType {
  CatalogRomType({
    required this.id,
    required this.displayName,
    required this.versions,
  });

  final String id;
  final String displayName;
  final List<CatalogVersion> versions;

  factory CatalogRomType.fromJson(Map<String, dynamic> json) => CatalogRomType(
    id: json['id'] as String,
    displayName: json['displayName'] as String,
    versions: (json['versions'] as List<dynamic>)
        .map((v) => CatalogVersion.fromJson(v as Map<String, dynamic>))
        .toList(),
  );
}

class CatalogBoard {
  CatalogBoard({required this.name, required this.romTypes});

  final String name;
  final List<CatalogRomType> romTypes;

  factory CatalogBoard.fromJson(Map<String, dynamic> json) => CatalogBoard(
    name: json['name'] as String,
    romTypes: (json['romTypes'] as List<dynamic>)
        .map((r) => CatalogRomType.fromJson(r as Map<String, dynamic>))
        .toList(),
  );
}

class CatalogSource {
  CatalogSource({
    required this.id,
    required this.displayName,
    required this.boards,
  });

  final String id;
  final String displayName;
  final List<CatalogBoard> boards;

  factory CatalogSource.fromJson(Map<String, dynamic> json) => CatalogSource(
    id: json['id'] as String,
    displayName: json['displayName'] as String,
    boards: (json['boards'] as List<dynamic>)
        .map((b) => CatalogBoard.fromJson(b as Map<String, dynamic>))
        .toList(),
  );
}

class FirmwareCatalog {
  FirmwareCatalog({required this.generated, required this.sources});

  final DateTime? generated;
  final List<CatalogSource> sources;

  static FirmwareCatalog parse(String raw) {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    if (json['schema'] != 1) {
      throw const FormatException('Unsupported catalog schema');
    }
    return FirmwareCatalog(
      generated: DateTime.tryParse(json['generated'] as String? ?? ''),
      sources: (json['sources'] as List<dynamic>)
          .map((s) => CatalogSource.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// A single flashable image resolved from the catalog (or a custom URL) —
/// the screen-facing contract carried over from the previous design.
/// [fetch]'s optional [onProgress] reports real bytes-received/content-
/// length (0.0-1.0); it is only invoked when the server sends a
/// Content-Length header — never a fabricated/timer-driven value.
class FirmwareAsset {
  FirmwareAsset({
    required this.label,
    required this.fetch,
    required this.flashOffset,
  });

  final String label;
  final Future<Uint8List> Function({void Function(double progress)? onProgress})
  fetch;
  final int flashOffset;
}

/// Local-first catalog access: [loadCatalog] never touches the network
/// (device file, then bundled asset fallback); [refreshCatalog] is the
/// single network entry point, wired to the screen's Refresh button.
class FirmwareCatalogService {
  FirmwareCatalogService({http.Client? httpClient, Directory? storageDirectory})
    : _httpClient = httpClient ?? http.Client(),
      _storageDirectoryOverride = storageDirectory;

  final http.Client _httpClient;
  final Directory? _storageDirectoryOverride;

  Future<File> _localFile() async {
    final dir =
        _storageDirectoryOverride ?? await getApplicationSupportDirectory();
    return File('${dir.path}/flasher/catalog.json');
  }

  Future<FirmwareCatalog> loadCatalog() async {
    final file = await _localFile();
    if (await file.exists()) {
      try {
        return FirmwareCatalog.parse(await file.readAsString());
      } on FormatException {
        // A corrupted/stale-schema local copy must not brick the screen —
        // fall through to the bundled snapshot and overwrite it below.
      }
    }
    final bundled = await rootBundle.loadString('assets/flasher/catalog.json');
    final catalog = FirmwareCatalog.parse(bundled);
    await file.create(recursive: true);
    await file.writeAsString(bundled);
    return catalog;
  }

  Future<FirmwareCatalog> refreshCatalog() async {
    final response = await _httpClient.get(Uri.parse(firmwareCatalogUrl));
    if (response.statusCode != 200) {
      throw StateError('Catalog download failed: HTTP ${response.statusCode}');
    }
    final catalog = FirmwareCatalog.parse(response.body); // validates schema
    final file = await _localFile();
    await file.create(recursive: true);
    await file.writeAsString(response.body);
    return catalog;
  }

  FirmwareAsset assetFor(CatalogFile file) => FirmwareAsset(
    label: file.name,
    flashOffset: file.offset,
    fetch: ({void Function(double progress)? onProgress}) =>
        _streamedFetch(file.url, label: file.name, onProgress: onProgress),
  );

  FirmwareAsset fromCustomUrl(String url, {required int flashOffset}) =>
      FirmwareAsset(
        label: url,
        flashOffset: flashOffset,
        fetch: ({void Function(double progress)? onProgress}) =>
            _streamedFetch(url, label: url, onProgress: onProgress),
      );

  Future<Uint8List> _streamedFetch(
    String url, {
    required String label,
    void Function(double progress)? onProgress,
  }) async {
    final response = await _httpClient.send(
      http.Request('GET', Uri.parse(url)),
    );
    if (response.statusCode != 200) {
      // Drain the stream before throwing so the underlying connection is
      // released cleanly instead of left dangling.
      await response.stream.drain<void>();
      throw StateError(
        'Firmware download failed for $label: HTTP ${response.statusCode}',
      );
    }
    final total = response.contentLength;
    final received = <int>[];
    await for (final chunk in response.stream) {
      received.addAll(chunk);
      if (total != null && total > 0) {
        // A server that under-reports Content-Length relative to the actual
        // body size would otherwise push this ratio past 1.0.
        onProgress?.call(math.min(1.0, received.length / total));
      }
    }
    return Uint8List.fromList(received);
  }
}
