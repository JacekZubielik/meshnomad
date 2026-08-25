import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';

import 'app_debug_log_service.dart';
import '../utils/macos_usb_device_names.dart';
import '../utils/platform_info.dart';
import '../utils/usb_port_labels.dart';
import 'usb_serial_frame_codec.dart';

/// Wraps the native flutter_libserialport plugin to expose a stream of raw
/// bytes for the MeshCore connector to consume.
class UsbSerialService {
  UsbSerialService();

  static const MethodChannel _androidMethodChannel = MethodChannel(
    'meshcore_open/android_usb_serial',
  );
  static const EventChannel _androidEventChannel = EventChannel(
    'meshcore_open/android_usb_serial_events',
  );
  final StreamController<Uint8List> _frameController =
      StreamController<Uint8List>.broadcast();
  final StreamController<Uint8List> _rawByteController =
      StreamController<Uint8List>.broadcast();
  final UsbSerialFrameDecoder _frameDecoder = UsbSerialFrameDecoder();
  StreamSubscription<dynamic>? _androidDataSubscription;
  StreamSubscription<Uint8List>? _dataSubscription;
  SerialPortReader? _reader;
  UsbSerialStatus _status = UsbSerialStatus.disconnected;
  String? _connectedPortKey;
  String? _connectedPortLabel;
  SerialPort? _serial;
  bool _lastDtr = true;
  bool _lastRts = false;
  AppDebugLogService? _debugLogService;
  Object? _lastError;

  UsbSerialStatus get status => _status;
  String? get activePortKey => _connectedPortKey;
  String? get activePortDisplayLabel =>
      _connectedPortLabel ?? _connectedPortKey;
  Stream<Uint8List> get frameStream => _frameController.stream;
  Stream<Uint8List> get rawByteStream => _rawByteController.stream;
  Object? get lastError => _lastError;
  bool get _useAndroidUsbHost =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  bool get _useDesktopSerialPort =>
      PlatformInfo.isWindows || PlatformInfo.isLinux || PlatformInfo.isMacOS;
  bool get _isSupportedPlatform => _useAndroidUsbHost || _useDesktopSerialPort;

  bool get isConnected {
    if (!_isSupportedPlatform) {
      return false;
    }
    // Trust _status as the authoritative connection state. Actual port
    // drops are handled by the onDone / onError callbacks on the serial
    // data stream subscription, which update _status correctly.
    return _status == UsbSerialStatus.connected;
  }

  Future<List<String>> listPorts() async {
    if (!_isSupportedPlatform) {
      return const <String>[];
    }
    if (_useAndroidUsbHost) {
      final ports = await _androidMethodChannel.invokeListMethod<String>(
        'listPorts',
      );
      return ports ?? <String>[];
    }
    final rawPorts = _describeAvailablePorts();
    // The previous native serial transport's device-name lookup used to be
    // broken on macOS 10.15+ because the IOKit class name changed from
    // IOUSBDevice to IOUSBHostDevice. flutter_libserialport reads the port
    // description straight from libserialport, so this workaround is likely
    // dead code now — left in place pending verification on real macOS
    // hardware.
    if (Platform.isMacOS && rawPorts.isNotEmpty) {
      return _annotateMacOsPorts(rawPorts);
    }
    return Future.value(rawPorts);
  }

  /// Builds the same `"<port> - <description> - <hardware_id>"` label format
  /// the previous native serial transport used to return, so
  /// [usb_port_labels.dart] and the USB screen stay unchanged after the
  /// transport migration.
  List<String> _describeAvailablePorts() {
    return SerialPort.availablePorts.map((address) {
      final port = SerialPort(address);
      try {
        final description =
            _nonEmpty(port.description) ?? _nonEmpty(port.productName) ?? 'n/a';
        final hardwareId = _usbHardwareId(port) ?? 'n/a';
        return '$address - $description - $hardwareId';
      } finally {
        port.dispose();
      }
    }).toList();
  }

  String? _usbHardwareId(SerialPort port) {
    final vendorId = port.vendorId;
    final productId = port.productId;
    if (vendorId == null || productId == null) {
      return null;
    }
    final vendorHex = vendorId.toRadixString(16).padLeft(4, '0');
    final productHex = productId.toRadixString(16).padLeft(4, '0');
    return 'USB VID:PID=$vendorHex:$productHex';
  }

  String? _nonEmpty(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  /// Rewrites the port list on macOS by substituting real USB device names
  /// (obtained via [ioreg]) for the "n/a" placeholders left by the fallback
  /// IOKit lookup when it can't find the deprecated IOUSBDevice parent.
  Future<List<String>> _annotateMacOsPorts(List<String> rawPorts) async {
    final deviceNames = await queryMacOsUsbDeviceNames();
    if (deviceNames.isEmpty) return rawPorts;
    return rawPorts.map((entry) {
      // entry format from fl_ports: "port - description - hardware_id"
      final port = normalizeUsbPortName(entry); // e.g. /dev/cu.usbmodem1101
      final knownName = deviceNames[port]; // e.g. "Nordic NRF52 DK"
      if (knownName == null) return entry; // non-USB port, keep as-is
      // Replace description field only; preserve hardware_id for device
      // identity (used by normalizeUsbPortName).
      final segments = entry.split(' - ');
      final hardwareId = segments.length >= 3 ? segments.last : 'n/a';
      return '$port - $knownName - $hardwareId';
    }).toList();
  }

  void setDebugLogService(AppDebugLogService? service) {
    _debugLogService = service;
  }

  Future<void> connect({
    required String portName,
    int baudRate = 115200,
  }) async {
    if (_status == UsbSerialStatus.connected ||
        _status == UsbSerialStatus.connecting) {
      throw StateError('USB serial transport is already active');
    }
    if (!_isSupportedPlatform) {
      throw UnsupportedError('USB serial is not supported on this platform.');
    }

    _status = UsbSerialStatus.connecting;
    var normalizedPortName = normalizeUsbPortName(portName);
    _frameDecoder.reset();

    if (_useAndroidUsbHost) {
      try {
        await _androidMethodChannel.invokeMethod<void>('connect', {
          'portName': normalizedPortName,
          'baudRate': baudRate,
        });
        _debugLogService?.info(
          'USB serial opened port=$normalizedPortName on Android via USB host bridge',
          tag: 'USB Serial',
        );
      } on PlatformException catch (error) {
        _status = UsbSerialStatus.disconnected;
        final msg = error.message ?? error.code;
        _debugLogService?.error(
          'Android connect failed: $msg',
          tag: 'USB Serial',
        );
        rethrow;
      }
    } else {
      // On macOS, USB serial devices can enumerate as both cu.* and tty.*
      // device nodes; if the listed one fails to open, try its sibling
      // before giving up.
      final candidates = _buildPortCandidates(normalizedPortName);
      SerialPortError? lastError;
      bool opened = false;

      for (final candidate in candidates) {
        // Declared outside the try block (Dart scopes try-local variables
        // out of reach of its own catch clauses) so every failure path below
        // can dispose a partially-opened port instead of leaking the native
        // handle and locking the device out ("Device or resource busy") for
        // every subsequent attempt.
        SerialPort? serial;
        try {
          serial = SerialPort(candidate);
          if (!serial.openReadWrite()) {
            final msg =
                'Failed to open USB port $candidate: ${SerialPort.lastError}';
            _debugLogService?.error(msg, tag: 'USB Serial');
            _status = UsbSerialStatus.disconnected;
            throw StateError(msg);
          }
          serial.config = SerialPortConfig()
            ..baudRate = baudRate
            ..bits = 8
            ..parity = SerialPortParity.none
            ..stopBits = 1
            ..setFlowControl(SerialPortFlowControl.none)
            ..rts = SerialPortRts.off;
          // Toggle DTR low→high so the device sees a fresh connection even
          // if the previous disconnect didn't cleanly signal DTR drop.
          serial.config = SerialPortConfig()..dtr = SerialPortDtr.off;
          await Future<void>.delayed(const Duration(milliseconds: 50));
          serial.config = SerialPortConfig()..dtr = SerialPortDtr.on;
          _serial = serial;
          // Update the normalized port name to whichever candidate succeeded.
          normalizedPortName = candidate;
          final signals = serial.signals;
          _debugLogService?.info(
            'USB serial opened port=$candidate '
            'cts=${signals & SerialPortSignal.cts != 0} '
            'dsr=${signals & SerialPortSignal.dsr != 0} dtr=true rts=false',
            tag: 'USB Serial',
          );
          opened = true;
          break;
        } on SerialPortError catch (error) {
          _debugLogService?.warn(
            'Failed to open $candidate: $error',
            tag: 'USB Serial',
          );
          lastError = error;
          serial?.dispose();
          // Try next candidate
        } catch (error, stackTrace) {
          if (error is! StateError) {
            _status = UsbSerialStatus.disconnected;
          }
          _debugLogService?.error(
            'Unexpected error opening $candidate: $error\n$stackTrace',
            tag: 'USB Serial',
          );
          serial?.dispose();
          rethrow;
        }
      }

      if (!opened) {
        _status = UsbSerialStatus.disconnected;
        final primary = candidates.first;
        final msg = lastError != null
            ? 'Failed to open USB port $primary: $lastError'
            : 'Failed to open USB port $primary';
        _debugLogService?.error(msg, tag: 'USB Serial');
        throw StateError(msg);
      }
    }

    _connectedPortKey = normalizedPortName;
    _connectedPortLabel = normalizedPortName;
    if (_useAndroidUsbHost) {
      _androidDataSubscription = _androidEventChannel
          .receiveBroadcastStream()
          .listen(
            _handleAndroidData,
            onError: _handleSerialError,
            onDone: _handleSerialDone,
          );
    } else {
      _reader = SerialPortReader(_serial!);
      _dataSubscription = _reader!.stream.listen(
        _handleSerialData,
        onError: _handleSerialError,
        onDone: _handleSerialDone,
      );
    }
    _status = UsbSerialStatus.connected;
  }

  Future<void> writeRaw(Uint8List data) async {
    if (!isConnected) {
      throw StateError('USB serial port is not open');
    }
    if (_useAndroidUsbHost) {
      try {
        await _androidMethodChannel.invokeMethod<void>('write', {'data': data});
      } on PlatformException catch (error) {
        throw StateError(error.message ?? error.code);
      }
    } else {
      try {
        _serial!.write(data, timeout: 1000);
      } on SerialPortError catch (error) {
        final msg = 'USB write failed: $error';
        _debugLogService?.error(msg, tag: 'USB Serial');
        throw StateError(msg);
      }
    }
  }

  Future<void> write(Uint8List data) async {
    if (!isConnected) {
      throw StateError('USB serial port is not open');
    }
    final packet = wrapUsbSerialTxFrame(data);
    // _logFrameSummary('USB TX frame', data);
    if (_useAndroidUsbHost) {
      try {
        await _androidMethodChannel.invokeMethod<void>('write', {
          'data': packet,
        });
      } on PlatformException catch (error) {
        throw StateError(error.message ?? error.code);
      }
    } else {
      try {
        _serial!.write(packet, timeout: 1000);
      } on SerialPortError catch (error) {
        final msg = 'USB write failed: $error';
        _debugLogService?.error(msg, tag: 'USB Serial');
        throw StateError(msg);
      }
    }
  }

  Future<void> disconnect() async {
    if (_status == UsbSerialStatus.disconnected) return;

    final portLabel = _connectedPortLabel ?? _connectedPortKey;
    _debugLogService?.info(
      'USB disconnect starting port=${portLabel ?? 'unknown'}',
      tag: 'USB Serial',
    );
    _status = UsbSerialStatus.disconnecting;
    _connectedPortKey = null;
    _connectedPortLabel = null;
    _frameDecoder.reset();

    if (_useAndroidUsbHost) {
      await _androidDataSubscription?.cancel();
      _androidDataSubscription = null;
      try {
        await _androidMethodChannel.invokeMethod<void>('disconnect');
      } catch (_) {
        // Ignore errors while closing.
      }
    } else {
      // IMPORTANT: Cancel the Dart subscription FIRST, before closing the
      // native port. SerialPortReader reads on a spawned Isolate that holds
      // the port's raw FFI pointer; cancelling the subscription kills that
      // isolate (StreamController.onCancel → SerialPortReader._cancelRead),
      // so the port can then be closed/disposed on the main isolate without
      // a background isolate racing to read from a freed pointer.
      await _dataSubscription?.cancel();
      _dataSubscription = null;
      _reader = null;

      final serial = _serial;
      _serial = null;
      try {
        if (serial != null && serial.isOpen) {
          serial.config = SerialPortConfig()..dtr = SerialPortDtr.off;
          serial.close();
        }
      } catch (_) {
        // Ignore errors while closing.
      } finally {
        serial?.dispose();
      }
    }
    _status = UsbSerialStatus.disconnected;
    _debugLogService?.info(
      'USB disconnect complete port=${portLabel ?? 'unknown'}',
      tag: 'USB Serial',
    );
  }

  void setRequestPortLabel(String label) {
    // Native implementations do not use a synthetic chooser row.
  }

  void setFallbackDeviceName(String label) {
    // Native implementations use OS-provided device names.
  }

  void updateConnectedLabel(String label) {
    final trimmed = label.trim();
    if (trimmed.isEmpty) {
      return;
    }
    _connectedPortLabel = buildUsbDisplayLabel(
      basePortLabel: _connectedPortKey ?? trimmed,
      deviceName: trimmed,
    );
  }

  void dispose() {
    // Synchronously close the native port so it doesn't outlive the Dart
    // isolate (e.g. on hot restart). Unlike the previous native serial
    // transport's raw native thread + FFI callback, SerialPortReader's
    // background work runs on a spawned Dart Isolate that the VM tears down
    // cleanly with the rest of the isolate group on hot restart — this guard
    // is defensive/cheap resource cleanup, not a crash workaround known to
    // be required for flutter_libserialport (verified empirically during
    // the migration gate).
    if (_useDesktopSerialPort) {
      // Null out _serial before disposing it (not just closing) — the later
      // disconnect() call below must not touch this now-freed native pointer.
      final serial = _serial;
      _serial = null;
      try {
        if (serial != null && serial.isOpen) {
          serial.config = SerialPortConfig()..dtr = SerialPortDtr.off;
          serial.close();
        }
      } catch (_) {}
      serial?.dispose();
    }
    // Kick off the full async teardown for anything else (subscription cancel,
    // stream controller close). These are best-effort at dispose time.
    unawaited(disconnect().whenComplete(_closeFrameController));
  }

  void _handleSerialData(Uint8List data) {
    try {
      if (data.isNotEmpty) {
        _ingestRawBytes(data);
      }
    } catch (error, stack) {
      _addFrameError(error, stack);
    }
  }

  void _handleAndroidData(dynamic data) {
    if (data is Uint8List) {
      _ingestRawBytes(data);
      return;
    }
    if (data is ByteData) {
      _ingestRawBytes(data.buffer.asUint8List());
      return;
    }
    _addFrameError(
      StateError('Unexpected Android USB event payload: ${data.runtimeType}'),
    );
  }

  void _handleSerialError(Object error, [StackTrace? stackTrace]) {
    _addFrameError(error, stackTrace);
  }

  void _handleSerialDone() {
    unawaited(disconnect());
  }

  void _ingestRawBytes(Uint8List bytes) {
    if (!_rawByteController.isClosed) _rawByteController.add(bytes);
    for (final packet in _frameDecoder.ingest(bytes)) {
      if (!packet.isRxFrame) {
        _debugLogService?.info(
          'USB ignored packet start=0x${packet.frameStart.toRadixString(16).padLeft(2, '0')} len=${packet.payload.length}',
          tag: 'USB Serial',
        );
        continue;
      }
      _addFrame(packet.payload);
    }
  }

  void _addFrame(Uint8List payload) {
    if (_frameController.isClosed) {
      return;
    }
    _frameController.add(payload);
  }

  void _addFrameError(Object error, [StackTrace? stackTrace]) {
    _lastError = error;
    if (_frameController.isClosed) {
      return;
    }
    _frameController.addError(error, stackTrace);
  }

  Future<void> _closeFrameController() async {
    if (!_frameController.isClosed) {
      await _frameController.close();
    }
    if (!_rawByteController.isClosed) {
      await _rawByteController.close();
    }
  }

  // void _logFrameSummary(String prefix, Uint8List bytes) {
  //   if (bytes.isEmpty) {
  //     _debugLogService?.info('$prefix len=0', tag: 'USB Serial');
  //     return;
  //   }
  //   _debugLogService?.info(
  //     '$prefix code=${bytes[0]} len=${bytes.length}',
  //     tag: 'USB Serial',
  //   );
  // }

  /// Returns an ordered list of port paths to try for [portName].
  ///
  /// On macOS, USB serial devices appear as both `/dev/cu.*` (call-out, the
  /// correct mode for outgoing serial connections) and `/dev/tty.*` (dial-in).
  /// The OS may list one variant while only the other is actually openable
  /// at a given moment. We prefer `cu.*` but automatically include the `tty.*`
  /// sibling as a fallback, and vice-versa.
  List<String> _buildPortCandidates(String normalizedPort) {
    if (!Platform.isMacOS) return [normalizedPort];
    const cuPrefix = '/dev/cu.';
    const ttyPrefix = '/dev/tty.';
    if (normalizedPort.startsWith(cuPrefix)) {
      final suffix = normalizedPort.substring(cuPrefix.length);
      return [normalizedPort, '$ttyPrefix$suffix'];
    }
    if (normalizedPort.startsWith(ttyPrefix)) {
      final suffix = normalizedPort.substring(ttyPrefix.length);
      return [normalizedPort, '$cuPrefix$suffix'];
    }
    return [normalizedPort];
  }

  /// Sets the DTR line. On Android this issues a CDC control transfer; on
  /// desktop it reconfigures the open [SerialPort]. Throws [StateError] if
  /// not connected.
  Future<void> setDtr(bool value) async {
    if (_useAndroidUsbHost) {
      await _androidMethodChannel.invokeMethod<void>('setControlLines', {
        'dtr': value,
        'rts': _lastRts,
      });
      _lastDtr = value;
    } else {
      final serial = _serial;
      if (serial == null) {
        throw StateError('setDtr called while not connected');
      }
      serial.config = SerialPortConfig()
        ..dtr = value ? SerialPortDtr.on : SerialPortDtr.off;
    }
  }

  /// Sets the RTS line. See [setDtr].
  Future<void> setRts(bool value) async {
    if (_useAndroidUsbHost) {
      await _androidMethodChannel.invokeMethod<void>('setControlLines', {
        'dtr': _lastDtr,
        'rts': value,
      });
      _lastRts = value;
    } else {
      final serial = _serial;
      if (serial == null) {
        throw StateError('setRts called while not connected');
      }
      serial.config = SerialPortConfig()
        ..rts = value ? SerialPortRts.on : SerialPortRts.off;
    }
  }
}

enum UsbSerialStatus { disconnected, connecting, connected, disconnecting }
