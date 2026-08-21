import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../connector/meshcore_connector.dart';
import '../l10n/l10n.dart';
import '../models/radio_settings.dart';
import '../theme/mesh_tokens.dart';
import 'mesh_ui.dart';

/// Matches a `{...}` placeholder token in a CLI command template, e.g. the
/// four tokens in `set radio {freq},{bw},{sf},{cr}`.
final RegExp _placeholderPattern = RegExp(r'\{([^}]+)\}');

/// True if [template] has at least one `{...}` placeholder — the signal
/// `RepeaterCommandDrawer` uses to decide whether tapping a chip opens this
/// popup or sends the command straight to the terminal.
bool commandTemplateHasPlaceholder(String template) =>
    _placeholderPattern.hasMatch(template);

/// Shows a small form for a CLI command template containing `{...}`
/// placeholders. Every field only offers values the firmware actually
/// accepts for that placeholder — no free numeric typing, no system
/// keyboard — except for placeholders with no known constraint (e.g. a
/// free-text name), which fall back to a plain text field.
///
/// [onSend] receives the fully-resolved command string once the user taps
/// Send; the caller (the CLI screen) is responsible for actually
/// transmitting it — this popup only builds the string.
Future<void> showRepeaterCommandParamPopup(
  BuildContext context, {
  required String template,
  required ValueChanged<String> onSend,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _ParamPopup(template: template, onSend: onSend),
  );
}

/// One `{...}` token extracted from the command template, e.g. `freq` or
/// `on|off` or `1-100`.
class _Token {
  final String raw;
  const _Token(this.raw);

  /// Lowercased, trimmed — used to match known parameter names like `freq`.
  String get name => raw.trim().toLowerCase();
}

/// A resolved value source for one token: a fixed list of (label, command
/// value) pairs to step through with +/-, no keyboard. Covers every
/// self-describing placeholder shape found in the real command list:
/// literal choices (`{on|off}`), literal integer ranges (`{1-100}`), and the
/// known LoRa radio enums (bw/sf/cr/tx-power) which aren't spelled out in
/// the placeholder text itself but are defined in `radio_settings.dart`.
class _StepperOptions {
  final List<(String label, String cmd)> values;
  const _StepperOptions(this.values);

  /// `{on|off}`, `{0|1|2}`, `{off|minimal|moderate|strict}`, `{rx|tx}`,
  /// `{none|share|prefs}` — the literal choices are already the command
  /// syntax itself, nothing to look up.
  static _StepperOptions? fromLiteralChoices(String raw) {
    if (!raw.contains('|')) return null;
    final parts = raw.split('|');
    return _StepperOptions([for (final p in parts) (p, p)]);
  }

  /// `{1-100}`, `{0-10000}`, `{1-14}` — a literal inclusive integer range
  /// spelled out in the command syntax. Deliberately does NOT match
  /// hyphenated placeholder *names* like `tx-power-dbm` (those aren't
  /// all-digit, so the regex simply doesn't fire).
  static _StepperOptions? fromLiteralRange(String raw) {
    final m = RegExp(r'^(\d+)-(\d+)$').firstMatch(raw);
    if (m == null) return null;
    final min = int.parse(m.group(1)!);
    final max = int.parse(m.group(2)!);
    if (max <= min || max - min > 500) {
      // Not a real range (or absurdly large) — treat as free text instead.
      return null;
    }
    return _StepperOptions([for (var v = min; v <= max; v++) ('$v', '$v')]);
  }

  static _StepperOptions bandwidth() => _StepperOptions([
    for (final bw in LoRaBandwidth.values) (bw.label, _formatKhz(bw.hz)),
  ]);

  static _StepperOptions spreadingFactor() => _StepperOptions([
    for (final sf in LoRaSpreadingFactor.values) (sf.label, '${sf.value}'),
  ]);

  static _StepperOptions codingRate() => _StepperOptions([
    for (final cr in LoRaCodingRate.values) (cr.label, '${cr.value}'),
  ]);

  static _StepperOptions txPowerDbm(int maxDbm) =>
      _StepperOptions([for (var v = 0; v <= maxDbm; v++) ('$v dBm', '$v')]);

  static String _formatKhz(int hz) {
    final khz = hz / 1000;
    return khz == khz.roundToDouble() ? khz.toInt().toString() : '$khz';
  }
}

/// One field's live state + how to render it. Three shapes: a looping
/// stepper over a fixed value list, a tap-to-pick region/frequency list, or
/// (only when nothing else matches) a plain text field.
abstract class _FieldController {
  String get commandValue;
  Widget build(BuildContext context, MeshTokens t, VoidCallback onChanged);

  factory _FieldController.forToken(_Token token, {required int maxTxPower}) {
    final literal =
        _StepperOptions.fromLiteralChoices(token.raw) ??
        _StepperOptions.fromLiteralRange(token.raw);
    if (literal != null) {
      return _StepperFieldController(label: token.raw, options: literal);
    }
    switch (token.name) {
      case 'freq':
        return _FreqFieldController();
      case 'bw':
        return _StepperFieldController(
          label: token.name,
          options: _StepperOptions.bandwidth(),
        );
      case 'sf':
        return _StepperFieldController(
          label: token.name,
          options: _StepperOptions.spreadingFactor(),
        );
      case 'cr':
        return _StepperFieldController(
          label: token.name,
          options: _StepperOptions.codingRate(),
        );
      case 'tx-power-dbm':
        return _StepperFieldController(
          label: token.name,
          options: _StepperOptions.txPowerDbm(maxTxPower),
        );
      default:
        return _TextFieldController(label: token.raw);
    }
  }
}

class _StepperFieldController implements _FieldController {
  final String label;
  final _StepperOptions options;
  int _index;

  _StepperFieldController({required this.label, required this.options})
    : _index = 0;

  @override
  String get commandValue => options.values[_index].$2;

  @override
  Widget build(BuildContext context, MeshTokens t, VoidCallback onChanged) {
    final count = options.values.length;
    void step(int delta) {
      _index = (_index + delta + count) % count;
      onChanged();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: t.monoCaption(color: t.ink4),
        ),
        SizedBox(height: t.spacingXxs),
        Row(
          children: [
            _stepperButton(t, '−', () => step(-1)),
            SizedBox(width: t.spacingXs),
            Expanded(
              child: Container(
                alignment: Alignment.center,
                padding: EdgeInsets.symmetric(vertical: t.spacingXs),
                decoration: BoxDecoration(
                  color: t.primaryBg,
                  borderRadius: BorderRadius.circular(t.sm),
                ),
                child: Text(
                  options.values[_index].$1,
                  style: t
                      .monoBody(color: t.primary)
                      .copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            SizedBox(width: t.spacingXs),
            _stepperButton(t, '+', () => step(1)),
          ],
        ),
      ],
    );
  }

  Widget _stepperButton(MeshTokens t, String glyph, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: t.primaryBg,
          border: Border.all(color: t.primaryLine),
          shape: BoxShape.circle,
        ),
        child: Text(
          glyph,
          style: t
              .monoBody(color: t.primary)
              .copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

/// `freq` specifically: tap opens a scrollable list of the same regional
/// presets already offered in `repeater_settings_screen.dart`
/// (`RadioSettings.presets`) — not a stepper, since ~45 raw frequency
/// values aren't reasonably steppable one tap at a time.
class _FreqFieldController implements _FieldController {
  int _presetIndex = 0;

  @override
  String get commandValue =>
      '${RadioSettings.presets[_presetIndex].$2.frequencyMHz}';

  @override
  Widget build(BuildContext context, MeshTokens t, VoidCallback onChanged) {
    final l10n = context.l10n;
    final preset = RadioSettings.presets[_presetIndex];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.repeater_paramPopup_region,
          textAlign: TextAlign.center,
          style: t.monoCaption(color: t.ink4),
        ),
        SizedBox(height: t.spacingXxs),
        InkWell(
          borderRadius: BorderRadius.circular(t.sm),
          onTap: () async {
            final picked = await showModalBottomSheet<int>(
              context: context,
              showDragHandle: true,
              builder: (context) => _RegionPickerSheet(selected: _presetIndex),
            );
            if (picked != null) {
              _presetIndex = picked;
              onChanged();
            }
          },
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: t.spacingSm,
              vertical: t.spacingXs,
            ),
            decoration: BoxDecoration(
              color: t.primaryBg,
              borderRadius: BorderRadius.circular(t.sm),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${preset.$1} · ${preset.$2.frequencyMHz} MHz',
                    style: t.monoBody(color: t.primary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.expand_more, color: t.primary, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RegionPickerSheet extends StatelessWidget {
  final int selected;
  const _RegionPickerSheet({required this.selected});

  @override
  Widget build(BuildContext context) {
    final t = MeshTokens.of(context);
    return ListView.separated(
      shrinkWrap: true,
      itemCount: RadioSettings.presets.length,
      separatorBuilder: (_, _) => Divider(height: 1, color: t.line),
      itemBuilder: (context, index) {
        final preset = RadioSettings.presets[index];
        return ListTile(
          selected: index == selected,
          title: Text('${preset.$1} · ${preset.$2.frequencyMHz} MHz'),
          onTap: () => Navigator.pop(context, index),
        );
      },
    );
  }
}

/// Fallback for any placeholder with no known constraint (e.g. a free-text
/// name or key) — a plain text field, keyboard unavoidable.
class _TextFieldController implements _FieldController {
  final String label;
  final TextEditingController controller = TextEditingController();

  _TextFieldController({required this.label});

  @override
  String get commandValue => controller.text;

  @override
  Widget build(BuildContext context, MeshTokens t, VoidCallback onChanged) {
    return TextField(
      controller: controller,
      onChanged: (_) => onChanged(),
      style: t.monoBody(color: t.ink),
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        filled: true,
        fillColor: t.primaryBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(t.sm),
          borderSide: BorderSide(color: t.primaryLine),
        ),
      ),
    );
  }
}

class _ParamPopup extends StatefulWidget {
  final String template;
  final ValueChanged<String> onSend;

  const _ParamPopup({required this.template, required this.onSend});

  @override
  State<_ParamPopup> createState() => _ParamPopupState();
}

class _ParamPopupState extends State<_ParamPopup> {
  late final List<_Token> _tokens;
  late final List<_FieldController> _fields;

  @override
  void initState() {
    super.initState();
    _tokens = [
      for (final m in _placeholderPattern.allMatches(widget.template))
        _Token(m.group(1)!),
    ];
    final maxTxPower = context.read<MeshCoreConnector>().maxTxPower ?? 22;
    _fields = [
      for (final token in _tokens)
        _FieldController.forToken(token, maxTxPower: maxTxPower),
    ];
  }

  String get _resolvedCommand {
    var result = widget.template;
    for (var i = 0; i < _tokens.length; i++) {
      result = result.replaceFirst(
        '{${_tokens[i].raw}}',
        _fields[i].commandValue,
      );
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = MeshTokens.of(context);
    final commandName = widget.template.split(RegExp(r'\s|{')).first.trim();

    return Dialog(
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 360,
          // A command like "set radio {freq},{bw},{sf},{cr}" has 4 fields —
          // on a short screen/test surface that can exceed the dialog's
          // natural height. Cap it and let only the field list scroll
          // (Step 4 below), keeping title/preview/buttons always visible.
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: MeshCard(
          padding: EdgeInsets.all(t.spacingMd),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.repeater_paramPopup_title(commandName),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              SizedBox(height: t.spacingXs),
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  horizontal: t.spacingSm,
                  vertical: t.spacingXs,
                ),
                decoration: BoxDecoration(
                  color: t.bg1,
                  borderRadius: BorderRadius.circular(t.sm),
                ),
                child: Text(
                  _resolvedCommand,
                  style: t.monoBody(color: t.primary),
                ),
              ),
              SizedBox(height: t.spacingSm),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final field in _fields) ...[
                        field.build(context, t, () => setState(() {})),
                        SizedBox(height: t.spacingXs),
                      ],
                    ],
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(context.l10n.common_cancel),
                  ),
                  SizedBox(width: t.spacingXs),
                  FilledButton(
                    onPressed: () {
                      final resolved = _resolvedCommand;
                      Navigator.pop(context);
                      widget.onSend(resolved);
                    },
                    child: Text(l10n.repeater_paramPopup_send),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
