import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import '../theme/mesh_tokens.dart';
import 'theme_profile_selector.dart';

class QuickSwitchBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final int contactsUnreadCount;
  final int channelsUnreadCount;

  const QuickSwitchBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.contactsUnreadCount = 0,
    this.channelsUnreadCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final t = MeshTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    // 2026-08-29 redesign: NavigationBar replaced with the app's real
    // selection-group buttons (SelectableChipButton — the QuickStylePicker
    // pattern: FilledButton when active, OutlinedButton otherwise). Icons
    // only, no captions; the active button therefore follows the Custom
    // Style Buttons section (buttonRadius corners, buttonBorder
    // none/solid/dotted outline) instead of the fixed NavigationBar
    // indicator pill. Screen names stay available to assistive tech via
    // Semantics below.
    // Solid theme surface on every tab (user decision 2026-08-10) — the old
    // translucent "glass" pill read the map tiles through itself on the map
    // tab.
    final destinations = [
      (
        icon: Icons.people_outline,
        selectedIcon: Icons.people,
        label: context.l10n.nav_contacts,
        badge: contactsUnreadCount,
      ),
      (
        icon: Icons.tag,
        selectedIcon: Icons.tag,
        label: context.l10n.nav_channels,
        badge: channelsUnreadCount,
      ),
      (
        icon: Icons.map_outlined,
        selectedIcon: Icons.map,
        label: context.l10n.nav_map,
        badge: 0,
      ),
    ];
    return ColoredBox(
      color: scheme.surface,
      child: Padding(
        // Outer gap from the bar's own top/bottom edge to the button edge
        // — was spacingXxs (6), read as far too tight against the taller
        // buttons (2026-08-29 user feedback).
        padding: EdgeInsets.symmetric(
          horizontal: t.spacingMd,
          vertical: t.spacingMd,
        ),
        child: Row(
          children: [
            for (var i = 0; i < destinations.length; i++) ...[
              if (i > 0) SizedBox(width: t.spacingXs),
              Expanded(
                child: Semantics(
                  label: destinations[i].label,
                  button: true,
                  selected: i == selectedIndex,
                  child: SelectableChipButton(
                    icon: _buildIconWithBadge(
                      context,
                      Icon(
                        i == selectedIndex
                            ? destinations[i].selectedIcon
                            : destinations[i].icon,
                      ),
                      destinations[i].badge,
                    ),
                    // Icon-only buttons read cramped at the shared chip
                    // padding — 1.5x the vertical inset, top/bottom stay
                    // equal (2026-08-29 user feedback).
                    padding: EdgeInsets.symmetric(
                      horizontal: t.spacingMd,
                      vertical: t.spacingXs * 1.5,
                    ),
                    selected: i == selectedIndex,
                    onTap: () => onDestinationSelected(i),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildIconWithBadge(BuildContext context, Icon icon, int count) {
    if (count <= 0) return icon;
    final label = count > 99 ? '99+' : '$count';
    return Badge(label: Text(label), child: icon);
  }
}
