import 'package:flutter/material.dart';
import 'package:meshcore_open/connector/meshcore_connector.dart';
import 'package:meshcore_open/widgets/battery_indicator.dart';
import 'package:provider/provider.dart';

import '../theme/mesh_tokens.dart';
import 'radio_stats_entry.dart';
import 'snr_indicator.dart';

/// The ⋮ menu icon for main-screen app bars, sized and padded identically to
/// the battery/signal/RF indicator columns so all four sit on one icon line.
/// The empty caption reserves the same line box the indicator captions use.
class AppBarMenuIcon extends StatelessWidget {
  const AppBarMenuIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.more_vert,
            size: 18,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          const SizedBox(height: 2),
          Text(
            '',
            style: MeshTokens.of(
              context,
            ).monoCaption().copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class AppBarTitle extends StatelessWidget {
  final String title;
  final Widget? leading;
  final Widget? trailing;
  final bool indicators;
  final bool showBatteryIndicator;
  final bool subtitle;
  const AppBarTitle(
    this.title, {
    this.leading,
    this.trailing,
    this.indicators = true,
    this.showBatteryIndicator = true,
    this.subtitle = true,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final connector = context.watch<MeshCoreConnector>();
    final selfName = connector.selfName;

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final compact = availableWidth < 170;
        final showSubtitle =
            !compact && connector.isConnected && selfName != null && subtitle;
        final showBattery = showBatteryIndicator && availableWidth >= 60;
        final showSnr = availableWidth >= 110;
        final showIndicators = (showBattery || showSnr) && indicators;

        return Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            leading ?? const SizedBox.shrink(),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (showSubtitle)
                    Text(
                      selfName,
                      style: TextStyle(
                        // 03-roles-chrome.md: bodyMedium + 2 (default 12+2=14).
                        fontSize:
                            (Theme.of(context).textTheme.bodyMedium?.fontSize ??
                                12) +
                            2,
                        color: Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            if (showIndicators) const SizedBox(width: 6),
            if (showIndicators)
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showBattery) BatteryIndicator(connector: connector),
                  if (showSnr) SNRIndicator(connector: connector),
                  if (connector.supportsCompanionRadioStats)
                    const RadioStatsIconButton(compact: true),
                ],
              ),
            trailing ?? const SizedBox.shrink(),
          ],
        );
      },
    );
  }
}
