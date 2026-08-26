import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meshnomad/l10n/app_localizations.dart';
import 'package:meshnomad/theme/mesh_theme.dart';
import 'package:meshnomad/theme/mesh_tokens.dart';
import 'package:meshnomad/widgets/flasher_version_row.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: MeshTheme.light().copyWith(
    extensions: const [MeshTokens.defaultTokens],
  ),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  testWidgets('idle state: both icons tappable, no progress panel', (
    tester,
  ) async {
    var resetTapped = false;
    var updateTapped = false;
    await tester.pumpWidget(
      _wrap(
        FlasherVersionRow(
          tag: 'v1.7.2',
          subLabel: 'companion_radio_ble-Heltec_V4',
          resetState: const FlasherActionState(),
          updateState: const FlasherActionState(),
          onTapReset: () => resetTapped = true,
          onTapUpdate: () => updateTapped = true,
        ),
      ),
    );

    expect(find.text('v1.7.2'), findsOneWidget);
    expect(find.byIcon(Icons.restart_alt), findsOneWidget);
    expect(find.byIcon(Icons.download), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);

    await tester.tap(find.byIcon(Icons.restart_alt));
    expect(resetTapped, isTrue);
    await tester.tap(find.byIcon(Icons.download));
    expect(updateTapped, isTrue);
  });

  testWidgets('downloading state shows the segmented track and percentage', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        FlasherVersionRow(
          tag: 'v1.7.1',
          subLabel: 'sub',
          resetState: const FlasherActionState(),
          updateState: const FlasherActionState(
            phase: FlasherRowPhase.downloading,
            progress: 0.4,
          ),
          onTapReset: () {},
          onTapUpdate: () {},
        ),
      ),
    );

    expect(find.text('40%'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget); // busy icon
  });

  testWidgets('flashing state shows the pill track and percentage', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        FlasherVersionRow(
          tag: 'v1.7.0',
          subLabel: 'sub',
          resetState: const FlasherActionState(),
          updateState: const FlasherActionState(
            phase: FlasherRowPhase.flashing,
            progress: 0.75,
          ),
          onTapReset: () {},
          onTapUpdate: () {},
        ),
      ),
    );

    expect(find.text('75%'), findsOneWidget);
  });

  testWidgets('completion message replaces the progress row', (tester) async {
    await tester.pumpWidget(
      _wrap(
        FlasherVersionRow(
          tag: 'v1.6.4',
          subLabel: 'sub',
          resetState: const FlasherActionState(),
          updateState: const FlasherActionState(
            completionMessage: 'Flashed — Update',
          ),
          onTapReset: () {},
          onTapUpdate: () {},
        ),
      ),
    );

    expect(find.text('Flashed — Update'), findsOneWidget);
    expect(find.text('%'), findsNothing);
  });

  testWidgets('ready state renders the update icon in accent color, tappable', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      _wrap(
        FlasherVersionRow(
          tag: 'v1.7.2',
          subLabel: 'sub',
          resetState: const FlasherActionState(),
          updateState: const FlasherActionState(phase: FlasherRowPhase.ready),
          onTapReset: () {},
          onTapUpdate: () => tapped = true,
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.download));
    expect(tapped, isTrue);
  });

  testWidgets('action icons carry the full-reset/update tooltips', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        FlasherVersionRow(
          tag: 'v1.7.2',
          subLabel: 'sub',
          resetState: const FlasherActionState(),
          updateState: const FlasherActionState(),
          onTapReset: () {},
          onTapUpdate: () {},
        ),
      ),
    );

    expect(find.byTooltip('Full reset'), findsOneWidget);
    expect(find.byTooltip('Update'), findsOneWidget);
  });

  testWidgets('when both states are busy, update panel takes precedence', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        FlasherVersionRow(
          tag: 'v1.6.9',
          subLabel: 'sub',
          resetState: const FlasherActionState(
            phase: FlasherRowPhase.downloading,
            progress: 0.3,
          ),
          updateState: const FlasherActionState(
            phase: FlasherRowPhase.flashing,
            progress: 0.6,
          ),
          onTapReset: () {},
          onTapUpdate: () {},
        ),
      ),
    );

    expect(find.text('60%'), findsOneWidget);
    expect(find.text('30%'), findsNothing);
  });
}
