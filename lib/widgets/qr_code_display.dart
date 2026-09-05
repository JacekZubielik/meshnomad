import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../l10n/l10n.dart';
import '../theme/mesh_tokens.dart';

/// A reusable QR code display widget for sharing data.
///
/// Features:
/// - Configurable size and colors
/// - Optional logo/icon in center
/// - Automatic theming (light/dark mode aware)
/// - Title and instructions
class QrCodeDisplay extends StatelessWidget {
  /// The data to encode in the QR code
  final String data;

  /// Size of the QR code (width and height)
  final double size;

  /// Optional widget to display in the center (e.g., app logo)
  final Widget? embeddedImage;

  /// Size of the embedded image (if provided). Default is ~25% of the
  /// dialog's 250px QR — the upper bound that error-correction level H
  /// (used whenever an image is embedded) still recovers reliably.
  final double embeddedImageSize;

  /// Title displayed above the QR code
  final String? title;

  /// Instructions displayed below the QR code
  final String? instructions;

  /// Background color of the QR code (defaults to white)
  final Color? backgroundColor;

  /// Foreground color of the QR code modules (defaults to black)
  final Color? foregroundColor;

  /// Padding around the QR code (defaults to [MeshTokens.spacingMd] on every
  /// side).
  final EdgeInsets? padding;

  /// Error correction level
  final int errorCorrectionLevel;

  const QrCodeDisplay({
    super.key,
    required this.data,
    this.size = 200,
    this.embeddedImage,
    this.embeddedImageSize = 64,
    this.title,
    this.instructions,
    this.backgroundColor,
    this.foregroundColor,
    this.padding,
    this.errorCorrectionLevel = QrErrorCorrectLevel.M,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final tokens = MeshTokens.of(context);

    // Default colors based on theme
    final bgColor = backgroundColor ?? Colors.white;
    final fgColor = foregroundColor ?? Colors.black;

    return Padding(
      padding: padding ?? EdgeInsets.all(tokens.spacingMd),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null) ...[
            Text(
              title!,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
          ],

          // QR code container with rounded corners
          Container(
            padding: EdgeInsets.all(tokens.spacingMd),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(tokens.lg),
              boxShadow: isDark ? null : tokens.labelShadow,
            ),
            child: embeddedImage != null
                ? _buildQrWithEmbeddedImage(context, fgColor, bgColor)
                : _buildSimpleQr(fgColor, bgColor),
          ),

          if (instructions != null) ...[
            const SizedBox(height: 16),
            Text(
              instructions!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSimpleQr(Color fgColor, Color bgColor) {
    return QrImageView(
      data: data,
      version: QrVersions.auto,
      size: size,
      backgroundColor: bgColor,
      errorCorrectionLevel: errorCorrectionLevel,
      eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: fgColor),
      dataModuleStyle: QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.square,
        color: fgColor,
      ),
    );
  }

  Widget _buildQrWithEmbeddedImage(
    BuildContext context,
    Color fgColor,
    Color bgColor,
  ) {
    return Stack(
      alignment: Alignment.center,
      children: [
        QrImageView(
          data: data,
          version: QrVersions.auto,
          size: size,
          backgroundColor: bgColor,
          // Use higher error correction when embedding image
          errorCorrectionLevel: QrErrorCorrectLevel.H,
          eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: fgColor),
          dataModuleStyle: QrDataModuleStyle(
            dataModuleShape: QrDataModuleShape.square,
            color: fgColor,
          ),
        ),
        // Circular quiet zone: a thin ring of QR background around the
        // logo so no data module touches it. Kept at 2dp (not a spacing
        // token) — anything wider shrank the mark to a dot inside its own
        // box (2026-09-03 feedback).
        Container(
          width: embeddedImageSize,
          height: embeddedImageSize,
          decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
          padding: const EdgeInsets.all(2),
          child: embeddedImage,
        ),
      ],
    );
  }
}

/// Dialog to display a QR code for sharing
class QrCodeShareDialog extends StatelessWidget {
  final String data;
  final String? title;
  final String? instructions;
  final Widget? embeddedImage;

  const QrCodeShareDialog({
    super.key,
    required this.data,
    this.title,
    this.instructions,
    this.embeddedImage,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: EdgeInsets.all(MeshTokens.of(context).spacingLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            QrCodeDisplay(
              data: data,
              size: 250,
              title: title,
              instructions: instructions,
              embeddedImage: embeddedImage,
              padding: EdgeInsets.zero,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: Text(context.l10n.common_done),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Show the dialog
  static Future<void> show({
    required BuildContext context,
    required String data,
    String? title,
    String? instructions,
    Widget? embeddedImage,
  }) {
    return showDialog(
      context: context,
      builder: (context) => QrCodeShareDialog(
        data: data,
        title: title,
        instructions: instructions,
        embeddedImage: embeddedImage,
      ),
    );
  }
}
