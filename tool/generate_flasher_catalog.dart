/// Generates the Flasher firmware catalog by querying GitHub's API.
///
/// This script is the ONLY component allowed to call api.github.com. It
/// runs in CI (flasher-catalog workflow, authenticated GITHUB_TOKEN) and,
/// rarely, locally (GITHUB_TOKEN=$(gh auth token)) to refresh the bundled
/// snapshot in assets/flasher/catalog.json. The app itself only ever
/// consumes the generated file.
///
/// Usage: dart run tool/generate_flasher_catalog.dart [output-path]
library;

import 'dart:convert';
import 'dart:io';

import 'catalog/catalog_builder.dart';

Future<void> main(List<String> args) async {
  final outputPath = args.isNotEmpty
      ? args.first
      : 'assets/flasher/catalog.json';
  final token = Platform.environment['GITHUB_TOKEN'];
  final client = HttpClient();

  Future<List<Map<String, dynamic>>> fetchReleases(String repo) async {
    final request = await client.getUrl(
      Uri.parse('https://api.github.com/repos/$repo/releases?per_page=100'),
    );
    request.headers.set('User-Agent', 'meshnomad-flasher-catalog');
    request.headers.set('Accept', 'application/vnd.github+json');
    if (token != null && token.isNotEmpty) {
      request.headers.set('Authorization', 'Bearer $token');
    }
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode != 200) {
      stderr.writeln(
        'GET $repo releases -> HTTP ${response.statusCode}: '
        '${body.substring(0, body.length > 300 ? 300 : body.length)}',
      );
      exit(1);
    }
    return (jsonDecode(body) as List).cast<Map<String, dynamic>>();
  }

  final releasesByRepo = <String, List<Map<String, dynamic>>>{};
  for (final source in catalogSources) {
    releasesByRepo[source.repo] = await fetchReleases(source.repo);
  }
  client.close();

  final catalog = buildCatalog(
    generatedAt: DateTime.now().toUtc().toIso8601String(),
    releasesByRepo: releasesByRepo,
  );
  File(outputPath)
    ..createSync(recursive: true)
    ..writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(catalog)}\n',
    );
  final boardCount = (catalog['sources'] as List)
      .map((s) => ((s as Map)['boards'] as List).length)
      .join('+');
  stdout.writeln('Wrote $outputPath (boards per source: $boardCount)');
}
