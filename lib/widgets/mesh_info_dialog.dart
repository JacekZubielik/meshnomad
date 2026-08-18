import 'package:flutter/material.dart';

import '../theme/mesh_tokens.dart';

/// The one shared pattern for full-screen info popups (battery, nearby
/// repeaters, radio stats, transport details, …): an equal inset
/// ([MeshTokens.spacingMd]) on every side, content-hugging height when there
/// is little to show (vertical centering keeps the top and bottom gaps
/// identical), and a hard cap at the inset with internal scrolling when
/// there is more. Build every info popup through [showMeshInfoDialog] —
/// never hand-roll an AlertDialog for these. Other dialogs that want the
/// same equal-inset pattern (e.g. the route map popup in
/// `channel_chat_screen.dart`) should read `MeshTokens.of(context).spacingMd`
/// directly rather than duplicating a literal, so they stay in sync with
/// this one as the token changes.
class MeshInfoDialog extends StatelessWidget {
  static const double _maxWidth = 560;

  final String title;
  final Widget child;

  const MeshInfoDialog({super.key, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final tokens = MeshTokens.of(context);
    return Dialog(
      insetPadding: EdgeInsets.all(tokens.spacingMd),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxWidth),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                tokens.spacingMd,
                tokens.spacingSm,
                tokens.spacingXs,
                0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  tokens.spacingMd,
                  tokens.spacingXs,
                  tokens.spacingMd,
                  tokens.spacingMd,
                ),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Width of the label column for a table-like group of [MeshInfoRow]s:
/// the widest `label:` among [labels] at the current text scale.
double meshInfoLabelColumnWidth(BuildContext context, List<String> labels) {
  final style = Theme.of(context).textTheme.bodySmall;
  var width = 0.0;
  for (final label in labels) {
    final painter = TextPainter(
      text: TextSpan(text: '$label:', style: style),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    if (painter.width > width) width = painter.width;
  }
  return width;
}

/// One label/value line inside a [MeshInfoDialog] body.
///
/// Default layout: label left, value right. With [labelWidth] (from
/// [meshInfoLabelColumnWidth]) rows render as two aligned columns —
/// `Label:` in a fixed-width column, values all starting at the same x
/// and wrapping within their own column.
class MeshInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final double? labelWidth;

  const MeshInfoRow(this.label, this.value, {super.key, this.labelWidth});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final labelStyle = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    final valueStyle = MeshTokens.of(context).monoBody(color: scheme.onSurface);
    final labelWidth = this.labelWidth;

    if (labelWidth != null) {
      return Padding(
        padding: EdgeInsets.symmetric(
          vertical: MeshTokens.of(context).spacingXs,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: labelWidth,
              child: Text('$label:', style: labelStyle),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(value, style: valueStyle)),
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(vertical: MeshTokens.of(context).spacingXs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: labelStyle)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(value, textAlign: TextAlign.right, style: valueStyle),
          ),
        ],
      ),
    );
  }
}

Future<T?> showMeshInfoDialog<T>(
  BuildContext context, {
  required String title,
  required WidgetBuilder builder,
}) {
  return showDialog<T>(
    context: context,
    builder: (dialogContext) =>
        MeshInfoDialog(title: title, child: builder(dialogContext)),
  );
}
