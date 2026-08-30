import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/mesh_tokens.dart';
import 'mesh_ui.dart';

/// One selectable row of a [showMeshSelectionSheet] list.
class MeshSelectionOption<T> {
  final T value;
  final String label;

  /// Optional right-aligned mono caption (e.g. a language code).
  final String? trailing;

  const MeshSelectionOption({
    required this.value,
    required this.label,
    this.trailing,
  });
}

/// What the sheet hands back on Save; null result = cancelled.
class MeshSelectionResult<T> {
  final T value;
  final bool? toggleValue;

  const MeshSelectionResult({required this.value, this.toggleValue});
}

/// The app's canonical selection bottom sheet — the "winda" (accepted
/// 2026-08-29, .mockups/channel-card-parity.html):
/// - height always hugs the content — never a fixed fraction of the screen,
///   never dead space below the footer (unlike the pre-2026-08-29
///   edit-channel sheet's fixed `initialChildSize: 0.65`),
/// - [BottomSheetHeader] on top (grabber + title + close),
/// - optional switch row (e.g. "Translate before sending") above the list,
/// - scrollable single-choice list, each row led by [MeshSelectorDot]
///   (variant B2 — same grammar as the sort/filter dropdown rows),
/// - footer inside the bottom SafeArea, never under the system bars:
///   Cancel as a bare [TextButton] (no fill), Save as a [FilledButton];
///   footer padding LTRB(spacingMd, spacingXs, spacingMd, spacingMd) —
///   same as the pre-existing sheet footers.
///
/// Selection is local until Save — Cancel (or dismissing) discards.
Future<MeshSelectionResult<T>?> showMeshSelectionSheet<T>(
  BuildContext context, {
  required String title,
  String? subtitle,
  required List<MeshSelectionOption<T>> options,
  required T selectedValue,
  String? toggleTitle,
  String? toggleSubtitle,
  bool toggleValue = false,
}) {
  return showMeshSheet<MeshSelectionResult<T>>(
    context,
    builder: (sheetContext) => _MeshSelectionSheetBody<T>(
      title: title,
      subtitle: subtitle,
      options: options,
      selectedValue: selectedValue,
      toggleTitle: toggleTitle,
      toggleSubtitle: toggleSubtitle,
      toggleValue: toggleValue,
    ),
  );
}

class _MeshSelectionSheetBody<T> extends StatefulWidget {
  final String title;
  final String? subtitle;
  final List<MeshSelectionOption<T>> options;
  final T selectedValue;
  final String? toggleTitle;
  final String? toggleSubtitle;
  final bool toggleValue;

  const _MeshSelectionSheetBody({
    required this.title,
    required this.subtitle,
    required this.options,
    required this.selectedValue,
    required this.toggleTitle,
    required this.toggleSubtitle,
    required this.toggleValue,
  });

  @override
  State<_MeshSelectionSheetBody<T>> createState() =>
      _MeshSelectionSheetBodyState<T>();
}

class _MeshSelectionSheetBodyState<T>
    extends State<_MeshSelectionSheetBody<T>> {
  late T _selected;
  late bool _toggle;

  @override
  void initState() {
    super.initState();
    _selected = widget.selectedValue;
    _toggle = widget.toggleValue;
  }

  @override
  Widget build(BuildContext context) {
    final t = MeshTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BottomSheetHeader(title: widget.title, subtitle: widget.subtitle),
          if (widget.toggleTitle != null)
            SwitchListTile(
              contentPadding: EdgeInsets.symmetric(horizontal: t.spacingMd),
              title: Text(widget.toggleTitle!),
              subtitle: widget.toggleSubtitle == null
                  ? null
                  : Text(widget.toggleSubtitle!),
              value: _toggle,
              onChanged: (value) => setState(() => _toggle = value),
            ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.symmetric(horizontal: 10),
              itemCount: widget.options.length,
              itemBuilder: (context, index) {
                final option = widget.options[index];
                final selected = option.value == _selected;
                return InkWell(
                  borderRadius: BorderRadius.circular(t.buttonRadius),
                  onTap: () => setState(() => _selected = option.value),
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 1),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? scheme.primary.withValues(alpha: 0.2)
                          : null,
                      borderRadius: BorderRadius.circular(t.buttonRadius),
                    ),
                    child: Row(
                      children: [
                        MeshSelectorDot(selected: selected),
                        SizedBox(width: t.spacingXxs + 4),
                        Expanded(
                          child: Text(
                            option.label,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: selected
                                      ? scheme.primary
                                      : scheme.onSurface,
                                  fontWeight: selected
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                ),
                          ),
                        ),
                        if (option.trailing != null)
                          Text(
                            option.trailing!,
                            style: t.monoCaption(
                              color: selected
                                  ? scheme.primary
                                  : scheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              t.spacingMd,
              t.spacingXs,
              t.spacingMd,
              t.spacingMd,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(context.l10n.common_cancel),
                  ),
                ),
                SizedBox(width: t.spacingSm),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(
                      context,
                      MeshSelectionResult<T>(
                        value: _selected,
                        toggleValue: widget.toggleTitle == null
                            ? null
                            : _toggle,
                      ),
                    ),
                    child: Text(context.l10n.common_save),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
