import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../l10n/l10n.dart';
import '../models/contact.dart';
import '../connector/meshcore_connector.dart';
import '../connector/meshcore_protocol.dart';
import '../theme/mesh_tokens.dart';
import '../widgets/app_bar.dart';
import '../widgets/debug_frame_viewer.dart';
import '../services/repeater_command_service.dart';
import '../widgets/repeater_command_drawer.dart';
import '../widgets/routing_sheet.dart';
import '../helpers/snack_bar_builder.dart';
import '../widgets/mesh_dashed_divider.dart';

class RepeaterCliScreen extends StatefulWidget {
  final Contact repeater;
  final String password;

  const RepeaterCliScreen({
    super.key,
    required this.repeater,
    required this.password,
  });

  @override
  State<RepeaterCliScreen> createState() => _RepeaterCliScreenState();
}

class _RepeaterCliScreenState extends State<RepeaterCliScreen> {
  final TextEditingController _commandController = TextEditingController();
  final FocusNode _commandFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, String>> _commandHistory = [];
  int _historyIndex = -1;
  StreamSubscription<Uint8List>? _frameSubscription;
  RepeaterCommandService? _commandService;

  late final List<Map<String, String>> _quickCommands = [
    {'labelKey': 'advertise', 'command': 'advert'},
    {'labelKey': 'getName', 'command': 'get name'},
    {'labelKey': 'getRadio', 'command': 'get radio'},
    {'labelKey': 'getTx', 'command': 'get tx'},
    {'labelKey': 'discovery', 'command': 'discover.neighbors'},
    {'labelKey': 'neighbors', 'command': 'neighbors'},
    {'labelKey': 'version', 'command': 'ver'},
    {'labelKey': 'clock', 'command': 'clock'},
    {'labelKey': 'clock sync', 'command': 'clock sync'},
  ];

  @override
  void initState() {
    super.initState();
    final connector = Provider.of<MeshCoreConnector>(context, listen: false);
    _commandService = RepeaterCommandService(connector);
    _setupMessageListener();
  }

  @override
  void dispose() {
    _frameSubscription?.cancel();
    _commandService?.dispose();
    _commandController.dispose();
    _commandFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _setupMessageListener() {
    final connector = Provider.of<MeshCoreConnector>(context, listen: false);
    _frameSubscription = connector.receivedFrames.listen((frame) {
      if (frame.isEmpty) return;
      if (frame[0] == respCodeContactMsgRecv ||
          frame[0] == respCodeContactMsgRecvV3) {
        _handleTextMessageResponse(frame);
      }
    });
  }

  int _resolveRepeaterIndex = -1;

  Contact _resolveRepeater(MeshCoreConnector connector) {
    if (_resolveRepeaterIndex >= 0 &&
        _resolveRepeaterIndex < connector.contacts.length &&
        connector.contacts[_resolveRepeaterIndex].publicKeyHex ==
            widget.repeater.publicKeyHex) {
      return connector.contacts[_resolveRepeaterIndex];
    }
    _resolveRepeaterIndex = connector.contacts.indexWhere(
      (c) => c.publicKeyHex == widget.repeater.publicKeyHex,
    );
    if (_resolveRepeaterIndex == -1) {
      return widget.repeater;
    }
    return connector.contacts[_resolveRepeaterIndex];
  }

  void _handleTextMessageResponse(Uint8List frame) {
    final parsed = parseContactMessageText(frame);
    if (parsed == null) return;
    if (!_matchesRepeaterPrefix(parsed.senderPrefix)) return;
    _commandService?.handleResponse(widget.repeater, parsed.text);
  }

  bool _matchesRepeaterPrefix(Uint8List prefix) {
    final target = widget.repeater.publicKey;
    if (target.length < 6 || prefix.length < 6) return false;
    for (int i = 0; i < 6; i++) {
      if (prefix[i] != target[i]) return false;
    }
    return true;
  }

  void _sendCommand({bool showDebug = false}) async {
    final command = _commandController.text.trim();
    if (command.isEmpty) return;

    setState(() {
      _commandHistory.add({
        'type': 'command',
        'text': command,
        'timestamp': DateTime.now().toString(),
      });
    });

    if (showDebug && mounted) {
      final frame = buildSendCliCommandFrame(
        widget.repeater.publicKey,
        command,
      );
      DebugFrameViewer.showFrameDebug(
        context,
        frame,
        context.l10n.repeater_cliCommandFrameTitle,
      );
    }

    try {
      if (_commandService != null) {
        final connector = Provider.of<MeshCoreConnector>(
          context,
          listen: false,
        );
        final repeater = _resolveRepeater(connector);
        final response = await _commandService!.sendCommand(
          repeater,
          command,
          retries: 1,
        );
        if (mounted) {
          setState(() {
            _commandHistory.add({
              'type': 'response',
              'text': response,
              'timestamp': DateTime.now().toString(),
            });
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _commandHistory.add({
            'type': 'response',
            'text': context.l10n.repeater_cliCommandError(e.toString()),
            'timestamp': DateTime.now().toString(),
          });
        });
      }
    }

    _commandController.clear();
    _historyIndex = -1;
    _commandFocusNode.requestFocus();

    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _useQuickCommand(String command) {
    _commandController.text = command;
    _sendCommand();
  }

  void _navigateHistory(bool up) {
    final commands = _commandHistory
        .where((entry) => entry['type'] == 'command')
        .toList()
        .reversed
        .toList();

    if (commands.isEmpty) return;

    if (up) {
      if (_historyIndex < commands.length - 1) {
        _historyIndex++;
      }
    } else {
      if (_historyIndex > 0) {
        _historyIndex--;
      } else {
        _historyIndex = -1;
        _commandController.clear();
        return;
      }
    }

    if (_historyIndex >= 0 && _historyIndex < commands.length) {
      _commandController.text = commands[_historyIndex]['text'] ?? '';
      _commandController.selection = TextSelection.fromPosition(
        TextPosition(offset: _commandController.text.length),
      );
    }
  }

  void _clearHistory() {
    setState(() {
      _commandHistory.clear();
      _historyIndex = -1;
    });
  }

  String _quickCommandLabel(String key) {
    final l10n = context.l10n;
    switch (key) {
      case 'getName':
        return l10n.repeater_cliQuickGetName;
      case 'getRadio':
        return l10n.repeater_cliQuickGetRadio;
      case 'getTx':
        return l10n.repeater_cliQuickGetTx;
      case 'neighbors':
        return l10n.repeater_cliQuickNeighbors;
      case 'version':
        return l10n.repeater_cliQuickVersion;
      case 'advertise':
        return l10n.repeater_cliQuickAdvertise;
      case 'clock':
        return l10n.repeater_cliQuickClock;
      case 'clock sync':
        return l10n.repeater_cliQuickClockSync;
      case 'discovery':
        return l10n.repeater_cliQuickDiscovery;
      default:
        return key;
    }
  }

  @override
  Widget build(BuildContext context) {
    // 07-selection-bugs.md: SelectionArea scoped per-screen (not globally
    // above the Navigator) so "select all" can't sweep in text from other,
    // offstage routes still mounted via maintainState:true.
    return SelectionArea(child: _screenBody(context));
  }

  Widget _screenBody(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final connector = context.watch<MeshCoreConnector>();
    final repeater = _resolveRepeater(connector);
    final isFloodMode = repeater.pathOverride == -1;
    final t = MeshTokens.of(context);

    return Scaffold(
      backgroundColor: MeshTokens.of(context).bg,
      appBar: AppBar(
        backgroundColor: MeshTokens.of(context).bg1,
        title: Text(l10n.repeater_cliTitle),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(isFloodMode ? Icons.waves : Icons.route),
            tooltip: l10n.repeater_routingMode,
            onPressed: () =>
                ContactRoutingSheet.show(context, contact: repeater),
          ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: l10n.repeater_commandHelp,
            onPressed: () => RepeaterCommandDrawer.show(
              context,
              onCommandSelected: _useQuickCommand,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.clear_all),
            tooltip: l10n.repeater_clearHistory,
            onPressed: _commandHistory.isEmpty ? null : _clearHistory,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'debug') {
                if (_commandController.text.trim().isNotEmpty) {
                  _sendCommand(showDebug: true);
                } else {
                  showDismissibleSnackBar(
                    context,
                    content: Text(l10n.repeater_enterCommandFirst),
                  );
                }
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'debug',
                child: Row(
                  children: [
                    const Icon(Icons.bug_report),
                    SizedBox(width: MeshTokens.of(context).spacingXs),
                    Text(l10n.repeater_debugNextCommand),
                  ],
                ),
              ),
            ],
          ),
          const QuickAccessMenuButton(),
        ],
      ),
      body: Column(
        children: [
          // Quick commands bar
          Container(
            color: MeshTokens.of(context).bg1,
            padding: EdgeInsets.fromLTRB(
              t.spacingXs,
              t.spacingXs,
              t.spacingXs,
              t.spacingXs,
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _quickCommands.map((cmd) {
                  final label = _quickCommandLabel(cmd['labelKey']!);
                  return Padding(
                    padding: EdgeInsets.only(right: t.spacingXs),
                    child: ActionChip(
                      label: Text(
                        label,
                        style: MeshTokens.of(context)
                            .monoCaption(color: MeshTokens.of(context).primary)
                            .copyWith(fontWeight: FontWeight.w600),
                      ),
                      backgroundColor: MeshTokens.of(context).primaryBg,
                      side: BorderSide(
                        color: MeshTokens.of(context).primaryLine,
                      ),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _useQuickCommand(cmd['command']!),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const MeshDashedDivider(),

          // Output area
          Expanded(
            child: _commandHistory.isEmpty
                ? _buildEmptyState()
                : _buildCommandHistory(),
          ),

          const MeshDashedDivider(),

          // Command input
          Container(
            color: MeshTokens.of(context).bg1,
            padding: EdgeInsets.all(t.spacingXs),
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.arrow_upward,
                      size: 18,
                      color: scheme.onSurfaceVariant,
                    ),
                    tooltip: l10n.repeater_previousCommand,
                    onPressed: () => _navigateHistory(true),
                    visualDensity: VisualDensity.compact,
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.arrow_downward,
                      size: 18,
                      color: scheme.onSurfaceVariant,
                    ),
                    tooltip: l10n.repeater_nextCommand,
                    onPressed: () => _navigateHistory(false),
                    visualDensity: VisualDensity.compact,
                  ),
                  SizedBox(width: t.spacingXxs),
                  Expanded(
                    child: TextField(
                      controller: _commandController,
                      focusNode: _commandFocusNode,
                      style: MeshTokens.of(
                        context,
                      ).monoBody(color: MeshTokens.of(context).ink),
                      decoration: InputDecoration(
                        hintText: context.l10n.repeater_enterCommandHint,
                        hintStyle: MeshTokens.of(
                          context,
                        ).monoCaption(color: MeshTokens.of(context).ink4),
                        prefixText: '> ',
                        prefixStyle: MeshTokens.of(context).monoBody(
                          color: MeshTokens.of(context).primary,
                          fontWeight: FontWeight.w700,
                        ),
                        filled: true,
                        fillColor: MeshTokens.of(context).bg2,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: t.spacingSm,
                          vertical: t.spacingSm,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            MeshTokens.of(context).pill,
                          ),
                          borderSide: BorderSide(
                            color: MeshTokens.of(context).line2,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            MeshTokens.of(context).pill,
                          ),
                          borderSide: BorderSide(
                            color: MeshTokens.of(context).line2,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            MeshTokens.of(context).pill,
                          ),
                          borderSide: BorderSide(
                            color: MeshTokens.of(context).primary,
                            width: 1.5,
                          ),
                        ),
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendCommand(),
                    ),
                  ),
                  SizedBox(width: t.spacingXs),
                  Material(
                    color: MeshTokens.of(
                      context,
                    ).primary.withValues(alpha: 0.15),
                    shape: CircleBorder(
                      side: BorderSide(
                        color: MeshTokens.of(context).primaryLine,
                      ),
                    ),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _sendCommand();
                      },
                      child: Padding(
                        padding: EdgeInsets.all(t.spacingSm),
                        child: Icon(
                          Icons.send,
                          size: 18,
                          color: MeshTokens.of(context).primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final l10n = context.l10n;
    final t = MeshTokens.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.terminal, size: 48, color: MeshTokens.of(context).ink4),
          SizedBox(height: t.spacingSm),
          Text(
            l10n.repeater_noCommandsSent,
            style: MeshTokens.of(
              context,
            ).monoCaption(color: MeshTokens.of(context).ink3),
          ),
          SizedBox(height: t.spacingXxs),
          Text(
            l10n.repeater_typeCommandOrUseQuick,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: MeshTokens.of(context).ink4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommandHistory() {
    final t = MeshTokens.of(context);
    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.symmetric(
        horizontal: t.spacingSm,
        vertical: t.spacingXs,
      ),
      itemCount: _commandHistory.length,
      itemBuilder: (context, index) {
        final entry = _commandHistory[index];
        final isCommand = entry['type'] == 'command';

        return Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Gutter prefix
              SizedBox(
                width: 20,
                child: Text(
                  isCommand ? '>' : ' ',
                  style: MeshTokens.of(context)
                      .monoCaption(
                        color: isCommand
                            ? MeshTokens.of(context).primary
                            : MeshTokens.of(context).ink3,
                      )
                      .copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              SizedBox(width: t.spacingXs),
              Expanded(
                child: SelectableText(
                  entry['text']!,
                  style: MeshTokens.of(context).monoBody(
                    color: isCommand
                        ? MeshTokens.of(context).primary
                        : MeshTokens.of(context).ink,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
