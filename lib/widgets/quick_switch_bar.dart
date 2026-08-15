import 'package:flutter/material.dart';
import '../l10n/l10n.dart';

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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final labelStyle = theme.textTheme.labelMedium ?? const TextStyle();
    // Solid theme surface on every tab (user decision 2026-08-10) — the old
    // translucent "glass" pill read the map tiles through itself on the map
    // tab and drew visible rounded corners over the uniform backdrop.
    // The selected icon sits on the primary indicator pill, so it uses
    // onPrimary. The label sits below on the bar background, so it must use a
    // foreground color that contrasts with the surface (not onPrimary, which
    // is white-on-white in the light theme).
    return SizedBox(
      width: double.infinity,
      child: ColoredBox(
        color: colorScheme.surface,
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            shadowColor: Colors.transparent,
            indicatorColor: colorScheme.primary,
            // This local NavigationBarTheme fully replaces the app-level
            // one for this subtree (fields left unset fall back to
            // Flutter's own Material-3 defaults, NOT to Theme.of(context)),
            // so without this the indicator was always a hardcoded
            // StadiumBorder — ignoring every Custom Style radius token.
            indicatorShape: theme.navigationBarTheme.indicatorShape,
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              final isSelected = states.contains(WidgetState.selected);
              return labelStyle.copyWith(
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? colorScheme.onSurface
                    : colorScheme.onSurfaceVariant,
              );
            }),
            iconTheme: WidgetStateProperty.resolveWith((states) {
              final isSelected = states.contains(WidgetState.selected);
              return IconThemeData(
                color: isSelected
                    ? colorScheme.onPrimary
                    : colorScheme.onSurfaceVariant,
              );
            }),
          ),
          child: NavigationBar(
            height: 72,
            selectedIndex: selectedIndex,
            onDestinationSelected: onDestinationSelected,
            destinations: [
              NavigationDestination(
                icon: _buildIconWithBadge(
                  context,
                  const Icon(Icons.people_outline),
                  contactsUnreadCount,
                ),
                selectedIcon: _buildIconWithBadge(
                  context,
                  const Icon(Icons.people),
                  contactsUnreadCount,
                ),
                label: context.l10n.nav_contacts,
              ),
              NavigationDestination(
                icon: _buildIconWithBadge(
                  context,
                  const Icon(Icons.tag),
                  channelsUnreadCount,
                ),
                selectedIcon: _buildIconWithBadge(
                  context,
                  const Icon(Icons.tag),
                  channelsUnreadCount,
                ),
                label: context.l10n.nav_channels,
              ),
              NavigationDestination(
                icon: const Icon(Icons.map_outlined),
                selectedIcon: const Icon(Icons.map),
                label: context.l10n.nav_map,
              ),
            ],
          ),
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
