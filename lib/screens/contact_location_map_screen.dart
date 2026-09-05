import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../services/map_tile_cache_service.dart';
import '../theme/mesh_tokens.dart';
import '../widgets/app_bar.dart';

/// Focused, single-marker map view for one contact's known GPS location —
/// pushed from the Contacts list's GPS badge (2026-08-19 refinement). Unlike
/// the shared [MapScreen] (a persistent bottom-tab root whose back
/// navigation is deliberately blocked while connected — see its own
/// `allowBack`), this is a genuine detail screen with a plain [AppBar] and a
/// normal back button, matching [PathTraceMapScreen]'s pattern (used by the
/// Route badge) rather than the tab-root one.
class ContactLocationMapScreen extends StatelessWidget {
  final LatLng position;
  final String contactName;

  const ContactLocationMapScreen({
    super.key,
    required this.position,
    required this.contactName,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = MeshTokens.of(context);
    final tileCache = context.read<MapTileCacheService>();
    return Scaffold(
      appBar: AppBar(
        title: Text(contactName),
        actions: const [QuickAccessMenuButton()],
      ),
      body: FlutterMap(
        options: MapOptions(
          initialCenter: position,
          initialZoom: 15,
          interactionOptions: const InteractionOptions(
            flags: ~InteractiveFlag.rotate,
          ),
        ),
        children: [
          tileCache.buildTileLayer(context),
          MarkerLayer(
            markers: [
              Marker(
                point: position,
                width: 44,
                height: 44,
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: tokens.mapBatteryLow,
                      border: Border.all(
                        color: tokens.mapMarkerOutline,
                        width: 3,
                      ),
                      boxShadow: tokens.mapMarkerShadowBox,
                    ),
                    child: Icon(
                      Icons.location_on,
                      color: tokens.mapMarkerInk,
                      size: 25,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
