import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:meshcore_open/connector/meshcore_connector.dart';
import 'package:meshcore_open/connector/repeater_cli/repeater_cli_session.dart';

/// Minimal controllable fake for [isUsbBlockedByCompanion] — overrides only
/// the two getters the check reads, following the same pattern as
/// `test/screens/usb_flow_test.dart`'s `_FakeMeshCoreConnector` (a real
/// `MeshCoreConnector()` talks to BLE/native channels we don't want alive in
/// a unit test).
class _FakeConnector extends MeshCoreConnector {
  _FakeConnector({required this.state, required this.activeTransport});

  @override
  final MeshCoreConnectionState state;

  @override
  final MeshCoreTransportType activeTransport;
}

/// Minimal fake implementation of the firmware's TCP CLI protocol
/// (`NetServices.cpp`, `TCP_CLI_PORT`): sends `"Password: "`, checks the
/// client's password line, then answers subsequent command lines with
/// canned responses (defaulting to a generic `"  -> ok\r\n"`).
class _FakeCliServer {
  _FakeCliServer(
    this.server, {
    required this.expectedPassword,
    this.responses = const {},
  });

  final ServerSocket server;
  final String expectedPassword;
  final Map<String, String> responses;

  final List<String> receivedCommands = [];
  Socket? _client;
  String _buffer = '';
  bool _authenticated = false;
  StreamSubscription<Socket>? _acceptSub;
  StreamSubscription<List<int>>? _dataSub;
  final Completer<void> _clientConnected = Completer<void>();

  void start() {
    _acceptSub = server.listen((socket) {
      _client = socket;
      socket.write('Password: ');
      _dataSub = socket.listen(_handleData);
      if (!_clientConnected.isCompleted) {
        _clientConnected.complete();
      }
    });
  }

  Future<void> get clientConnected => _clientConnected.future;

  void _handleData(List<int> chunk) {
    _buffer += utf8.decode(chunk);
    if (!_authenticated) {
      final newlineIndex = _buffer.indexOf('\n');
      if (newlineIndex == -1) return;
      final passwordLine = _buffer
          .substring(0, newlineIndex)
          .replaceAll('\r', '');
      _buffer = _buffer.substring(newlineIndex + 1);
      if (passwordLine == expectedPassword) {
        _authenticated = true;
        _client?.write('OK\r\n> ');
      } else {
        _client?.write('Denied\r\n');
        unawaited(_client?.close());
      }
      return;
    }
    while (true) {
      final newlineIndex = _buffer.indexOf('\n');
      if (newlineIndex == -1) break;
      final command = _buffer.substring(0, newlineIndex).replaceAll('\r', '');
      _buffer = _buffer.substring(newlineIndex + 1);
      receivedCommands.add(command);
      if (command.isEmpty) continue; // keep-alive ping — firmware ignores it
      final response = responses[command] ?? '  -> ok\r\n';
      _client?.write('$response> ');
    }
  }

  Future<void> close() async {
    await _dataSub?.cancel();
    await _acceptSub?.cancel();
    await _client?.close();
  }
}

Future<void> _waitFor(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 2),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Condition not met within $timeout');
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  group('RepeaterCliSession TCP', () {
    test('happy path: authenticates and matches command to response', () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final fakeServer = _FakeCliServer(
        server,
        expectedPassword: 'secret',
        responses: {'ver': '  -> v1.17.0\r\n'},
      )..start();
      final session = RepeaterCliSession();
      final lines = <String>[];
      final linesSub = session.lines.listen(lines.add);

      try {
        await session.connectTcp(
          host: InternetAddress.loopbackIPv4.address,
          port: server.port,
          password: 'secret',
        );
        await fakeServer.clientConnected;
        await _waitFor(
          () => session.state == RepeaterCliConnectionState.connected,
        );

        session.send('ver');
        await _waitFor(() => lines.contains('  -> v1.17.0'));

        expect(session.state, RepeaterCliConnectionState.connected);
        expect(lines, contains('> ver'));
        expect(lines, contains('  -> v1.17.0'));
      } finally {
        await linesSub.cancel();
        await session.disconnect();
        await fakeServer.close();
        await server.close();
      }
    });

    test(
      'wrong password: state becomes error(bad password), socket closed',
      () async {
        final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
        final fakeServer = _FakeCliServer(server, expectedPassword: 'secret')
          ..start();
        final session = RepeaterCliSession();

        try {
          await session.connectTcp(
            host: InternetAddress.loopbackIPv4.address,
            port: server.port,
            password: 'wrong',
          );
          await _waitFor(
            () => session.state == RepeaterCliConnectionState.error,
          );

          expect(session.state, RepeaterCliConnectionState.error);
          expect(session.lastError, 'bad password');
        } finally {
          await session.disconnect();
          await fakeServer.close();
          await server.close();
        }
      },
    );

    test('server-initiated disconnect surfaces a kick/closed error', () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final fakeServer = _FakeCliServer(server, expectedPassword: 'secret')
        ..start();
      final session = RepeaterCliSession();

      try {
        await session.connectTcp(
          host: InternetAddress.loopbackIPv4.address,
          port: server.port,
          password: 'secret',
        );
        await _waitFor(
          () => session.state == RepeaterCliConnectionState.connected,
        );

        // Simulate the device kicking us (e.g. replaced by another client).
        await fakeServer.close();

        await _waitFor(() => session.state == RepeaterCliConnectionState.error);
        expect(session.lastError, contains('closed by device'));
      } finally {
        await session.disconnect();
        await server.close();
      }
    });

    test('keep-alive sends an empty line after the idle interval', () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final fakeServer = _FakeCliServer(server, expectedPassword: 'secret')
        ..start();
      final session = RepeaterCliSession(
        keepAliveInterval: const Duration(milliseconds: 50),
      );

      try {
        await session.connectTcp(
          host: InternetAddress.loopbackIPv4.address,
          port: server.port,
          password: 'secret',
        );
        await _waitFor(
          () => session.state == RepeaterCliConnectionState.connected,
        );

        await _waitFor(
          () => fakeServer.receivedCommands.contains(''),
          timeout: const Duration(seconds: 2),
        );
        expect(fakeServer.receivedCommands, contains(''));
      } finally {
        await session.disconnect();
        await fakeServer.close();
        await server.close();
      }
    });

    test('send() echoes the command locally as "> <line>"', () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final fakeServer = _FakeCliServer(server, expectedPassword: 'secret')
        ..start();
      final session = RepeaterCliSession();
      final lines = <String>[];
      final linesSub = session.lines.listen(lines.add);

      try {
        await session.connectTcp(
          host: InternetAddress.loopbackIPv4.address,
          port: server.port,
          password: 'secret',
        );
        await _waitFor(
          () => session.state == RepeaterCliConnectionState.connected,
        );

        session.send('ver');
        await _waitFor(() => lines.contains('> ver'));

        expect(lines, contains('> ver'));
      } finally {
        await linesSub.cancel();
        await session.disconnect();
        await fakeServer.close();
        await server.close();
      }
    });
  });

  group('RepeaterCliSession USB', () {
    // connectUsb()'s happy path is NOT unit-tested here: UsbSerialService is
    // a concrete class with no test seam (Android goes through a real
    // MethodChannel to native Kotlin, desktop opens a real OS serial device
    // node via flutter_libserialport's SerialPort) — there is no fake
    // implementation to inject without adding an interface purely for this
    // test, which the task explicitly says not to do. The line-parsing
    // logic connectUsb() drives (_handleData/_processConnectedBuffer) is
    // NOT USB-specific code, though: connectUsb() wires the exact same
    // private handlers TCP already uses (see repeater_cli_session.dart),
    // so the "RepeaterCliSession TCP" group above already exercises it
    // byte-for-byte. What's USB-specific and IS covered here is the
    // conflict check below. The happy path (real port open, straight to
    // `connected` with no password phase) is verified manually on a Pixel
    // — see this task's `## RAPORT WYKONANIA`.

    test('isUsbBlockedByCompanion refuses while companion holds USB', () {
      final connected = _FakeConnector(
        state: MeshCoreConnectionState.connected,
        activeTransport: MeshCoreTransportType.usb,
      );
      expect(isUsbBlockedByCompanion(connected), isTrue);

      final connecting = _FakeConnector(
        state: MeshCoreConnectionState.connecting,
        activeTransport: MeshCoreTransportType.usb,
      );
      expect(
        isUsbBlockedByCompanion(connecting),
        isTrue,
        reason:
            'the Android bridge is a singleton regardless of exact '
            'lifecycle phase, not just "connected"',
      );
    });

    test(
      'isUsbBlockedByCompanion allows connecting when companion is idle or on another transport',
      () {
        final disconnected = _FakeConnector(
          state: MeshCoreConnectionState.disconnected,
          activeTransport: MeshCoreTransportType.usb,
        );
        expect(isUsbBlockedByCompanion(disconnected), isFalse);

        final bluetoothConnected = _FakeConnector(
          state: MeshCoreConnectionState.connected,
          activeTransport: MeshCoreTransportType.bluetooth,
        );
        expect(isUsbBlockedByCompanion(bluetoothConnected), isFalse);

        final tcpConnected = _FakeConnector(
          state: MeshCoreConnectionState.connected,
          activeTransport: MeshCoreTransportType.tcp,
        );
        expect(isUsbBlockedByCompanion(tcpConnected), isFalse);
      },
    );
  });
}
