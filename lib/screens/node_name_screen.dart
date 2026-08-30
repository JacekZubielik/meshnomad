import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../connector/meshcore_connector.dart';
import '../helpers/snack_bar_builder.dart';
import '../l10n/l10n.dart';
import '../theme/mesh_tokens.dart';
import '../widgets/mesh_ui.dart';

Future<void> pushNodeNameScreen(BuildContext context) {
  return Navigator.push(
    context,
    MaterialPageRoute<void>(builder: (context) => const NodeNameScreen()),
  );
}

/// Node-name editor — its own card screen (redesign 2026-08-23; used to be
/// an AlertDialog popup, then briefly an inline pill field that cramped the
/// row). A text field with a borderless Save button; system back discards.
class NodeNameScreen extends StatefulWidget {
  const NodeNameScreen({super.key});

  @override
  State<NodeNameScreen> createState() => _NodeNameScreenState();
}

class _NodeNameScreenState extends State<NodeNameScreen> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: context.read<MeshCoreConnector>().selfName ?? '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final connector = context.read<MeshCoreConnector>();
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    await connector.setNodeName(name);
    await connector.refreshDeviceInfo();
    if (!mounted) return;
    showDismissibleSnackBar(
      context,
      content: Text(l10n.settings_nodeNameUpdated),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = MeshTokens.of(context);
    return SelectionArea(
      child: Scaffold(
        appBar: AppBar(
          // Circular/accent app-bar family (2026-08-29) — see
          // docs/superpowers/meshnomad-vault/templates/ui-patterns/app-bar-schema.md.
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: Theme.of(context).colorScheme.primary,
            ),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: Text(l10n.settings_nodeName),
          centerTitle: true,
        ),
        body: SafeArea(
          top: false,
          child: ListView(
            padding: EdgeInsets.symmetric(vertical: t.spacingXs),
            children: [
              MeshCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _controller,
                      maxLength: 31,
                      decoration: InputDecoration(
                        labelText: l10n.settings_nodeName,
                        hintText: l10n.settings_nodeNameHint,
                        border: const OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _save(),
                    ),
                    SizedBox(height: t.spacingMd),
                    ListenableBuilder(
                      listenable: _controller,
                      builder: (context, _) {
                        return SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            // Plain action button, not a switch-style
                            // control — never renders the app-wide
                            // buttonBorder style.
                            style: const ButtonStyle(
                              side: WidgetStatePropertyAll(BorderSide.none),
                            ),
                            onPressed: _controller.text.trim().isEmpty
                                ? null
                                : _save,
                            icon: const Icon(Icons.save_outlined),
                            label: Text(l10n.common_save),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
