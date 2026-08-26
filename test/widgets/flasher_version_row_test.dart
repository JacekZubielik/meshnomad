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

    // Ready = armed to flash, so the icon swaps to the flash glyph rather
    // than staying on the download arrow (which would misleadingly read
    // as "tap to download" when tapping it now writes firmware).
    await tester.tap(find.byIcon(Icons.bolt));
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

  testWidgets('no variant chips render when variantLabels is empty', (
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

    // The variant-toggle Wrap only builds when variantLabels.length > 1;
    // with the default empty list, no chip row exists at all.
    expect(find.byType(Wrap), findsNothing);
  });

  testWidgets('variant chips render both labels and report the tapped index', (
    tester,
  ) async {
    var tappedIndex = -1;
    await tester.pumpWidget(
      _wrap(
        FlasherVersionRow(
          tag: 'v1.7.2',
          subLabel: 'sub',
          resetState: const FlasherActionState(),
          updateState: const FlasherActionState(),
          onTapReset: () {},
          onTapUpdate: () {},
          variantLabels: const ['BLE', 'USB'],
          selectedVariantIndex: 0,
          onSelectVariant: (index) => tappedIndex = index,
        ),
      ),
    );

    expect(find.text('BLE'), findsOneWidget);
    expect(find.text('USB'), findsOneWidget);
    // Compact custom toggle, not SelectableChipButton — that button-family
    // chip's real height blew up this row (device-test feedback,
    // 2026-08-26); each toggle is an InkWell-wrapped label. The action
    // icons also use InkWell internally (IconButton), so scope the finder
    // to InkWell ancestors of the two chip labels specifically.
    expect(
      find.ancestor(of: find.text('BLE'), matching: find.byType(InkWell)),
      findsOneWidget,
    );
    expect(
      find.ancestor(of: find.text('USB'), matching: find.byType(InkWell)),
      findsOneWidget,
    );

    await tester.tap(find.text('USB'));
    expect(tappedIndex, 1);
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
