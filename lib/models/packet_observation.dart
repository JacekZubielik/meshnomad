import 'dart:typed_data';

/// One observed radio packet, captured from `PUSH_CODE_LOG_RX_DATA` frames.
///
/// Fields mirror what the firmware reports per packet; anything the frame does
/// not carry (notably a timestamp) is filled in at observation time.
class PacketObservation {
  const PacketObservation({
    required this.observedAt,
    required this.payloadType,
    required this.routeType,
    required this.snr,
    required this.rssi,
    required this.hopCount,
    required this.hopHashWidth,
    required this.pathBytes,
    required this.payloadLength,
  });

  /// Local time the frame was handled. RX frames carry no timestamp field.
  final DateTime observedAt;

  /// Raw payload type nibble, e.g. `payloadTypeADVERT`.
  final int payloadType;

  /// Raw route type, 0x00..0x03.
  final int routeType;

  /// Signal-to-noise ratio in dB, already scaled by the connector.
  final double snr;

  /// Received signal strength in dBm. Negative in practice.
  final int rssi;

  /// Number of hops recorded in the path. Zero means direct or unrecorded.
  final int hopCount;

  /// Bytes per hop hash, 1..4. Meaningless when [hopCount] is zero.
  final int hopHashWidth;

  /// Raw path bytes, `hopCount * hopHashWidth` long.
  final Uint8List pathBytes;

  /// Length of the payload that followed the path.
  final int payloadLength;

  /// Hop hashes rendered as uppercase hex, one entry per hop.
  List<String> get hopTokens {
    if (hopCount <= 0 || hopHashWidth <= 0) return const [];
    final tokens = <String>[];
    for (var i = 0; i + hopHashWidth <= pathBytes.length; i += hopHashWidth) {
      final buffer = StringBuffer();
      for (var j = 0; j < hopHashWidth; j++) {
        buffer.write(pathBytes[i + j].toRadixString(16).padLeft(2, '0'));
      }
      tokens.add(buffer.toString().toUpperCase());
    }
    return tokens;
  }

  /// Hop tokens joined with '>', or null when the packet carries no path.
  String? get pathSignature {
    final tokens = hopTokens;
    if (tokens.isEmpty) return null;
    return tokens.join('>');
  }
}
