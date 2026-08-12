import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../services/usb_serial_service.dart';
import '../meshcore_connector.dart';

/// Lifecycle states for a [RepeaterCliSession].
enum RepeaterCliConnectionState {
  disconnected,
  connecting,
  authenticating,
  connected,
  error,
}

/// Whether a companion [MeshCoreConnector] connection currently blocks a
/// [RepeaterCliSession.connectUsb] attempt.
///
/// Callers (the direct-console screen) MUST check this before calling
/// [RepeaterCliSession.connectUsb] — the session itself has no reference to
/// [MeshCoreConnector] and cannot check it (see the class doc comment for
/// why the two are deliberately decoupled). True whenever the connector's
/// active transport is USB and its state is anything other than
/// disconnected — connecting/connected/disconnecting all count, because the
/// Android native USB host bridge is a process-wide singleton regardless of
/// the exact lifecycle phase or which port it's using (see the class doc
/// comment for the full explanation).
bool isUsbBlockedByCompanion(MeshCoreConnector connector) {
  return connector.activeTransport == MeshCoreTransportType.usb &&
      connector.state != MeshCoreConnectionState.disconnected;
}

/// Raw, unauthenticated debug session to a repeater's admin CLI over TCP.
///
/// This talks to the custom firmware's text-based CLI server
/// (`NetServices.cpp`, `TCP_CLI_PORT` 5000) directly — completely separate
/// from the companion BLE/USB/TCP frame protocol used by
/// [MeshCoreConnector]. The wire protocol is telnet-like:
///
/// 1. Server sends `"Password: "` (no trailing newline).
/// 2. Client sends the password followed by `\n`.
/// 3. Server replies `"OK\r\n> "` (success) or `"Denied\r\n"` (failure, then
///    disconnects).
/// 4. Once authenticated, every command line is answered with response
///    lines prefixed `"  -> "`, followed by a bare `"> "` prompt (again, no
///    trailing newline).
///
/// The parser is intentionally defensive (no firmware changes possible): it
/// tolerates the prompt fragments arriving with no terminating newline by
/// stripping a leading `"> "` before every line-split attempt, and skips
/// empty lines produced by bare `\r\n` framing noise.
///
/// USB transport (`connectUsb`) talks to the SAME firmware CLI, but on
/// 115200-baud serial instead of TCP port 5000 — and WITHOUT the password
/// phase (USB access is already gated by OS/user-level serial permissions,
/// there is no `Password:`/`OK`/`Denied` exchange; the session goes straight
/// to `connected`). It opens its own, independent `UsbSerialService`
/// (`lib/services/usb_serial_service.dart`, the platform shim — native or
/// Web Serial depending on target) — a plain class, not a singleton — and
/// reads its `rawByteStream`, which publishes bytes BEFORE
/// COBS decoding, alongside (not instead of) the existing `frameStream` used
/// by the companion frame protocol. Real, independent limitation on Android:
/// the native USB host bridge (`android/.../MeshcoreUsbFunctions.kt`) keeps
/// its state in un-keyed instance fields (one `usbConnection`/`eventSink`/
/// `readThread`), so it cannot host this session's connection alongside
/// whatever the companion `MeshCoreConnector` already has open — any active
/// companion USB connection must be disconnected first (enforced by the
/// caller UI, not this class, since it needs `MeshCoreConnector` state).
class RepeaterCliSession extends ChangeNotifier {
  RepeaterCliSession({Duration keepAliveInterval = const Duration(seconds: 60)})
    : _keepAliveInterval = keepAliveInterval;

  final Duration _keepAliveInterval;

  RepeaterCliConnectionState _state = RepeaterCliConnectionState.disconnected;
  RepeaterCliConnectionState get state => _state;

  String? _lastError;
  String? get lastError => _lastError;

  final StreamController<String> _linesController =
      StreamController<String>.broadcast();
  Stream<String> get lines => _linesController.stream;

  Socket? _socket;
  StreamSubscription<Uint8List>? _subscription;
  UsbSerialService? _usbService;
  StreamSubscription<Uint8List>? _usbSubscription;
  Timer? _keepAliveTimer;
  DateTime _lastActivity = DateTime.now();
  String _buffer = '';
  bool _passwordSent = false;
  String? _pendingPassword;
  bool _manualTeardown = false;

  bool get isConnected => _state == RepeaterCliConnectionState.connected;

  /// Connects to a repeater's raw CLI over TCP and performs the
  /// password handshake described in the class doc comment.
  Future<void> connectTcp({
    required String host,
    required int port,
    required String password,
  }) async {
    if (_state == RepeaterCliConnectionState.connecting ||
        _state == RepeaterCliConnectionState.authenticating ||
        _state == RepeaterCliConnectionState.connected) {
      throw StateError('RepeaterCliSession is already active');
    }

    _manualTeardown = false;
    _buffer = '';
    _passwordSent = false;
    _pendingPassword = password;
    _updateState(RepeaterCliConnectionState.connecting);

    try {
      final socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(seconds: 10),
      );
      _socket = socket;
      _lastActivity = DateTime.now();
      _updateState(RepeaterCliConnectionState.authenticating);
      _subscription = socket.listen(
        _handleData,
        onError: _handleSocketError,
        onDone: _handleSocketDone,
        cancelOnError: false,
      );
      _startKeepAliveTimer();
    } catch (error) {
      _socket = null;
      _updateState(
        RepeaterCliConnectionState.error,
        error: 'TCP connect failed: $error',
      );
      rethrow;
    }
  }

  /// Connects to a repeater's raw CLI over USB serial. Same firmware CLI as
  /// [connectTcp], no password phase (see the class doc comment) — the
  /// session goes straight to `connected` once the port opens.
  ///
  /// Callers MUST check for an in-use companion USB connection before
  /// calling this (see the class doc comment) — this method has no access
  /// to `MeshCoreConnector` state and will happily attempt to open a port
  /// the companion already holds, which fails loudly rather than silently.
  Future<void> connectUsb({
    required String portName,
    int baudRate = 115200,
  }) async {
    if (_state == RepeaterCliConnectionState.connecting ||
        _state == RepeaterCliConnectionState.authenticating ||
        _state == RepeaterCliConnectionState.connected) {
      throw StateError('RepeaterCliSession is already active');
    }

    _manualTeardown = false;
    _buffer = '';
    _updateState(RepeaterCliConnectionState.connecting);

    final usbService = UsbSerialService();
    try {
      await usbService.connect(portName: portName, baudRate: baudRate);
    } catch (error) {
      usbService.dispose();
      _updateState(
        RepeaterCliConnectionState.error,
        error: 'USB connect failed: $error',
      );
      rethrow;
    }

    _usbService = usbService;
    _lastActivity = DateTime.now();
    _usbSubscription = usbService.rawByteStream.listen(
      _handleData,
      onError: _handleSocketError,
      onDone: _handleSocketDone,
      cancelOnError: false,
    );
    _startKeepAliveTimer();
    // No password handshake over USB — the firmware answers directly.
    _updateState(RepeaterCliConnectionState.connected);
  }

  /// Sends [line] to the device (a trailing `\n` is appended) and echoes it
  /// locally into [lines] as `"> <line>"`, mirroring what a real terminal
  /// would show.
  void send(String line) {
    if (_state != RepeaterCliConnectionState.connected) {
      throw StateError('RepeaterCliSession is not connected');
    }
    _writeRaw('$line\n');
    _emitLine('> $line');
  }

  Future<void> disconnect() async {
    await _teardown(closeSocket: true);
    _updateState(RepeaterCliConnectionState.disconnected, error: null);
  }

  @override
  void dispose() {
    unawaited(_teardown(closeSocket: true));
    if (!_linesController.isClosed) {
      unawaited(_linesController.close());
    }
    super.dispose();
  }

  // --- Wire protocol -------------------------------------------------

  void _handleData(Uint8List chunk) {
    _lastActivity = DateTime.now();
    _buffer += utf8.decode(chunk, allowMalformed: true);
    switch (_state) {
      case RepeaterCliConnectionState.authenticating:
        _processAuthBuffer();
        break;
      case RepeaterCliConnectionState.connected:
        _processConnectedBuffer();
        break;
      case RepeaterCliConnectionState.connecting:
      case RepeaterCliConnectionState.disconnected:
      case RepeaterCliConnectionState.error:
        // Defensive: data arriving outside the expected lifecycle is
        // ignored rather than crashing the session.
        break;
    }
  }

  void _processAuthBuffer() {
    if (!_passwordSent) {
      final promptIndex = _buffer.indexOf('Password:');
      if (promptIndex == -1) return; // wait for more data
      var consumeEnd = promptIndex + 'Password:'.length;
      if (consumeEnd < _buffer.length && _buffer[consumeEnd] == ' ') {
        consumeEnd += 1;
      }
      _buffer = _buffer.substring(consumeEnd);
      _passwordSent = true;
      _writeRaw('${_pendingPassword ?? ''}\n');
    }

    // Defensive: tolerate leading CR/LF noise before the OK/Denied reply.
    _buffer = _buffer.replaceFirst(RegExp(r'^[\r\n]+'), '');

    if (_buffer.startsWith('Denied')) {
      unawaited(
        _teardown(closeSocket: true).then((_) {
          _updateState(RepeaterCliConnectionState.error, error: 'bad password');
        }),
      );
      return;
    }

    if (_buffer.startsWith('OK')) {
      _buffer = _buffer.substring(2);
      _updateState(RepeaterCliConnectionState.connected);
      _processConnectedBuffer();
      return;
    }
    // Not enough data yet to decide — wait for the next chunk.
  }

  void _processConnectedBuffer() {
    while (true) {
      if (_buffer.startsWith('> ')) {
        _buffer = _buffer.substring(2);
        continue;
      }
      if (_buffer == '>') {
        // Ambiguous partial prompt fragment — wait for the rest.
        break;
      }
      final newlineIndex = _buffer.indexOf('\n');
      if (newlineIndex == -1) break;
      var line = _buffer.substring(0, newlineIndex);
      _buffer = _buffer.substring(newlineIndex + 1);
      if (line.endsWith('\r')) {
        line = line.substring(0, line.length - 1);
      }
      _emitLine(line);
    }
  }

  void _emitLine(String line) {
    if (line.isEmpty) return;
    if (_linesController.isClosed) return;
    _linesController.add(line);
  }

  void _writeRaw(String data) {
    final bytes = utf8.encode(data);
    final socket = _socket;
    if (socket != null) {
      socket.add(bytes);
      _lastActivity = DateTime.now();
      return;
    }
    final usbService = _usbService;
    if (usbService != null) {
      _lastActivity = DateTime.now();
      unawaited(
        usbService
            .writeRaw(Uint8List.fromList(bytes))
            .catchError(_handleSocketError),
      );
    }
  }

  // --- Keep-alive ------------------------------------------------------

  void _startKeepAliveTimer() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = Timer.periodic(_keepAliveInterval, (_) {
      if (_socket == null && _usbService == null) return;
      final idleFor = DateTime.now().difference(_lastActivity);
      if (idleFor >= _keepAliveInterval) {
        // Firmware ignores an empty line; sending one just resets its idle
        // timeout without being interpreted as a command. USB has no idle
        // timeout of its own, but keeping this unconditional is cheaper than
        // a platform/transport branch and it's harmless over USB.
        _writeRaw('\n');
      }
    });
  }

  // --- Teardown / error handling ---------------------------------------

  void _handleSocketError(Object error, [StackTrace? stackTrace]) {
    unawaited(
      _teardown(closeSocket: true).then((_) {
        _updateState(RepeaterCliConnectionState.error, error: error.toString());
      }),
    );
  }

  void _handleSocketDone() {
    if (_manualTeardown) return;
    unawaited(
      _teardown(closeSocket: false).then((_) {
        _updateState(
          RepeaterCliConnectionState.error,
          error:
              'connection closed by device (possibly replaced by another client)',
        );
      }),
    );
  }

  Future<void> _teardown({required bool closeSocket}) async {
    _manualTeardown = true;
    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;
    final subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();
    final socket = _socket;
    _socket = null;
    if (closeSocket && socket != null) {
      try {
        await socket.close();
      } catch (_) {
        // Best-effort — the socket may already be gone.
      }
    }
    final usbSubscription = _usbSubscription;
    _usbSubscription = null;
    await usbSubscription?.cancel();
    final usbService = _usbService;
    _usbService = null;
    // Unlike the raw Socket above, UsbSerialService.dispose() is safe to call
    // unconditionally (idempotent internal disconnect guard) — no need to
    // branch on closeSocket here.
    usbService?.dispose();
  }

  void _updateState(RepeaterCliConnectionState newState, {Object? error}) {
    _state = newState;
    _lastError = error?.toString();
    notifyListeners();
  }
}
