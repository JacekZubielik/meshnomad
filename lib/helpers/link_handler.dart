import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/l10n.dart';
import '../utils/platform_info.dart';
import '../helpers/snack_bar_builder.dart';

class LinkHandler {
  static TextStyle defaultLinkStyle(BuildContext context, TextStyle base) {
    final brightness = Theme.of(context).brightness;
    final orange = brightness == Brightness.dark
        ? const Color(0xFFFFB74D)
        : const Color(0xFFE65100);
    return base.copyWith(color: orange, decoration: TextDecoration.underline);
  }

  /// Returns a [SelectableLinkify] on every platform (2026-09-05): message
  /// text is the one thing in a chat bubble that must be selectable, and a
  /// plain [Linkify] under the bubble's long-press GestureDetector never was
  /// on mobile — the bubble's own recognizer won the long press, so only
  /// the (SelectableText) sender name and time ever selected. A
  /// SelectableText handles its own long press, deeper than the bubble's.
  static Widget buildLinkifyText({
    required BuildContext context,
    required String text,
    required TextStyle style,
    TextStyle? linkStyle,
    VoidCallback? onSecondaryTap,
  }) {
    final effectiveLinkStyle = linkStyle ?? defaultLinkStyle(context, style);
    const options = LinkifyOptions(humanize: false, defaultToHttps: false);
    const linkifiers = [UrlLinkifier(), EmailLinkifier()];
    void onOpen(LinkableElement link) => handleLinkTap(context, link.url);

    final linkify = SelectableLinkify(
      text: text,
      style: style,
      linkStyle: effectiveLinkStyle,
      options: options,
      linkifiers: linkifiers,
      onOpen: onOpen,
      // SelectableLinkify defaults this to null and hands it straight to
      // SelectableText.rich, which then shows NO toolbar at all (text
      // selects, but no Copy / Select all — found on-device 2026-09-05).
      // Plain SelectableText defaults to exactly this builder.
      contextMenuBuilder: (context, editableTextState) =>
          AdaptiveTextSelectionToolbar.editableText(
            editableTextState: editableTextState,
          ),
    );
    if (onSecondaryTap == null || !PlatformInfo.isDesktop) return linkify;
    return Listener(
      onPointerDown: (event) {
        if (event.buttons & kSecondaryMouseButton != 0) onSecondaryTap();
      },
      behavior: HitTestBehavior.translucent,
      child: linkify,
    );
  }

  static Future<void> handleLinkTap(BuildContext context, String url) async {
    // Show confirmation dialog
    final shouldOpen = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.chat_openLink),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.chat_openLinkConfirmation,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                url,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontFamily: 'monospace'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.common_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.chat_open),
          ),
        ],
      ),
    );

    if (shouldOpen != true) return;

    // Launch URL
    try {
      final uri = Uri.parse(url);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (context.mounted) {
          showDismissibleSnackBar(
            context,
            content: Text(context.l10n.chat_couldNotOpenLink(url)),
            backgroundColor: Colors.red,
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        showDismissibleSnackBar(
          context,
          content: Text(context.l10n.chat_invalidLink),
          backgroundColor: Colors.red,
        );
      }
    }
  }
}
