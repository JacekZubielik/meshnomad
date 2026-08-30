import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../connector/meshcore_connector.dart';
import '../l10n/l10n.dart';
import '../services/app_settings_service.dart';
import '../theme/dashed_rounded_border.dart';
import '../theme/mesh_tokens.dart';
import '../widgets/adaptive_app_bar_title.dart';
import '../widgets/app_bar.dart';
import '../widgets/mesh_ui.dart';
import '../widgets/screen_watermark_icon.dart';
import '../widgets/transport_switcher.dart';
import '../helpers/snack_bar_builder.dart';
import 'channels_screen.dart';
import 'scanner_screen.dart';
import 'usb_screen.dart';

class TcpScreen extends StatefulWidget {
  const TcpScreen({super.key});

  @override
  State<TcpScreen> createState() => _TcpScreenState();
}

class _TcpScreenState extends State<TcpScreen> {
  late final TextEditingController _hostController;
  late final TextEditingController _portController;
  late final MeshCoreConnector _connector;
  late final VoidCallback _connectionListener;
  bool _navigatedToChannels = false;

  @override
  void initState() {
    super.initState();
    _hostController = TextEditingController(
      text: context.read<AppSettingsService>().settings.tcpServerAddress,
    );
    _portController = TextEditingController(
      text: context.read<AppSettingsService>().settings.tcpServerPort > 0
          ? context.read<AppSettingsService>().settings.tcpServerPort.toString()
          : '',
    );
    _connector = context.read<MeshCoreConnector>();

    _connectionListener = () {
      if (!mounted) return;
      if (_connector.state == MeshCoreConnectionState.disconnected) {
        _navigatedToChannels = false;
      }
      if (_connector.state == MeshCoreConnectionState.connected &&
          _connector.isTcpTransportConnected &&
          !_navigatedToChannels) {
        context.read<AppSettingsService>().setTcpServerAddress(
          _hostController.text,
        );
        context.read<AppSettingsService>().setTcpServerPort(
          int.tryParse(_portController.text) ?? 0,
        );
        _navigatedToChannels = true;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ChannelsScreen()),
        );
      }
    };
    _connector.addListener(_connectionListener);
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _connector.removeListener(_connectionListener);
    if (!_navigatedToChannels &&
        _connector.activeTransport == MeshCoreTransportType.tcp &&
        _connector.state != MeshCoreConnectionState.disconnected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_connector.disconnect(manual: true));
      });
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 07-selection-bugs.md: SelectionArea scoped per-screen (not globally
    // above the Navigator) so "select all" can't sweep in text from other,
    // offstage routes still mounted via maintainState:true.
    return SelectionArea(child: _screenBody(context));
  }

  void _backToHub(BuildContext context) {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Widget _screenBody(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Theme.of(context).colorScheme.primary,
          ),
          onPressed: () => _backToHub(context),
        ),
        title: AdaptiveAppBarTitle(context.l10n.tcpScreenTitle),
        centerTitle: true,
        actions: const [CircleQuickAccessMenuButton()],
      ),
      body: SafeArea(
        top: false,
        child: Consumer<MeshCoreConnector>(
          builder: (context, connector, child) {
            final isConnecting =
                connector.state == MeshCoreConnectionState.connecting &&
                connector.activeTransport == MeshCoreTransportType.tcp;
            // Connect is only available from a fully disconnected state —
            // scanning, connecting, or an active session must settle first.
            final isButtonDisabled =
                connector.state != MeshCoreConnectionState.disconnected;
            final buttonBorder = context
                .watch<AppSettingsService>()
                .activeProfileOverrides
                .buttonBorder;
            return Stack(
              children: [
                const ScreenWatermarkIcon(icon: Icons.lan),
                ListView(
                  padding: EdgeInsets.only(
                    bottom: MeshTokens.of(context).spacingXlg,
                  ),
                  children: [
                    // Status header
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        MeshTokens.of(context).spacingMd,
                        MeshTokens.of(context).spacingSm,
                        MeshTokens.of(context).spacingMd,
                        MeshTokens.of(context).spacingXxs,
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Align(
                          key: ValueKey(connector.state),
                          alignment: Alignment.centerLeft,
                          child: _buildStatusChip(context, connector),
                        ),
                      ),
                    ),

                    TransportSwitcher(
                      current: MeshCoreTransportType.tcp,
                      onSelectBluetooth: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => const ScannerScreen(),
                          ),
                        );
                      },
                      onSelectUsb: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (_) => const UsbScreen()),
                        );
                      },
                      onSelectTcp: () {},
                    ),

                    // Connection form
                    const SectionHeader('TCP / IP'),
                    MeshCard(
                      padding: EdgeInsets.all(MeshTokens.of(context).spacingMd),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _hostController,
                            decoration: InputDecoration(
                              labelText: context.l10n.tcpHostLabel,
                              hintText: context.l10n.tcpHostHint,
                            ),
                            enabled: !isConnecting,
                            keyboardType: TextInputType.url,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            context.l10n.tcpPortLabel,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: 4),
                          _PortStepper(
                            controller: _portController,
                            buttonBorder: buttonBorder,
                            enabled: !isConnecting,
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            key: const Key('tcp_connect_button'),
                            onPressed: isButtonDisabled
                                ? null
                                : () {
                                    HapticFeedback.lightImpact();
                                    _connectTcp();
                                  },
                            icon: isConnecting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.lan),
                            label: Text(
                              isConnecting
                                  ? context.l10n.scanner_connecting
                                  : context.l10n.common_connect,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Last used endpoint
                    if (connector.activeTcpEndpoint != null &&
                        connector.isTcpTransportConnected) ...[
                      const SectionHeader('CONNECTED TO'),
                      MeshCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.lan,
                              size: 16,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                connector.activeTcpEndpoint!,
                                style: MeshTokens.of(context).monoBody(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatusChip(BuildContext context, MeshCoreConnector connector) {
    final l10n = context.l10n;

    if (connector.isTcpTransportConnected) {
      return StatusChip(
        label: l10n.scanner_connectedTo(connector.activeTcpEndpoint ?? 'TCP'),
        color: MeshTokens.of(context).signal,
      );
    } else if (connector.state == MeshCoreConnectionState.connecting &&
        connector.activeTransport == MeshCoreTransportType.tcp) {
      return StatusChip(
        label: l10n.tcpStatus_connectingTo(
          '${_hostController.text}:${_portController.text}',
        ),
        color: MeshTokens.of(context).warn,
        pulse: true,
      );
    } else if (connector.state == MeshCoreConnectionState.disconnecting &&
        connector.activeTransport == MeshCoreTransportType.tcp) {
      return StatusChip(
        label: l10n.scanner_disconnecting,
        color: MeshTokens.of(context).warn,
        pulse: true,
      );
    } else {
      return StatusChip(
        label: l10n.tcpStatus_notConnected,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      );
    }
  }

  Future<void> _connectTcp() async {
    if (_connector.state == MeshCoreConnectionState.connecting ||
        _connector.state == MeshCoreConnectionState.connected ||
        _connector.state == MeshCoreConnectionState.disconnecting) {
      return;
    }

    final host = _hostController.text.trim();
    final parsedPort = int.tryParse(_portController.text.trim());
    if (host.isEmpty) {
      _showError(context.l10n.tcpErrorHostRequired);
      return;
    }
    if (parsedPort == null || parsedPort < 1 || parsedPort > 65535) {
      _showError(context.l10n.tcpErrorPortInvalid);
      return;
    }

    try {
      await _connector.connectTcp(host: host, port: parsedPort);
    } catch (error) {
      if (!mounted) return;
      _showError(_friendlyErrorMessage(error));
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    showDismissibleSnackBar(
      context,
      content: Text(message),
      backgroundColor: Theme.of(context).colorScheme.error,
    );
  }

  String _friendlyErrorMessage(Object error) {
    if (error is UnsupportedError) {
      return context.l10n.tcpErrorUnsupported;
    }
    if (error is TimeoutException) {
      return context.l10n.tcpErrorTimedOut;
    }
    if (error is StateError) {
      return context.l10n.tcpConnectionFailed(error.message);
    }
    if (error is ArgumentError) {
      return context.l10n.tcpConnectionFailed(
        error.message?.toString() ?? error.toString(),
      );
    }
    return context.l10n.tcpConnectionFailed(error.toString());
  }
}

/// Numeric port stepper (2026-08-29 redesign) — steals the button-family
/// circle chrome from `SettingsValueStepper`/`_BorderStyleStepper`
/// (`settings_value_stepper.dart`, `custom_style_editor_screen.dart`), but
/// is NOT built on either: those cycle a fixed `List<T>` of choices, which
/// doesn't fit an arbitrary TCP port (1-65535) — the +/- buttons here do
/// real arithmetic on an editable, still-directly-typable field instead of
/// cycling a closed set.
class _PortStepper extends StatelessWidget {
  const _PortStepper({
    required this.controller,
    required this.buttonBorder,
    required this.enabled,
  });

  final TextEditingController controller;

  /// Current app-wide `buttonBorder` ('none'/'solid'/'dotted', null ==
  /// 'none') — same source as every other button-family member, read by
  /// the caller via `activeProfileOverrides.buttonBorder`.
  final String? buttonBorder;
  final bool enabled;

  static const int _minPort = 1;
  static const int _maxPort = 65535;

  void _step(int direction) {
    final current = int.tryParse(controller.text.trim()) ?? 0;
    final next = (current + direction).clamp(_minPort, _maxPort);
    controller.text = next.toString();
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
        width: 34,
        height: 34,
        child: DecoratedBox(
          decoration: ShapeDecoration(
            shape: circleShape,
            color: scheme.primary.withValues(alpha: 0.2),
          ),
          child: IconButton(
            padding: EdgeInsets.zero,
            iconSize: 16,
            color: scheme.primary,
            icon: Icon(icon),
            onPressed: enabled ? onPressed : null,
          ),
        ),
      );
    }

    return Row(
      children: [
        circleButton(Icons.remove, () => _step(-1)),
        SizedBox(width: t.spacingXxs),
        Expanded(
          child: TextField(
            controller: controller,
            enabled: enabled,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: t.monoBody(color: scheme.onSurface),
            decoration: InputDecoration(
              hintText: context.l10n.tcpPortHint,
              filled: true,
              fillColor: scheme.primary.withValues(alpha: 0.2),
              contentPadding: EdgeInsets.symmetric(
                horizontal: t.spacingSm,
                vertical: t.spacingSm,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(t.sm),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(t.sm),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(t.sm),
                borderSide: BorderSide(color: scheme.primary, width: 1.5),
              ),
            ),
          ),
        ),
        SizedBox(width: t.spacingXxs),
        circleButton(Icons.add, () => _step(1)),
      ],
    );
  }
}
