import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/translation_support.dart';
import 'mesh_selection_sheet.dart';

class MessageTranslationButton extends StatelessWidget {
  final bool enabled;
  final String? languageCode;
  final VoidCallback onPressed;

  const MessageTranslationButton({
    super.key,
    required this.enabled,
    required this.languageCode,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final label = _languageLabel(
      languageCode,
      context.l10n.translation_systemLanguage,
    );
    return IconButton(
      icon: Icon(enabled ? Icons.translate : Icons.translate_outlined),
      onPressed: onPressed,
      tooltip: enabled
          ? context.l10n.translation_translateTo(label)
          : context.l10n.translation_translationOptions,
    );
  }
}

/// Message-translation options ("Translate before sending" toggle + target
/// language). Rewritten 2026-08-29 from a hand-rolled bottom sheet with
/// Material radio ListTiles to the canonical selection sheet ("winda",
/// [showMeshSelectionSheet]) — content-hugging height, [MeshSelectorDot]
/// rows, Cancel/Save footer. The callbacks now fire once, on Save, with the
/// final values (the old sheet applied every intermediate tap immediately).
Future<void> showMessageTranslationSheet({
  required BuildContext context,
  required bool enabled,
  required String? selectedLanguageCode,
  required ValueChanged<bool> onEnabledChanged,
  required ValueChanged<String?> onLanguageSelected,
}) async {
  final l10n = context.l10n;
  final result = await showMeshSelectionSheet<String?>(
    context,
    title: l10n.translation_messageTranslation,
    toggleTitle: l10n.translation_translateBeforeSending,
    toggleSubtitle: l10n.translation_composerEnabledHint,
    toggleValue: enabled,
    selectedValue: selectedLanguageCode,
    options: [
      MeshSelectionOption<String?>(
        value: null,
        label: l10n.translation_useAppLanguage,
      ),
      for (final option in supportedTranslationLanguages)
        MeshSelectionOption<String?>(
          value: option.code,
          label: option.label,
          trailing: option.code.toUpperCase(),
        ),
    ],
  );
  if (result == null) return;
  if (result.toggleValue != null && result.toggleValue != enabled) {
    onEnabledChanged(result.toggleValue!);
  }
  if (result.value != selectedLanguageCode) {
    onLanguageSelected(result.value);
  }
}

String _languageLabel(String? languageCode, String systemLanguageFallback) {
  if (languageCode == null) {
    return systemLanguageFallback;
  }
  for (final option in supportedTranslationLanguages) {
    if (option.code == languageCode) {
      return option.label;
    }
  }
  return languageCode.toUpperCase();
}
