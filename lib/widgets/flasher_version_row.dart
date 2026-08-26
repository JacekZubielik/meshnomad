import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/mesh_tokens.dart';

/// Lifecycle of one action icon (Full Reset or Update) within a single
/// [FlasherVersionRow]. The two icons in a row are fully independent — one
/// can be `ready` while the other is still `idle`.
enum FlasherRowPhase { idle, downloading, ready, flashing }

/// Immutable snapshot handed to [FlasherVersionRow] by the owning screen.
/// [progress] is only meaningful while `phase` is `downloading`/`flashing`.
/// [completionMessage], when non-null, replaces the progress row with a
/// checkmark line for a few seconds after a download or flash finishes —
/// the caller (FlasherScreen) is responsible for clearing it after a delay.
class FlasherActionState {
  const FlasherActionState({
    this.phase = FlasherRowPhase.idle,
    this.progress = 0,
    this.completionMessage,
  });

  final FlasherRowPhase phase;
  final double progress;
  final String? completionMessage;

  bool get isBusy =>
      phase == FlasherRowPhase.downloading || phase == FlasherRowPhase.flashing;
}

/// One version's row in the Flasher's VERSION list: tag + filename, and two
/// independent action icons (Full Reset / Update). Purely presentational —
/// all state lives in the owning screen; this widget only renders it and
/// reports taps.
class FlasherVersionRow extends StatelessWidget {
  const FlasherVersionRow({
    super.key,
    required this.tag,
    required this.subLabel,
    required this.resetState,
    required this.updateState,
    required this.onTapReset,
    required this.onTapUpdate,
    this.variantLabels = const [],
    this.selectedVariantIndex = 0,
    this.onSelectVariant,
  });

  final String tag;
  final String subLabel;
  final FlasherActionState resetState;
  final FlasherActionState updateState;
  final VoidCallback? onTapReset;
  final VoidCallback? onTapUpdate;

  /// Variant chip labels (e.g. `['BLE', 'USB']`) for boards that publish
  /// separate firmware images at the same flash offset. Empty — the common
  /// case — means the row has no variant choice and renders no chips.
  final List<String> variantLabels;
  final int selectedVariantIndex;
  final ValueChanged<int>? onSelectVariant;

  FlasherActionState? get _activeState {
    if (updateState.isBusy || updateState.completionMessage != null) {
      return updateState;
    }
    if (resetState.isBusy || resetState.completionMessage != null) {
      return resetState;
    }
    return null;
  }

  Widget _actionIcon(
    BuildContext context, {
    required IconData icon,
    required FlasherActionState state,
    required VoidCallback? onTap,
    required String tooltip,
    required String readyTooltip,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final ready = state.phase == FlasherRowPhase.ready;
    final tappable = onTap != null && !state.isBusy;
    // Once the file is downloaded (ready == armed to flash), the icon
    // itself changes to a flash-specific glyph — leaving it as the
    // download arrow read as "tap to download" even though tapping it now
    // writes firmware to the device, which is misleading and confusing on
    // a control this consequential (device-test feedback, 2026-08-26).
    final displayIcon = ready ? Icons.bolt : icon;
    return SizedBox(
      width: 32,
      height: 32,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          shape: const CircleBorder(),
          color: ready
              ? scheme.primary.withValues(alpha: 0.2)
              : scheme.onSurfaceVariant.withValues(alpha: 0.08),
        ),
        child: state.isBusy
            ? Padding(
                padding: const EdgeInsets.all(8),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: scheme.onSurfaceVariant,
                ),
              )
            : IconButton(
                padding: EdgeInsets.zero,
                iconSize: 15,
                color: ready ? scheme.primary : scheme.onSurfaceVariant,
                icon: Icon(displayIcon),
                tooltip: ready ? readyTooltip : tooltip,
                onPressed: tappable ? onTap : null,
              ),
      ),
    );
  }

  /// Compact BLE/USB toggle for rows that publish more than one firmware
  /// variant at the same offset. Deliberately NOT [SelectableChipButton] —
  /// that button-family chip's real padding/text height (~46px tall) blew
  /// up this already-dense row's height when reused here (device-test
  /// feedback, 2026-08-26); this is sized to sit inline with the tag/sub
  /// text instead, roughly matching a compact label rather than a full
  /// button. Same tint/accent language as the rest of this row's controls
  /// (primary @ 20% fill, primary border/text when selected).
  Widget _variantToggle(
    BuildContext context, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: selected
              ? scheme.primary.withValues(alpha: 0.2)
              : Colors.transparent,
          border: Border.all(
            color: selected
                ? scheme.primary
                : scheme.onSurfaceVariant.withValues(alpha: 0.4),
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _pillTrack(BuildContext context, double progress) {
    final t = MeshTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 8,
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.2),
        border: Border.all(color: scheme.primary),
        borderRadius: BorderRadius.circular(t.pill),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: progress.clamp(0, 1),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.primary,
            borderRadius: BorderRadius.circular(t.pill),
          ),
        ),
      ),
    );
  }

  Widget _segmentedTrack(BuildContext context, double progress) {
    final scheme = Theme.of(context).colorScheme;
    // 24 small dots, not 10 wide bars — with few real progress ticks (small
    // firmware files often download in 1-3 HTTP chunks), a handful of fat
    // segments jumped from empty to full almost at once and read as "no
    // progress effect" (device-test feedback, 2026-08-26). More, smaller
    // dots make the same jump look like a gradual fill instead.
    const dotCount = 24;
    const dotHeight = 5.0;
    final filled = (progress.clamp(0, 1) * dotCount).round();
    return Row(
      children: List.generate(dotCount, (i) {
        final on = i < filled;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i == dotCount - 1 ? 0 : 2),
            height: dotHeight,
            decoration: BoxDecoration(
              color: on
                  ? scheme.primary.withValues(alpha: 0.2)
                  : scheme.onSurfaceVariant.withValues(alpha: 0.08),
              border: Border.all(
                color: on
                    ? scheme.primary
                    : scheme.onSurfaceVariant.withValues(alpha: 0.3),
              ),
              borderRadius: BorderRadius.circular(dotHeight / 2),
            ),
          ),
        );
      }),
    );
  }

  Widget? _progressPanel(BuildContext context) {
    final active = _activeState;
    if (active == null) return null;
    final t = MeshTokens.of(context);

    if (active.completionMessage != null) {
      return Padding(
        padding: EdgeInsets.only(top: t.spacingXs),
        child: Row(
          children: [
            Icon(Icons.check_circle, size: 14, color: t.signal),
            SizedBox(width: t.spacingXxs),
            Text(
              active.completionMessage!,
              style: TextStyle(
                fontSize: 12,
                color: t.signal,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    final isFlash = active.phase == FlasherRowPhase.flashing;
    return Padding(
      padding: EdgeInsets.only(top: t.spacingXs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isFlash
                ? context.l10n.flasherFlashing
                : context.l10n.flasherDownloading,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: t.ink3),
          ),
          SizedBox(height: t.spacingXxs),
          Row(
            children: [
              Expanded(
                child: isFlash
                    ? _pillTrack(context, active.progress)
                    : _segmentedTrack(context, active.progress),
              ),
              SizedBox(width: t.spacingXs),
              Text(
                '${(active.progress * 100).round()}%',
                style: t.monoBody(color: t.primary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = MeshTokens.of(context);
    final panel = _progressPanel(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: t.spacingSm,
        vertical: t.spacingXxs + 4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tag,
                      style: t.monoBody(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      subLabel,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: t.ink3),
                    ),
                    if (variantLabels.length > 1) ...[
                      SizedBox(height: t.spacingXxs),
                      Wrap(
                        spacing: t.spacingXxs,
                        children: [
                          for (var i = 0; i < variantLabels.length; i++)
                            _variantToggle(
                              context,
                              label: variantLabels[i],
                              selected: i == selectedVariantIndex,
                              onTap: () => onSelectVariant?.call(i),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              _actionIcon(
                context,
                icon: Icons.restart_alt,
                state: resetState,
                onTap: onTapReset,
                tooltip: context.l10n.flasherFullResetShortLabel,
                readyTooltip: context.l10n.flasherFullResetReadyTooltip,
              ),
              SizedBox(width: t.spacingXxs),
              _actionIcon(
                context,
                icon: Icons.download,
                state: updateState,
                onTap: onTapUpdate,
                tooltip: context.l10n.flasherUpdateShortLabel,
                readyTooltip: context.l10n.flasherUpdateReadyTooltip,
              ),
            ],
          ),
          ?panel,
        ],
      ),
    );
  }
}
