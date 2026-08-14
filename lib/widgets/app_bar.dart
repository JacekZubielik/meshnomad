import 'package:flutter/material.dart';
import 'package:meshcore_open/connector/meshcore_connector.dart';
import 'package:meshcore_open/widgets/battery_indicator.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../theme/mesh_tokens.dart';
import 'indicator_caption.dart';
import 'mesh_info_dialog.dart';
import 'radio_stats_entry.dart';
import 'snr_indicator.dart';
import 'stats_line_chart.dart';
import 'sync_progress_overlay.dart';

/// The ⋮ menu icon for main-screen app bars — same icon size as the
/// indicators, vertically centered in the toolbar.
class AppBarMenuIcon extends StatelessWidget {
  const AppBarMenuIcon({super.key});

  @override
  Widget build(BuildContext context) {
    // ~Square touch field right of the last separator. No right padding:
    // the AppBar's titleSpacing already provides the 16dp edge inset, so the
    // right margin mirrors the title's left inset exactly.
    final xs = MeshTokens.of(context).spacingXs;
    return Padding(
      padding: EdgeInsets.only(left: xs, top: xs, bottom: xs),
      child: Center(
        child: Icon(
          Icons.more_vert,
          size: 18,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}

/// The shared app-bar pattern for main cards (Contacts / Channels / Map and
/// any future card): identical title placement, sync progress strip and a
/// ⋮ menu sized like the indicators. Build every card's app bar through
/// this — never hand-roll an AppBar on a main card.
AppBar meshMainAppBar(
  BuildContext context, {
  required String title,
  required List<PopupMenuEntry<dynamic>> Function(BuildContext) menuItemBuilder,
  String? menuTooltip,
  Color? backgroundColor,
  Color? foregroundColor,
}) {
  // The ⋮ menu lives INSIDE AppBarTitle's row (trailing), right after the
  // last indicator separator — AppBar's own title/actions layout would insert
  // an extra titleSpacing-wide gap between the cluster and the menu.
  return AppBar(
    title: AppBarTitle(
      title,
      trailing: PopupMenuButton<dynamic>(
        tooltip: menuTooltip,
        itemBuilder: menuItemBuilder,
        child: const AppBarMenuIcon(),
      ),
    ),
    centerTitle: false,
    titleSpacing: 16,
    automaticallyImplyLeading: false,
    backgroundColor: backgroundColor,
    foregroundColor: foregroundColor,
    bottom: const SyncProgressAppBarBottom(),
  );
}

/// 1 px vertical rule between app-bar indicators, drawn with the "Lines"
/// token so it follows the custom style.
class _IndicatorSeparator extends StatelessWidget {
  const _IndicatorSeparator();

  @override
  Widget build(BuildContext context) {
    // Same stroke as every other divider in the app, so it recolors and
    // rescales with the custom style like the rest of the theme.
    return Container(
      key: const ValueKey('appBarIndicatorSeparator'),
      width: DividerTheme.of(context).thickness ?? 1,
      height: 28,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      color:
          DividerTheme.of(context).color ??
          Theme.of(context).colorScheme.outlineVariant,
    );
  }
}

/// Connection-transport indicator: BT / USB / IP icon with the parameter
/// that identifies the live link (BLE RSSI, USB port, TCP endpoint).
class TransportIndicator extends StatefulWidget {
  final MeshCoreConnector connector;

  const TransportIndicator({super.key, required this.connector});

  @override
  State<TransportIndicator> createState() => _TransportIndicatorState();
}

class _TransportIndicatorState extends State<TransportIndicator> {
  @override
  void initState() {
    super.initState();
    widget.connector.acquireBleRssiPolling();
  }

  @override
  void dispose() {
    widget.connector.releaseBleRssiPolling();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connector = widget.connector;
    final IconData icon;
    final String caption;
    switch (connector.activeTransport) {
      case MeshCoreTransportType.bluetooth:
        icon = Icons.bluetooth;
        final rssi = connector.bleLinkRssi;
        caption = rssi == null ? '—' : '${rssi}dBm';
      case MeshCoreTransportType.usb:
        icon = Icons.usb;
        // Port paths/names are too long for the caption — show the link's
        // baud rate ('115200' fits the fixed box); full details belong to
        // the future indicator popup.
        caption = connector.activeUsbBaudRate?.toString() ?? 'USB';
      case MeshCoreTransportType.tcp:
        icon = Icons.lan;
        caption = connector.activeTcpEndpoint ?? 'TCP';
    }
    final scheme = Theme.of(context).colorScheme;
    // The BT glyph carries the accent — the RF activity icon blinks white.
    final iconColor =
        connector.activeTransport == MeshCoreTransportType.bluetooth
        ? scheme.primary
        : scheme.onSurfaceVariant;
    final tokens = MeshTokens.of(context);
    return InkWell(
      // 8→6dp: xs is the nearest available token radius.
      borderRadius: BorderRadius.circular(tokens.xs),
      onTap: () => _showTransportPopup(context),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacingXxs,
          vertical: tokens.spacingXs,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(height: 2),
            IndicatorCaption(caption),
          ],
        ),
      ),
    );
  }

  void _showTransportPopup(BuildContext context) {
    final connector = widget.connector;
    showMeshInfoDialog<void>(
      context,
      title: context.l10n.indicator_connectionTitle,
      builder: (_) => AnimatedBuilder(
        animation: connector,
        builder: (context, _) {
          final l10n = context.l10n;
          final isBle =
              connector.activeTransport == MeshCoreTransportType.bluetooth;
          // USB rows render as two aligned columns; the label column is as
          // wide as the longest label of the pair.
          final usbLabelWidth = meshInfoLabelColumnWidth(context, [
            l10n.indicator_portLabel,
            l10n.indicator_baudLabel,
          ]);
          final rows = <Widget>[
            switch (connector.activeTransport) {
              MeshCoreTransportType.bluetooth => MeshInfoRow(
                l10n.indicator_deviceLabel,
                connector.deviceDisplayName,
              ),
              MeshCoreTransportType.usb => MeshInfoRow(
                l10n.indicator_portLabel,
                connector.activeUsbPortDisplayLabel ?? '—',
                labelWidth: usbLabelWidth,
              ),
              MeshCoreTransportType.tcp => MeshInfoRow(
                l10n.indicator_endpointLabel,
                connector.activeTcpEndpoint ?? '—',
              ),
            },
            switch (connector.activeTransport) {
              MeshCoreTransportType.bluetooth => MeshInfoRow(
                l10n.indicator_macLabel,
                connector.deviceIdLabel,
              ),
              MeshCoreTransportType.usb => MeshInfoRow(
                l10n.indicator_baudLabel,
                connector.activeUsbBaudRate?.toString() ?? '—',
                labelWidth: usbLabelWidth,
              ),
              MeshCoreTransportType.tcp => MeshInfoRow(
                l10n.indicator_portLabel,
                connector.activeTcpEndpoint?.split(':').last ?? '—',
              ),
            },
            if (isBle)
              MeshInfoRow(
                l10n.indicator_rssiLabel,
                connector.bleLinkRssi != null
                    ? '${connector.bleLinkRssi} dBm'
                    : '—',
              ),
          ];
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ...rows,
              if (isBle) ...[
                const SizedBox(height: 8),
                StatsLineChart(samples: connector.bleRssiHistory, height: 140),
              ],
            ],
          );
        },
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
        final showBattery =
            showBatteryIndicator &&
            availableWidth >= 60 &&
            connector.batteryMillivolts != null;
        final showSnr = availableWidth >= 110;

        // Every visible indicator is followed by a vertical separator in the
        // "Lines" token color — the trailing one visually splits the cluster
        // from the ⋮ menu living in the AppBar actions.
        final indicatorWidgets = <Widget>[
          if (showBattery) BatteryIndicator(connector: connector),
          if (showSnr) SNRIndicator(connector: connector),
          if (connector.isConnected && connector.supportsCompanionRadioStats)
            const RadioStatsIconButton(compact: true),
          if (connector.isConnected) TransportIndicator(connector: connector),
        ];
        final showIndicators = indicators && indicatorWidgets.isNotEmpty;

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
                        color: MeshTokens.of(context).ink2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            if (showIndicators) const SizedBox(width: 6),
            if (showIndicators)
              // Non-flex child pinned to the right edge: the Expanded title
              // absorbs ALL slack, so the cluster and the ⋮ hug the right
              // side like the chat screens' actions do. The width cap only
              // kicks in on very narrow bars, scaling the cluster down
              // uniformly while the title keeps a readable minimum.
              ConstrainedBox(
                constraints: BoxConstraints(
                  // Reserve ~160dp so the card name and device name stay
                  // readable before the cluster starts scaling down.
                  maxWidth: (availableWidth - 160).clamp(120.0, availableWidth),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final indicator in indicatorWidgets) ...[
                        indicator,
                        const _IndicatorSeparator(),
                      ],
                    ],
                  ),
                ),
              ),
            trailing ?? const SizedBox.shrink(),
          ],
        );
      },
    );
  }
}
