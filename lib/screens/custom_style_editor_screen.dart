import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/custom_style_overrides.dart';
import '../services/app_settings_service.dart';
import '../theme/mesh_tokens.dart';
import '../theme/styles/default_style.dart';
import '../widgets/mesh_ui.dart';

class _ColorFieldSpec {
  const _ColorFieldSpec(this.key, this.label, this.defaultColor);
  final String key;
  final String label;
  final Color defaultColor;
}

class _FontFieldSpec {
  const _FontFieldSpec(this.key, this.label, this.defaultSize);
  final String key;
  final String label;
  final double defaultSize;
}

final List<_ColorFieldSpec> _colorFields = [
  _ColorFieldSpec('bg', 'Background', MeshTokens.defaultTokens.bg),
  _ColorFieldSpec('ink', 'Text', MeshTokens.defaultTokens.ink),
  _ColorFieldSpec('line', 'Divider', MeshTokens.defaultTokens.line),
  _ColorFieldSpec(
    'primary',
    'Primary accent',
    MeshTokens.defaultTokens.primary,
  ),
  _ColorFieldSpec(
    'secondary',
    'Secondary accent',
    MeshTokens.defaultTokens.secondary,
  ),
  _ColorFieldSpec('signal', 'Signal', MeshTokens.defaultTokens.signal),
  _ColorFieldSpec('warn', 'Warning', MeshTokens.defaultTokens.warn),
  _ColorFieldSpec('alert', 'Alert', MeshTokens.defaultTokens.alert),
  _ColorFieldSpec('me', 'Message bubble', MeshTokens.defaultTokens.me),
  _ColorFieldSpec(
    'meInk',
    'Message bubble text',
    MeshTokens.defaultTokens.meInk,
  ),
];

final List<_FontFieldSpec> _fontFields = [
  _FontFieldSpec(
    'bodyMedium',
    'Body',
    defaultStyle.light.textTheme.bodyMedium?.fontSize ?? 12,
  ),
  _FontFieldSpec(
    'bodySmall',
    'Body (small)',
    defaultStyle.light.textTheme.bodySmall?.fontSize ?? 11,
  ),
  _FontFieldSpec(
    'titleSmall',
    'Title',
    defaultStyle.light.textTheme.titleSmall?.fontSize ?? 13,
  ),
  _FontFieldSpec(
    'labelSmall',
    'Label (small)',
    defaultStyle.light.textTheme.labelSmall?.fontSize ?? 10,
  ),
  _FontFieldSpec(
    'labelMedium',
    'Label',
    defaultStyle.light.textTheme.labelMedium?.fontSize ?? 15,
  ),
  _FontFieldSpec(
    'monoCaptionSize',
    'Mono caption',
    MeshTokens.defaultTokens.monoCaptionSize,
  ),
  _FontFieldSpec(
    'monoBodySize',
    'Mono body',
    MeshTokens.defaultTokens.monoBodySize,
  ),
];

// A compact preset palette for the color picker sheet — common hues at a
// couple of lightness steps, not tied to any single brand.
const List<Color> _presetSwatches = [
  Color(0xFF000000),
  Color(0xFF1A1A1A),
  Color(0xFF334155),
  Color(0xFF64748B),
  Color(0xFF94A3B8),
  Color(0xFFCBD5E1),
  Color(0xFFF1F5F9),
  Color(0xFFFFFFFF),
  Color(0xFFEF4444),
  Color(0xFFF97316),
  Color(0xFFF59E0B),
  Color(0xFFEAB308),
  Color(0xFF84CC16),
  Color(0xFF22C55E),
  Color(0xFF10B981),
  Color(0xFF14B8A6),
  Color(0xFF06B6D4),
  Color(0xFF0EA5E9),
  Color(0xFF3B82F6),
  Color(0xFF6366F1),
  Color(0xFF8B5CF6),
  Color(0xFFA855F7),
  Color(0xFFD946EF),
  Color(0xFFEC4899),
];

/// Editor for the "custom" [MeshStyle] — a shortlist of the most visible
/// colors plus a handful of textTheme/mono font-size roles, layered on top
/// of [defaultStyle] via [CustomStyleOverrides]. No new l10n keys (english
/// strings only), matching the rest of the 2026-08 theme prompts.
class CustomStyleEditorScreen extends StatelessWidget {
  const CustomStyleEditorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppSettingsService>(
      builder: (context, settingsService, child) {
        final overrides = settingsService.settings.customStyleOverrides;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Custom style'),
            centerTitle: true,
            actions: [
              PopupMenuButton<void>(
                itemBuilder: (context) => [
                  PopupMenuItem(
                    onTap: settingsService.resetAllCustomOverrides,
                    child: const Text('Reset all'),
                  ),
                ],
              ),
            ],
          ),
          body: SafeArea(
            top: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
              children: [
                const SectionHeader('Colors'),
                MeshCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (var i = 0; i < _colorFields.length; i++) ...[
                        if (i > 0) const Divider(height: 1, indent: 16),
                        _ColorFieldRow(
                          spec: _colorFields[i],
                          overrides: overrides,
                          settingsService: settingsService,
                        ),
                      ],
                    ],
                  ),
                ),
                const SectionHeader('Font sizes'),
                MeshCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (var i = 0; i < _fontFields.length; i++) ...[
                        if (i > 0) const Divider(height: 1, indent: 16),
                        _FontFieldRow(
                          spec: _fontFields[i],
                          overrides: overrides,
                          settingsService: settingsService,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ColorFieldRow extends StatelessWidget {
  const _ColorFieldRow({
    required this.spec,
    required this.overrides,
    required this.settingsService,
  });

  final _ColorFieldSpec spec;
  final CustomStyleOverrides overrides;
  final AppSettingsService settingsService;

  @override
  Widget build(BuildContext context) {
    final override = overrides.colorOverrides[spec.key];
    final currentColor = override != null ? Color(override) : spec.defaultColor;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: Text(spec.label),
      onTap: () => _openColorPicker(context, currentColor),
      leading: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: currentColor,
          shape: BoxShape.circle,
          border: Border.all(color: Theme.of(context).colorScheme.outline),
        ),
      ),
      trailing: override == null
          ? null
          : IconButton(
              icon: const Icon(Icons.restart_alt, size: 20),
              tooltip: 'Reset to default',
              onPressed: () => settingsService.resetCustomOverride(spec.key),
            ),
    );
  }

  void _openColorPicker(BuildContext context, Color currentColor) {
    showMeshSheet<void>(
      context,
      builder: (sheetContext) => _ColorPickerSheet(
        title: spec.label,
        currentColor: currentColor,
        onColorSelected: (color) {
          settingsService.setCustomColorOverride(spec.key, color);
          Navigator.of(sheetContext).pop();
        },
      ),
    );
  }
}

class _ColorPickerSheet extends StatefulWidget {
  const _ColorPickerSheet({
    required this.title,
    required this.currentColor,
    required this.onColorSelected,
  });

  final String title;
  final Color currentColor;
  final ValueChanged<Color> onColorSelected;

  @override
  State<_ColorPickerSheet> createState() => _ColorPickerSheetState();
}

class _ColorPickerSheetState extends State<_ColorPickerSheet> {
  late final TextEditingController _hexController;
  String? _hexError;

  static final RegExp _hexPattern = RegExp(r'^#?([0-9A-Fa-f]{6})$');

  @override
  void initState() {
    super.initState();
    _hexController = TextEditingController(
      text:
          '#${widget.currentColor.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
    );
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  void _applyHex() {
    final match = _hexPattern.firstMatch(_hexController.text.trim());
    if (match == null) {
      setState(() => _hexError = 'Enter a hex color like #RRGGBB');
      return;
    }
    final value = int.parse(match.group(1)!, radix: 16);
    widget.onColorSelected(Color(0xFF000000 | value));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BottomSheetHeader(title: widget.title),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final swatch in _presetSwatches)
                  GestureDetector(
                    key: ValueKey('swatch_${swatch.toARGB32()}'),
                    onTap: () => widget.onColorSelected(swatch),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: swatch,
                      child: swatch.toARGB32() == widget.currentColor.toARGB32()
                          ? Icon(
                              Icons.check,
                              size: 18,
                              color:
                                  ThemeData.estimateBrightnessForColor(
                                        swatch,
                                      ) ==
                                      Brightness.dark
                                  ? Colors.white
                                  : Colors.black,
                            )
                          : null,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _hexController,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[#0-9A-Fa-f]')),
                LengthLimitingTextInputFormatter(7),
              ],
              decoration: InputDecoration(
                labelText: 'Hex color',
                hintText: '#RRGGBB',
                errorText: _hexError,
                suffixIcon: IconButton(
                  key: const ValueKey('applyHexButton'),
                  icon: const Icon(Icons.check),
                  onPressed: () {
                    setState(() => _hexError = null);
                    _applyHex();
                  },
                ),
              ),
              onChanged: (_) => setState(() => _hexError = null),
              onSubmitted: (_) => _applyHex(),
            ),
          ),
        ],
      ),
    );
  }
}

class _FontFieldRow extends StatelessWidget {
  const _FontFieldRow({
    required this.spec,
    required this.overrides,
    required this.settingsService,
  });

  final _FontFieldSpec spec;
  final CustomStyleOverrides overrides;
  final AppSettingsService settingsService;

  static const double _minSize = 8;
  static const double _maxSize = 24;

  @override
  Widget build(BuildContext context) {
    final override = overrides.fontSizeOverrides[spec.key];
    final currentSize = (override ?? spec.defaultSize).clamp(
      _minSize,
      _maxSize,
    );
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: Text(spec.label),
      subtitle: Slider(
        value: currentSize,
        min: _minSize,
        max: _maxSize,
        divisions: ((_maxSize - _minSize) * 2).round(),
        label: currentSize.toStringAsFixed(1),
        onChanged: (value) =>
            settingsService.setCustomFontSizeOverride(spec.key, value),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${currentSize.toStringAsFixed(1)}pt'),
          if (override != null)
            IconButton(
              icon: const Icon(Icons.restart_alt, size: 20),
              tooltip: 'Reset to default',
              onPressed: () => settingsService.resetCustomOverride(spec.key),
            ),
        ],
      ),
    );
  }
}
