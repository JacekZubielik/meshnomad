import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../connector/meshcore_connector.dart';
import '../connector/meshcore_protocol.dart';
import '../helpers/path_helper.dart';
import '../l10n/l10n.dart';
import '../models/contact.dart';
import '../screens/map_screen.dart';
import '../theme/mesh_tokens.dart';
import 'indicator_caption.dart';
import 'mesh_info_dialog.dart';
import 'mesh_ui.dart';
import 'signal_ui.dart';
import 'mesh_dashed_divider.dart';

Contact? _getRepeaterPrefixMatchNearLocation(
  List<Contact> contacts,
  List<int> pubkeyPrefix, {
  String? contactKeyHex,
  LatLng? searchPoint,
  bool preferFavorites = false,
}) {
  if (contactKeyHex != null) {
    for (final c in contacts) {
      if (c.publicKeyHex == contactKeyHex) {
        return c;
      }
    }
  }

  final candidates = contacts
      .where(
        (c) =>
            c.publicKey.length >= pubkeyPrefix.length &&
            listEquals(
              c.publicKey.sublist(0, pubkeyPrefix.length),
              pubkeyPrefix,
            ) &&
            (c.type == advTypeRepeater || c.type == advTypeRoom),
      )
      .toList();

  if (candidates.isEmpty) return null;

  candidates.sort((a, b) {
    if (preferFavorites) {
      final favA = a.isFavorite ? 1 : 0;
      final favB = b.isFavorite ? 1 : 0;
      final favCompare = favB.compareTo(favA);
      if (favCompare != 0) return favCompare;
    }

    final seenCompare = b.lastSeen.compareTo(a.lastSeen);
    if (seenCompare != 0) return seenCompare;

    return a.publicKeyHex.compareTo(b.publicKeyHex);
  });

  if (searchPoint == null) {
    return candidates.first;
  }

  final distance = Distance();
  Contact best = candidates.first;
  var bestDistance = double.infinity;

  for (final c in candidates) {
    if (c.hasLocation && c.latitude != null && c.longitude != null) {
      final d = distance(searchPoint, LatLng(c.latitude!, c.longitude!));
      if (d < bestDistance) {
        bestDistance = d;
        best = c;
      }
    }
  }

  return best;
}

class SNRUi {
  final IconData icon;
  final Color color;
  final String text;
  const SNRUi(this.icon, this.color, this.text);
}

List<double> getSNRfromSF(int spreadingFactor) {
  switch (spreadingFactor) {
    case 7:
      return [4.0, -2.0, -4.0, -6.0];
    case 8:
      return [4.0, -4.0, -6.0, -8.0];
    case 9:
      return [4.0, -6.0, -8.0, -10.0];
    case 10:
      return [4.0, -8.0, -10.0, -13.0];
    case 11:
      return [4.0, -10.0, -12.5, -15.0];
    case 12:
      return [4.0, -12.5, -15.0, -18.0];
    default:
      return []; // Or throw Exception('Invalid SF: $spreadingFactor');
  }
}

SNRUi snrUiFromSNR(BuildContext context, double? snr, int? spreadingFactor) {
  if (snr == null ||
      spreadingFactor == null ||
      spreadingFactor < 7 ||
      spreadingFactor > 12) {
    return SNRUi(Icons.signal_cellular_off, MeshTokens.of(context).ink4, '—');
  }

  final snrLevels = getSNRfromSF(spreadingFactor);

  String text = '${snr.toStringAsFixed(1)}dB';
  final tier = snr >= snrLevels[0]
      ? 0
      : snr >= snrLevels[1]
      ? 1
      : snr >= snrLevels[2]
      ? 2
      : snr >= snrLevels[3]
      ? 3
      : 4;
  final signalUi = signalUiForStrengthTier(context, tier);

  return SNRUi(signalUi.icon, signalUi.color, text);
}

String _formatLastUpdated(DateTime lastSeen) {
  final now = DateTime.now();
  final diff = now.difference(lastSeen);
  if (diff.isNegative) {
    return "0s";
  }
  if (diff.inMinutes < 1) {
    return "${diff.inSeconds}s";
  }
  if (diff.inMinutes < 60) {
    return "${diff.inMinutes}m";
  }
  if (diff.inHours < 24) {
    final hours = diff.inHours;
    return "${hours}h";
  }
  final days = diff.inDays;
  return "${days}d";
}

class NearbyRepeaterTile extends StatelessWidget {
  final DirectRepeater repeater;
  final Contact? contact;

  const NearbyRepeaterTile({super.key, required this.repeater, this.contact});

  @override
  Widget build(BuildContext context) {
    final contact = this.contact;
    final name = contact?.name;
    final prefixLabel = PathHelper.formatHopHex(repeater.pubkeyPrefix);
    final snrColor = MeshTokens.of(
      context,
    ).snrColor(repeater.snr, blocked: false);
    final latitude = contact?.latitude;
    final longitude = contact?.longitude;
    final hasLocation =
        (contact?.hasLocation ?? false) &&
        latitude != null &&
        longitude != null;

    return Padding(
      // vertical 10 has no exact token — spacingSm (12) is nearest.
      padding: EdgeInsets.symmetric(
        horizontal: MeshTokens.of(context).spacingMd,
        vertical: MeshTokens.of(context).spacingSm,
      ),
      child: Row(
        children: [
          AvatarCircle(name: name ?? prefixLabel, size: 36, color: snrColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name ?? prefixLabel,
                        style: Theme.of(context).textTheme.bodyMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (contact != null) ...[
                      const SizedBox(width: 6),
                      RouteChip(
                        isDirect: contact.pathLength >= 0,
                        hops: contact.pathLength,
                      ),
                    ],
                  ],
                ),
                Text(
                  '$prefixLabel • ${repeater.snr.toStringAsFixed(1)} dB • ${_formatLastUpdated(repeater.lastUpdated)}',
                  style: MeshTokens.of(context).monoCaption(color: snrColor),
                ),
                if (hasLocation)
                  Text(
                    '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}',
                    style: MeshTokens.of(context).monoCaption(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          if (hasLocation)
            IconButton(
              icon: const Icon(Icons.map_outlined),
              tooltip: context.l10n.map_centerOnNode,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => MapScreen(
                    highlightPosition: LatLng(latitude, longitude),
                    highlightLabel: name ?? prefixLabel,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class SNRIndicator extends StatefulWidget {
  final MeshCoreConnector connector;

  const SNRIndicator({super.key, required this.connector});

  @override
  State<SNRIndicator> createState() => _SNRIndicatorState();
}

class _SNRIndicatorState extends State<SNRIndicator> {
  bool _isValidSelfLocation(double lat, double lon) {
    const double epsilon = 1e-6;
    return (lat.abs() > epsilon || lon.abs() > epsilon) &&
        lat >= -90.0 &&
        lat <= 90.0 &&
        lon >= -180.0 &&
        lon <= 180.0;
  }

  @override
  Widget build(BuildContext context) {
    final directRepeaters = widget.connector.directRepeaters;
    final directBestRepeaters = List.of(directRepeaters)
      ..sort((a, b) => (b.ranking).compareTo(a.ranking));
    final directRepeater = directBestRepeaters.isEmpty
        ? null
        : directBestRepeaters.first;

    final snrUi = snrUiFromSNR(
      context,
      directBestRepeaters.isNotEmpty ? directRepeater!.snr : null,
      widget.connector.currentSf,
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      child: InkWell(
        onTap: directRepeater != null
            ? () => _showFullPathDialog(context, directBestRepeaters)
            : null,
        borderRadius: BorderRadius.circular(MeshTokens.of(context).xs),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: MeshTokens.of(context).spacingXxs,
            vertical: MeshTokens.of(context).spacingXs,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(snrUi.icon, size: 18, color: snrUi.color),
              const SizedBox(height: 2),
              IndicatorCaption(snrUi.text),
            ],
          ),
        ),
      ),
    );
  }

  void _showFullPathDialog(
    BuildContext context,
    List<DirectRepeater> directBestRepeaters,
  ) {
    final allContacts = widget.connector.allContacts;
    final selfLat = widget.connector.selfLatitude;
    final selfLon = widget.connector.selfLongitude;

    LatLng? selfPoint;
    if (selfLat != null &&
        selfLon != null &&
        _isValidSelfLocation(selfLat, selfLon)) {
      selfPoint = LatLng(selfLat, selfLon);
    }

    showMeshInfoDialog<void>(
      context,
      title:
          '${context.l10n.snrIndicator_nearByRepeaters} '
          '(${directBestRepeaters.length})',
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (index, repeater) in directBestRepeaters.indexed) ...[
            if (index > 0) const MeshDashedDivider(),
            NearbyRepeaterTile(
              repeater: repeater,
              contact: _getRepeaterPrefixMatchNearLocation(
                allContacts,
                repeater.pubkeyPrefix,
                contactKeyHex: repeater.contactKeyHex,
                searchPoint: selfPoint,
                preferFavorites: true,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
