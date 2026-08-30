import 'package:flutter/material.dart';

import '../connector/meshcore_connector.dart';
import '../l10n/l10n.dart';
import '../theme/mesh_tokens.dart';
import '../utils/platform_info.dart';
import 'theme_profile_selector.dart';

/// Companion-connect transport switcher (2026-08-29 redesign) — shown
/// identically on the BLE/USB/TCP connect screens, replacing the old
/// per-screen mix of app-bar icon buttons (scanner_screen.dart) and inline
/// `Wrap` of two `OutlinedButton.icon` (usb_screen.dart/tcp_screen.dart).
///
/// Built from `SelectableChipButton` — the same widget QuickSwitchBar uses
/// (2026-08-29): FilledButton when selected, OutlinedButton otherwise, so
/// it follows the app's button-family fill/radius/border rules for free.
/// The current transport renders selected and non-tappable (`onTap: null`)
/// rather than a live link back to the same screen.
class TransportSwitcher extends StatelessWidget {
  const TransportSwitcher({
    super.key,
    required this.current,
    required this.onSelectBluetooth,
    required this.onSelectUsb,
    required this.onSelectTcp,
  });

  final MeshCoreTransportType current;
  final VoidCallback onSelectBluetooth;
  final VoidCallback onSelectUsb;
  final VoidCallback onSelectTcp;

  @override
  Widget build(BuildContext context) {
    final t = MeshTokens.of(context);
    final l10n = context.l10n;
    final entries = [
      (
        type: MeshCoreTransportType.bluetooth,
        icon: Icons.bluetooth,
        label: l10n.connectionChoiceBluetoothLabel,
        onTap: onSelectBluetooth,
      ),
      if (PlatformInfo.supportsUsbSerial)
        (
          type: MeshCoreTransportType.usb,
          icon: Icons.usb,
          label: l10n.connectionChoiceUsbLabel,
          onTap: onSelectUsb,
        ),
      if (!PlatformInfo.isWeb)
        (
          type: MeshCoreTransportType.tcp,
          icon: Icons.lan,
          label: l10n.connectionChoiceTcpLabel,
          onTap: onSelectTcp,
        ),
    ];
    return Padding(
      padding: EdgeInsets.fromLTRB(
        t.spacingMd,
        t.spacingXxs,
        t.spacingMd,
        t.spacingMd,
      ),
      child: Row(
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            if (i > 0) SizedBox(width: t.spacingXs),
            Expanded(
              child: Semantics(
                label: entries[i].label,
                button: true,
                selected: entries[i].type == current,
                child: SelectableChipButton(
                  icon: Icon(entries[i].icon, size: 18),
                  label: entries[i].label,
                  selected: entries[i].type == current,
                  onTap: entries[i].type == current ? () {} : entries[i].onTap,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
