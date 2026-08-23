import 'package:flutter/material.dart';

import '../theme/dashed_rounded_border.dart';
import '../theme/mesh_tokens.dart';

/// Generic settings value stepper — the canonical fixed-choice picker
/// control (user spec 2026-08-23: every such picker looks identical to
/// Appearance -> Button border): circular tinted +/- buttons flanking a
/// stable-width mono value pill, cycling through a fixed list of choices
/// that previously lived in bottom sheets, dropdowns and dialogs.
///
/// The circles follow the app-wide `buttonBorder` setting
/// ('none'/'solid'/'dotted'), like every other member of the button family —
/// they are hand-drawn, not theme buttons, so the side/shape is derived here
/// the same way as `applyChromeRadii` does for real buttons. (The Custom
/// Style editor's own border stepper is intentionally separate: its circles
/// preview the border value being edited, not the applied one.)
class SettingsValueStepper<T> extends StatelessWidget {
  const SettingsValueStepper({
    super.key,
    required this.values,
    required this.value,
    required this.labelOf,
    required this.buttonBorder,
    required this.onChanged,
    this.enabled = true,
    this.pillMaxWidth,
  });

  final List<T> values;
  final T value;
  final String Function(BuildContext, T) labelOf;

  /// Current app-wide buttonBorder ('none'/'solid'/'dotted', null == 'none').
  final String? buttonBorder;
  final ValueChanged<T> onChanged;
  final bool enabled;

  /// Optional cap on the value pill's width. The pill normally sizes to the
  /// WIDEST label in [values]; with user-defined labels (e.g. CYR2LAT
  /// profile names) that is unbounded, so callers on narrow layouts pass a
  /// cap and over-long labels ellipsize instead of crushing their row.
  final double? pillMaxWidth;

  void _step(int direction) {
    final index = values.indexOf(value);
    // A stored value outside the fixed cycle (possible only for prefs
    // predating the choice list) lands on the first choice with one tap.
    final next = index == -1
        ? values.first
        : values[(index + direction + values.length) % values.length];
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = MeshTokens.of(context);

    final borderStyle = buttonBorder ?? 'none';
    final circleBorderSide = borderStyle == 'none'
        ? BorderSide.none
        : BorderSide(color: scheme.primary);
    final circleShape = borderStyle == 'dotted'
        ? DashedCircleBorder(side: circleBorderSide)
        : CircleBorder(side: circleBorderSide);

    Widget circleButton(IconData icon, VoidCallback onPressed) {
      return SizedBox(
        width: 36,
        height: 36,
        child: DecoratedBox(
          decoration: ShapeDecoration(
            shape: circleShape,
            color: scheme.primary.withValues(alpha: 0.2),
          ),
          child: IconButton(
            padding: EdgeInsets.zero,
            iconSize: 18,
            color: scheme.primary,
            icon: Icon(icon),
            onPressed: enabled ? onPressed : null,
          ),
        ),
      );
    }

    final valuePill = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: pillMaxWidth ?? double.infinity),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: t.spacingSm,
          vertical: t.spacingSm,
        ),
        decoration: BoxDecoration(
          color: scheme.primary.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(t.sm),
        ),
        child: IntrinsicWidth(
          child: Stack(
            alignment: Alignment.center,
            children: [
              for (final v in values)
                Visibility(
                  visible: v == value,
                  maintainState: true,
                  maintainAnimation: true,
                  maintainSize: true,
                  child: Text(
                    labelOf(context, v),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: t.monoBody(
                      color: enabled
                          ? scheme.onSurface
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        circleButton(Icons.remove, () => _step(-1)),
        SizedBox(width: t.spacingXxs),
        valuePill,
        SizedBox(width: t.spacingXxs),
        circleButton(Icons.add, () => _step(1)),
      ],
    );
  }
}
