import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../connector/meshcore_connector.dart';
import '../connector/repeater_cli/repeater_cli_session.dart';
import '../helpers/snack_bar_builder.dart';
import '../l10n/l10n.dart';
import '../services/usb_serial_service.dart';
import '../storage/prefs_manager.dart';
import '../theme/mesh_tokens.dart';
import '../utils/usb_port_labels.dart';

/// Minimal debug screen for [RepeaterCliSession]: a raw TCP or USB terminal
/// to a repeater's admin CLI, independent of any paired companion
/// connection.
///
/// The USB port picker uses its own, throwaway [UsbSerialService] instance
/// purely for [UsbSerialService.listPorts] — never the one owned by
/// [MeshCoreConnector] (that one may be mid-companion-session). The actual
/// USB connection is opened by [RepeaterCliSession.connectUsb] on yet
/// another instance it creates internally. Before attempting that connect,
/// this screen checks [MeshCoreConnector] for an in-use companion USB
/// connection and refuses locally — see [_connectUsb] for why that check
/// can't live inside [RepeaterCliSession] itself.
class RepeaterDirectConsoleScreen extends StatefulWidget {
  const RepeaterDirectConsoleScreen({super.key});

  @override
  State<RepeaterDirectConsoleScreen> createState() =>
      _RepeaterDirectConsoleScreenState();
}

class _RepeaterDirectConsoleScreenState
    extends State<RepeaterDirectConsoleScreen> {
  static const String _passwordKeyPrefix = 'repeater_direct.';

  final TextEditingController _hostController = TextEditingController();
  final TextEditingController _portController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _commandController = TextEditingController();
  final ScrollController _logScrollController = ScrollController();
  final List<String> _log = [];

  late final RepeaterCliSession _session;
  late final UsbSerialService _usbPortLister;
  StreamSubscription<String>? _linesSub;
  bool _rememberPassword = false;
  bool _passwordAutoFilled = false;
  RepeaterCliConnectionState _lastObservedState =
      RepeaterCliConnectionState.disconnected;

  List<String> _usbPorts = const [];
  String? _selectedUsbPort;
  bool _isLoadingUsbPorts = false;

  @override
  void initState() {
    super.initState();
    _session = RepeaterCliSession();
    _session.addListener(_handleSessionStateChanged);
    _linesSub = _session.lines.listen(_appendLog);
    _hostController.addListener(_maybeAutoFillPassword);
    _portController.addListener(_maybeAutoFillPassword);
    _usbPortLister = UsbSerialService();
    unawaited(_loadUsbPorts());
  }

  @override
  void dispose() {
    _linesSub?.cancel();
    _session.removeListener(_handleSessionStateChanged);
    _session.dispose();
    _usbPortLister.dispose();
    _hostController.dispose();
    _portController.dispose();
    _passwordController.dispose();
    _commandController.dispose();
    _logScrollController.dispose();
    super.dispose();
  }

  String get _passwordKey =>
      '$_passwordKeyPrefix${_hostController.text.trim()}:${_portController.text.trim()}';

  void _maybeAutoFillPassword() {
    if (_passwordController.text.isNotEmpty && !_passwordAutoFilled) return;
    final host = _hostController.text.trim();
    final port = _portController.text.trim();
    if (host.isEmpty || port.isEmpty) return;
    final saved = PrefsManager.instance.getString(_passwordKey);
    if (saved == null) return;
    _passwordController.text = saved;
    _passwordAutoFilled = true;
    setState(() => _rememberPassword = true);
  }

  void _handleSessionStateChanged() {
    if (!mounted) return;
    final previousState = _lastObservedState;
    final newState = _session.state;
    _lastObservedState = newState;
    setState(() {});

    if (newState == RepeaterCliConnectionState.error &&
        _session.lastError != null) {
      _appendLog('[error] ${_session.lastError}');
    }

    // Only persist the password once the login handshake has actually
    // succeeded — connectTcp()'s future resolves as soon as the raw socket
    // is open, well before the firmware confirms OK/Denied.
    if (previousState != RepeaterCliConnectionState.connected &&
        newState == RepeaterCliConnectionState.connected) {
      final password = _passwordController.text;
      if (_rememberPassword) {
        unawaited(PrefsManager.instance.setString(_passwordKey, password));
      } else {
        unawaited(PrefsManager.instance.remove(_passwordKey));
      }
    }
  }

  void _appendLog(String line) {
    if (!mounted) return;
    setState(() {
      _log.add(line);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_logScrollController.hasClients) return;
      _logScrollController.animateTo(
        _logScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _connect() async {
    final l10n = context.l10n;
    final host = _hostController.text.trim();
    final portText = _portController.text.trim();
    final password = _passwordController.text;

    if (host.isEmpty) {
      _showError(l10n.tcpErrorHostRequired);
      return;
    }
    final port = int.tryParse(portText);
    if (port == null || port < 1 || port > 65535) {
      _showError(l10n.tcpErrorPortInvalid);
      return;
    }

    try {
      await _session.connectTcp(host: host, port: port, password: password);
    } catch (error) {
      if (!mounted) return;
      _showError(l10n.tcpConnectionFailed(error.toString()));
    }
  }

  Future<void> _disconnect() async {
    await _session.disconnect();
  }

  Future<void> _loadUsbPorts() async {
    if (!mounted) return;
    setState(() => _isLoadingUsbPorts = true);
    try {
      final ports = await _usbPortLister.listPorts();
      if (!mounted) return;
      setState(() {
        _usbPorts = ports;
        if (_selectedUsbPort != null && !ports.contains(_selectedUsbPort)) {
          _selectedUsbPort = null;
        }
        _isLoadingUsbPorts = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _usbPorts = const [];
        _selectedUsbPort = null;
        _isLoadingUsbPorts = false;
      });
      _showError(error.toString());
    }
  }

  /// Refuses to open a second, independent USB connection while the
  /// companion [MeshCoreConnector] already holds one. This can't be checked
  /// inside [RepeaterCliSession] itself — it knows nothing about the
  /// companion connector, only its own transport. See the class doc comment
  /// on [RepeaterCliSession] for why a second Android USB handle can't
  /// coexist with the companion bridge regardless of port name.
  Future<void> _connectUsb() async {
    final connector = context.read<MeshCoreConnector>();
    final port = _selectedUsbPort;
    if (port == null) return;

    if (isUsbBlockedByCompanion(connector)) {
      _showError(
        'USB port in use by companion connection — disconnect it first',
      );
      return;
    }

    try {
      await _session.connectUsb(portName: normalizeUsbPortName(port));
    } catch (error) {
      if (!mounted) return;
      _showError(error.toString());
    }
  }

  void _send() {
    final command = _commandController.text.trim();
    if (command.isEmpty) return;
    if (_session.state != RepeaterCliConnectionState.connected) return;
    try {
      _session.send(command);
    } catch (error) {
      _showError(error.toString());
    }
    _commandController.clear();
  }

  void _showError(String message) {
    if (!mounted) return;
    showDismissibleSnackBar(
      context,
      content: Text(message),
      backgroundColor: Theme.of(context).colorScheme.error,
    );
  }

  bool get _isBusy =>
      _session.state == RepeaterCliConnectionState.connecting ||
      _session.state == RepeaterCliConnectionState.authenticating;
  bool get _isConnected =>
      _session.state == RepeaterCliConnectionState.connected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(l10n.repeaterHub_directConsole),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                MeshTokens.of(context).spacingMd,
                MeshTokens.of(context).spacingSm,
                MeshTokens.of(context).spacingMd,
                MeshTokens.of(context).spacingXs,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _hostController,
                          enabled: !_isBusy && !_isConnected,
                          decoration: InputDecoration(
                            labelText: l10n.tcpHostLabel,
                            hintText: l10n.tcpHostHint,
                            isDense: true,
                          ),
                          keyboardType: TextInputType.url,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 1,
                        child: TextField(
                          controller: _portController,
                          enabled: !_isBusy && !_isConnected,
                          decoration: InputDecoration(
                            labelText: l10n.tcpPortLabel,
                            hintText: l10n.tcpPortHint,
                            isDense: true,
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _passwordController,
                    enabled: !_isBusy && !_isConnected,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: l10n.repeaterDirectConsole_password,
                      isDense: true,
                    ),
                    onChanged: (_) => _passwordAutoFilled = false,
                  ),
                  CheckboxListTile(
                    value: _rememberPassword,
                    onChanged: (_isBusy || _isConnected)
                        ? null
                        : (value) => setState(
                            () => _rememberPassword = value ?? false,
                          ),
                    title: Text(l10n.repeaterDirectConsole_rememberPassword),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                  FilledButton.icon(
                    onPressed: _isBusy
                        ? null
                        : () {
                            HapticFeedback.lightImpact();
                            if (_isConnected) {
                              unawaited(_disconnect());
                            } else {
                              unawaited(_connect());
                            }
                          },
                    icon: _isBusy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(_isConnected ? Icons.link_off : Icons.lan),
                    label: Text(
                      _isConnected
                          ? l10n.common_disconnect
                          : l10n.common_connect,
                    ),
                  ),
                  const Divider(height: 24),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedUsbPort,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: l10n.usbScreenStatus,
                            isDense: true,
                          ),
                          items: _usbPorts
                              .map(
                                (port) => DropdownMenuItem(
                                  value: port,
                                  child: Text(
                                    friendlyUsbPortName(port),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (!_isBusy && !_isConnected)
                              ? (value) =>
                                    setState(() => _selectedUsbPort = value)
                              : null,
                          hint: Text(
                            _usbPorts.isEmpty
                                ? l10n.usbScreenEmptyState
                                : l10n.usbScreenStatus,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: l10n.scanner_scan,
                        onPressed: (_isBusy || _isLoadingUsbPorts)
                            ? null
                            : () => unawaited(_loadUsbPorts()),
                        icon: _isLoadingUsbPorts
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed:
                        (_isBusy || _isConnected || _selectedUsbPort == null)
                        ? null
                        : () {
                            HapticFeedback.lightImpact();
                            unawaited(_connectUsb());
                          },
                    icon: const Icon(Icons.usb),
                    label: Text(l10n.common_connect),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _log.isEmpty
                  ? Center(
                      child: Text(
                        l10n.repeaterDirectConsole_emptyLog,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _logScrollController,
                      padding: EdgeInsets.all(MeshTokens.of(context).spacingSm),
                      itemCount: _log.length,
                      itemBuilder: (context, index) => SelectableText(
                        _log[index],
                        style: MeshTokens.of(context).monoBody(),
                      ),
                    ),
            ),
            const Divider(height: 1),
            Padding(
              padding: EdgeInsets.all(MeshTokens.of(context).spacingSm),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commandController,
                      enabled: _isConnected,
                      decoration: InputDecoration(
                        hintText: l10n.repeater_enterCommandHint,
                        isDense: true,
                        border: const OutlineInputBorder(),
                      ),
                      style: const TextStyle(fontFamily: 'monospace'),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _isConnected ? _send : null,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
