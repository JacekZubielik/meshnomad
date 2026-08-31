import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:meshnomad/connector/meshcore_connector.dart';
import 'package:meshnomad/l10n/app_localizations.dart';
import 'package:meshnomad/theme/mesh_theme.dart';
import 'package:meshnomad/theme/mesh_tokens.dart';
import 'package:meshnomad/widgets/winda_overlay.dart';

class _FakeConnector extends MeshCoreConnector {
  @override
  bool isLoadingContacts = false;
  @override
  double? contactSyncProgress;
  @override
  bool isSyncingChannels = false;
  @override
  int channelSyncProgress = 0;
  @override
  bool get isShowingQueuedMessageSyncProgress => _queued;
  bool _queued = false;
  set isShowingQueuedMessageSyncProgress(bool v) => _queued = v;
}

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: MeshTheme.light().copyWith(
      extensions: const [MeshTokens.defaultTokens],
    ),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('null child renders nothing visible', (tester) async {
    await tester.pumpWidget(_wrap(const WindaOverlay(child: null)));
    await tester.pumpAndSettle();
    expect(find.byType(WindaOverlay), findsOneWidget);
    expect(find.text('anything'), findsNothing);
  });

  testWidgets('a non-null child renders and can be swapped for arbitrary '
      'content — the shell has no opinion about what it hosts', (tester) async {
    await tester.pumpWidget(_wrap(const WindaOverlay(child: Text('hello'))));
    await tester.pumpAndSettle();
    expect(find.text('hello'), findsOneWidget);

    await tester.pumpWidget(
      _wrap(const WindaOverlay(child: Icon(Icons.check))),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('WindaProgress determinate shows the rounded percentage', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(const WindaProgress(label: 'Syncing contacts', value: 0.474)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Syncing contacts'), findsOneWidget);
    expect(find.text('47%'), findsOneWidget);
  });

  testWidgets('WindaProgress indeterminate (value: null) shows no percentage '
      'text', (tester) async {
    // The indeterminate pill has a perpetually-repeating AnimationController
    // (a real sliding-thumb loop, per the brief's contract), so it never
    // "settles" — pumpAndSettle() would throw "pumpAndSettle timed out"
    // against it. Pump a couple of fixed durations instead.
    await tester.pumpWidget(
      _wrap(const WindaProgress(label: 'Sending queued messages', value: null)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Sending queued messages'), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);
  });

  testWidgets(
    'fromConnector prioritizes contacts > channels > queued, matches the '
    'old _SyncProgressState priority order',
    (tester) async {
      final connector = _FakeConnector()
        ..isLoadingContacts = true
        ..contactSyncProgress = 0.5
        ..isSyncingChannels = true
        ..channelSyncProgress = 80;

      late AppLocalizations l10n;
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) {
              l10n = AppLocalizations.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final progress = WindaProgress.fromConnector(connector, l10n);
      expect(progress, isNotNull);
      expect(progress!.label, l10n.common_syncingContacts);
    },
  );

  testWidgets('fromConnector returns null when nothing is syncing', (
    tester,
  ) async {
    late AppLocalizations l10n;
    await tester.pumpWidget(
      _wrap(
        Builder(
          builder: (context) {
            l10n = AppLocalizations.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(WindaProgress.fromConnector(_FakeConnector(), l10n), isNull);
  });
}
