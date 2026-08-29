import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import '../theme/mesh_tokens.dart';
import '../widgets/dotted_separator.dart';
import '../widgets/mesh_ui.dart';
import '../utils/contact_search.dart';

class SortFilterMenuOption<T> {
  final T value;
  final String label;
  final bool? checked;

  /// Leading slot override (2026-08-29 button-family redesign): when set,
  /// renders this icon (accent-colored, always full opacity — it signals
  /// "what this option is", not "is it selected") instead of the selector
  /// dot. Menus that aren't a single-choice group (no [checked]) can still
  /// carry a plain accent icon here and keep the exact same row geometry as
  /// every other dropdown — see [SortFilterMenu] doc comment for the
  /// canonical row spec this establishes for ALL future dropdown menus.
  final IconData? icon;

  /// On/off row (accepted variant U-A, 2026-08-29): rendered cut off from
  /// the single-choice group above it by a [DottedSeparator], with an EMPTY
  /// leading slot (text keeps the shared indent) and a mini switch on the
  /// trailing side — a toggle must not wear the selector dot, which promises
  /// "pick one of many" semantics this row doesn't have.
  final bool isToggle;

  const SortFilterMenuOption({
    required this.value,
    required this.label,
    this.checked,
    this.icon,
    this.isToggle = false,
  });
}

class SortFilterMenuSection<T> {
  final String title;
  final List<SortFilterMenuOption<T>> options;

  const SortFilterMenuSection({required this.title, required this.options});
}

/// Canonical dropdown-menu row spec (2026-08-29 button-family redesign) —
/// established here for [SortFilterMenu] first, but the geometry below is
/// the pattern EVERY future dropdown menu in the app should reuse, whether
/// or not it happens to need the selector dot:
/// - row: `EdgeInsets.symmetric(horizontal: 12, vertical: 7)`, corner
///   radius `t.buttonRadius` (same slider as every other button-family
///   member), fill `scheme.primary @ alpha 0.2` when selected/active, no
///   fill otherwise — same button-family formula as [SelectableChipButton].
/// - leading slot: fixed 20×20, always reserved (even when empty) so text
///   starts at the same x offset in every row of every menu. Filled by
///   EITHER the selector dot (single-choice groups, [SortFilterMenuOption.
///   checked] set) OR a plain accent-colored icon ([SortFilterMenuOption.
///   icon] set) — never both, and a menu can mix rows of each kind.
/// - text: `bodyMedium` (13), `w600`+primary when selected, `w500`+
///   onSurface otherwise.
/// - section separator: [DottedSeparator] between groups, replacing the
///   solid `PopupMenuDivider` — dash/gap geometry matches every other
///   dotted rule in the app (contact/channel card footers).
class SortFilterMenu<T> extends StatelessWidget {
  final List<SortFilterMenuSection<T>> sections;
  final ValueChanged<T> onSelected;
  final String tooltip;
  final Widget? icon;

  const SortFilterMenu({
    super.key,
    required this.sections,
    required this.onSelected,
    required this.tooltip,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T>(
      // Explicit primary tint (2026-08-23) — matches the app-wide button
      // ink color instead of inheriting the ambient onSurfaceVariant
      // iconTheme.
      icon:
          icon ??
          Icon(
            Icons.filter_list_outlined,
            color: Theme.of(context).colorScheme.primary,
          ),
      tooltip: tooltip,
      // Flutter's default position is PopupMenuPosition.over — the menu
      // opens directly ON TOP of the trigger icon, covering the search bar
      // that hosts it (2026-08-29 on-device feedback). `under` anchors it
      // Offset(0, button.size.height) below the icon instead; the extra
      // `offset` adds a small additional gap so it doesn't sit flush
      // against the search bar's bottom edge.
      position: PopupMenuPosition.under,
      offset: Offset(0, MeshTokens.of(context).spacingXxs),
      // Flutter's own default here is EdgeInsets.symmetric(vertical: 8) —
      // independent of the row gutter (padding: 10 on each option's
      // PopupMenuItem below), so the menu's top/bottom inset didn't match
      // its left/right inset (2026-08-29 on-device feedback). Match both.
      menuPadding: const EdgeInsets.symmetric(vertical: 10),
      onSelected: onSelected,
      itemBuilder: (context) {
        final theme = Theme.of(context);
        final labelStyle = theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        );
        final visibleSections = sections
            .where((section) => section.options.isNotEmpty)
            .toList();
        final entries = <PopupMenuEntry<T>>[];
        for (int i = 0; i < visibleSections.length; i++) {
          final section = visibleSections[i];
          entries.add(
            PopupMenuItem<T>(
              enabled: false,
              child: Text(section.title, style: labelStyle),
            ),
          );
          for (final option in section.options) {
            if (option.isToggle) {
              // Variant U-A: a toggle row is a different kind of control —
              // cut it off from the single-choice rows above it.
              entries.add(
                PopupMenuItem<T>(
                  enabled: false,
                  height: 13,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: DottedSeparator(
                    color: theme.colorScheme.outlineVariant,
                  ),
                ),
              );
            }
            entries.add(
              PopupMenuItem<T>(
                value: option.value,
                // Gutter between the menu's own rounded edge and the row's
                // fill pill — was EdgeInsets.zero, which let the pill touch
                // the popup card's edge directly (2026-08-29 on-device
                // feedback: missing L/R padding vs the accepted mockup,
                // where the row sat inside a `.row-pad` 10px inset before
                // its own 12px content padding).
                padding: const EdgeInsets.symmetric(horizontal: 10),
                height: 38,
                child: _MenuOptionRow(option: option),
              ),
            );
          }
          if (i < visibleSections.length - 1) {
            entries.add(
              PopupMenuItem<T>(
                enabled: false,
                height: 13,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: DottedSeparator(color: theme.colorScheme.outlineVariant),
              ),
            );
          }
        }
        return entries;
      },
    );
  }
}

class _MenuOptionRow<T> extends StatelessWidget {
  final SortFilterMenuOption<T> option;

  const _MenuOptionRow({required this.option});

  @override
  Widget build(BuildContext context) {
    final t = MeshTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    final selected = option.checked ?? false;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 1),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: selected ? scheme.primary.withValues(alpha: 0.2) : null,
        borderRadius: BorderRadius.circular(t.buttonRadius),
      ),
      child: Row(
        children: [
          _MenuOptionLeading(option: option, selected: selected),
          SizedBox(width: t.spacingXxs + 4),
          Expanded(
            child: Text(
              option.label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: selected ? scheme.primary : scheme.onSurface,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
          if (option.isToggle) _MiniToggle(on: selected),
        ],
      ),
    );
  }
}

/// Trailing mini switch for toggle rows (variant U-A, 2026-08-29) — the
/// real switchTheme grammar shrunk to row scale: tinted track (no outline)
/// + solid primary thumb sliding right when on; the off state ghosts the
/// whole pair to .30 like every other inactive indicator.
class _MiniToggle extends StatelessWidget {
  final bool on;

  const _MiniToggle({required this.on});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Opacity(
      opacity: on ? 1.0 : 0.30,
      child: Container(
        width: 34,
        height: 20,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: scheme.primary.withValues(alpha: 0.2),
        ),
        alignment: on ? Alignment.centerRight : Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: scheme.primary,
          ),
        ),
      ),
    );
  }
}

/// Fixed 20×20 leading slot — selector dot, plain accent icon, or empty
/// spacer, always reserved so option text aligns identically either way.
class _MenuOptionLeading<T> extends StatelessWidget {
  final SortFilterMenuOption<T> option;
  final bool selected;

  const _MenuOptionLeading({required this.option, required this.selected});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (option.icon != null) {
      return SizedBox(
        width: 20,
        height: 20,
        child: Icon(option.icon, size: 18, color: scheme.primary),
      );
    }
    if (option.checked == null || option.isToggle) {
      // Toggle rows keep the slot EMPTY (variant U-A) — the mini switch on
      // the trailing side carries the state; the reserved width keeps the
      // text at the shared indent.
      return const SizedBox(width: 20, height: 20);
    }
    // Selector dot — accepted variant B2 (2026-08-29); shared widget so the
    // dropdown rows and selection sheets ("winda") can never drift apart.
    return MeshSelectorDot(selected: selected);
  }
}

sealed class _ContactsFilterAction {
  const _ContactsFilterAction();
}

class _SortAction extends _ContactsFilterAction {
  final ContactSortOption option;
  const _SortAction(this.option);
}

class _TypeFilterAction extends _ContactsFilterAction {
  final ContactTypeFilter filter;
  const _TypeFilterAction(this.filter);
}

class _ToggleUnreadAction extends _ContactsFilterAction {
  const _ToggleUnreadAction();
}

class ContactsFilterMenu extends StatelessWidget {
  final ContactSortOption sortOption;
  final ContactTypeFilter typeFilter;
  final bool showUnreadOnly;
  final ValueChanged<ContactSortOption> onSortChanged;
  final ValueChanged<ContactTypeFilter> onTypeFilterChanged;
  final ValueChanged<bool> onUnreadOnlyChanged;

  const ContactsFilterMenu({
    super.key,
    required this.sortOption,
    required this.typeFilter,
    required this.showUnreadOnly,
    required this.onSortChanged,
    required this.onTypeFilterChanged,
    required this.onUnreadOnlyChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SortFilterMenu<_ContactsFilterAction>(
      tooltip: l10n.listFilter_tooltip,
      sections: [
        SortFilterMenuSection(
          title: l10n.listFilter_sortBy,
          options: [
            SortFilterMenuOption(
              value: _SortAction(ContactSortOption.recentMessages),
              label: l10n.listFilter_latestMessages,
              checked: sortOption == ContactSortOption.recentMessages,
            ),
            SortFilterMenuOption(
              value: _SortAction(ContactSortOption.lastSeen),
              label: l10n.listFilter_heardRecently,
              checked: sortOption == ContactSortOption.lastSeen,
            ),
            SortFilterMenuOption(
              value: _SortAction(ContactSortOption.name),
              label: l10n.listFilter_az,
              checked: sortOption == ContactSortOption.name,
            ),
          ],
        ),
        SortFilterMenuSection(
          title: l10n.listFilter_filters,
          options: [
            SortFilterMenuOption(
              value: _TypeFilterAction(ContactTypeFilter.all),
              label: l10n.listFilter_all,
              checked: typeFilter == ContactTypeFilter.all,
            ),
            SortFilterMenuOption(
              value: _TypeFilterAction(ContactTypeFilter.favorites),
              label: l10n.listFilter_favorites,
              checked: typeFilter == ContactTypeFilter.favorites,
            ),
            SortFilterMenuOption(
              value: _TypeFilterAction(ContactTypeFilter.users),
              label: l10n.listFilter_users,
              checked: typeFilter == ContactTypeFilter.users,
            ),
            SortFilterMenuOption(
              value: _TypeFilterAction(ContactTypeFilter.repeaters),
              label: l10n.listFilter_repeaters,
              checked: typeFilter == ContactTypeFilter.repeaters,
            ),
            SortFilterMenuOption(
              value: _TypeFilterAction(ContactTypeFilter.rooms),
              label: l10n.listFilter_roomServers,
              checked: typeFilter == ContactTypeFilter.rooms,
            ),
            SortFilterMenuOption(
              value: const _ToggleUnreadAction(),
              label: l10n.listFilter_unreadOnly,
              checked: showUnreadOnly,
              isToggle: true,
            ),
          ],
        ),
      ],
      onSelected: (action) {
        switch (action) {
          case _SortAction(:final option):
            onSortChanged(option);
          case _TypeFilterAction(:final filter):
            onTypeFilterChanged(filter);
          case _ToggleUnreadAction():
            onUnreadOnlyChanged(!showUnreadOnly);
        }
      },
    );
  }
}

sealed class _DiscoveryFilterAction {
  const _DiscoveryFilterAction();
}

class _DiscoverySortAction extends _DiscoveryFilterAction {
  final ContactSortOption option;
  const _DiscoverySortAction(this.option);
}

class _DiscoveryTypeFilterAction extends _DiscoveryFilterAction {
  final ContactTypeFilter filter;
  const _DiscoveryTypeFilterAction(this.filter);
}

class DiscoveryContactsFilterMenu extends StatelessWidget {
  final ContactSortOption sortOption;
  final ContactTypeFilter typeFilter;
  final ValueChanged<ContactSortOption> onSortChanged;
  final ValueChanged<ContactTypeFilter> onTypeFilterChanged;

  const DiscoveryContactsFilterMenu({
    super.key,
    required this.sortOption,
    required this.typeFilter,
    required this.onSortChanged,
    required this.onTypeFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SortFilterMenu<_DiscoveryFilterAction>(
      tooltip: l10n.listFilter_tooltip,
      sections: [
        SortFilterMenuSection(
          title: l10n.listFilter_sortBy,
          options: [
            SortFilterMenuOption(
              value: _DiscoverySortAction(ContactSortOption.lastSeen),
              label: l10n.listFilter_heardRecently,
              checked: sortOption == ContactSortOption.lastSeen,
            ),
            SortFilterMenuOption(
              value: _DiscoverySortAction(ContactSortOption.name),
              label: l10n.listFilter_az,
              checked: sortOption == ContactSortOption.name,
            ),
          ],
        ),
        SortFilterMenuSection(
          title: l10n.listFilter_filters,
          options: [
            SortFilterMenuOption(
              value: _DiscoveryTypeFilterAction(ContactTypeFilter.all),
              label: l10n.listFilter_all,
              checked: typeFilter == ContactTypeFilter.all,
            ),
            SortFilterMenuOption(
              value: _DiscoveryTypeFilterAction(ContactTypeFilter.users),
              label: l10n.listFilter_users,
              checked: typeFilter == ContactTypeFilter.users,
            ),
            SortFilterMenuOption(
              value: _DiscoveryTypeFilterAction(ContactTypeFilter.repeaters),
              label: l10n.listFilter_repeaters,
              checked: typeFilter == ContactTypeFilter.repeaters,
            ),
            SortFilterMenuOption(
              value: _DiscoveryTypeFilterAction(ContactTypeFilter.rooms),
              label: l10n.listFilter_roomServers,
              checked: typeFilter == ContactTypeFilter.rooms,
            ),
          ],
        ),
      ],
      onSelected: (action) {
        switch (action) {
          case _DiscoverySortAction(:final option):
            onSortChanged(option);
          case _DiscoveryTypeFilterAction(:final filter):
            onTypeFilterChanged(filter);
        }
      },
    );
  }
}
