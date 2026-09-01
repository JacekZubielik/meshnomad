import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:meshnomad/screens/contact_location_map_screen.dart';
import 'package:meshnomad/screens/path_trace_map.dart';
import 'package:meshnomad/services/notification_service.dart';
import 'package:meshnomad/utils/app_logger.dart';
import 'package:meshnomad/utils/platform_info.dart';
import 'package:meshnomad/widgets/app_bar.dart';
import 'package:meshnomad/widgets/mesh_screen_scaffold.dart';
import 'package:meshnomad/widgets/winda_message.dart';
import 'package:meshnomad/widgets/winda_overlay.dart';
import 'package:provider/provider.dart';

import '../connector/meshcore_connector.dart';
import '../l10n/l10n.dart';
import '../connector/meshcore_protocol.dart';
import '../models/contact.dart';
import '../l10n/contact_localization.dart';
import '../models/contact_group.dart';
import '../helpers/node_freshness.dart';
import '../models/translation_support.dart';
import '../services/app_settings_service.dart';
import '../services/ui_view_state_service.dart';
import '../theme/mesh_tokens.dart';
import '../utils/contact_search.dart';
import '../storage/contact_group_store.dart';
import '../utils/dialog_utils.dart';
import '../widgets/dotted_separator.dart';
import '../utils/disconnect_navigation_mixin.dart';
import '../utils/emoji_utils.dart';
import '../utils/last_seen_label.dart';
import '../utils/route_transitions.dart';
import '../widgets/list_filter_widget.dart';
import '../widgets/empty_state.dart';
import '../widgets/mesh_selection_sheet.dart';
import '../widgets/mesh_ui.dart';
import '../widgets/quick_style_picker_dialog.dart';
import '../widgets/quick_switch_bar.dart';
import '../widgets/repeater_login_dialog.dart';
import '../widgets/room_login_dialog.dart';
import '../widgets/unread_badge.dart';
import '../helpers/snack_bar_builder.dart';
import 'channels_screen.dart';
import 'chat_screen.dart';
import 'discovery_screen.dart';
import 'map_screen.dart';
import 'repeater_hub_screen.dart';
import 'settings_screen.dart';

enum RoomLoginDestination { chat, management }

enum ContactOperationType { import, export, zeroHopShare }

class ContactsScreen extends StatefulWidget {
  final bool hideBackButton;

  const ContactsScreen({super.key, this.hideBackButton = false});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen>
    with DisconnectNavigationMixin {
  final TextEditingController _searchController = TextEditingController();
  final ContactGroupStore _groupStore = ContactGroupStore();

  /// Backs the main contacts `ListView.builder` — lets GPS/Route badge taps
  /// (2026-08-19 refinement) restore the exact scroll position after the
  /// operator returns from viewing the map, instead of resetting to the top.
  final ScrollController _contactsScrollController = ScrollController();
  MeshCoreConnector? _scopeSyncConnector;
  List<ContactGroup> _groups = [];
  String _loadedGroupScopeKeyHex = '';
  Timer? _searchDebounce;

  final List<ContactOperationType> _pendingOperations = [];

  StreamSubscription<Uint8List>? _frameSubscription;

  // Lets the message winda (hosted above the Navigator, see
  // MeshScreenScaffold.extraTopOffset) stack below this screen's own search
  // field + floating progress winda, instead of overlapping them — measured
  // dynamically rather than hardcoded, since either can change height with
  // text-scaling/accessibility settings or a l10n string length change.
  final GlobalKey _searchFieldKey = GlobalKey();
  final GlobalKey _progressWindaKey = GlobalKey();
  double _extraTopOffset = 0;

  void _measureExtraTopOffset() {
    double heightOf(GlobalKey key) {
      final renderObject = key.currentContext?.findRenderObject();
      return (renderObject is RenderBox && renderObject.hasSize)
          ? renderObject.size.height
          : 0;
    }

    final measured = heightOf(_searchFieldKey) + heightOf(_progressWindaKey);
    if ((measured - _extraTopOffset).abs() > 0.5) {
      setState(() => _extraTopOffset = measured);
    }
  }

  @override
  void initState() {
    super.initState();
    _searchController.text = context
        .read<UiViewStateService>()
        .contactsSearchText;
    _loadGroups();
    _setupFrameListener();
    _clearAdvertNotifications();
  }

  void _clearAdvertNotifications() {
    final connector = context.read<MeshCoreConnector>();
    final contactIds = connector.contacts.map((c) => c.publicKeyHex).toList();
    NotificationService().clearAdvertNotifications(contactIds);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final connector = context.read<MeshCoreConnector>();
    if (!identical(_scopeSyncConnector, connector)) {
      _scopeSyncConnector?.removeListener(_handleConnectorScopeChange);
      _scopeSyncConnector = connector;
      _scopeSyncConnector?.addListener(_handleConnectorScopeChange);
    }
    _handleConnectorScopeChange();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _contactsScrollController.dispose();
    _frameSubscription?.cancel();
    _scopeSyncConnector?.removeListener(_handleConnectorScopeChange);
    super.dispose();
  }

  /// Pushes [route], preserving `_contactsScrollController`'s offset across
  /// the trip — captures it before navigating, restores it once the pushed
  /// route pops (2026-08-19: GPS/Route badge taps use this so leaving to
  /// view the map doesn't lose your place in a long contacts list).
  Future<void> _pushPreservingScroll(Route<void> route) async {
    final offset = _contactsScrollController.hasClients
        ? _contactsScrollController.offset
        : null;
    await Navigator.push(context, route);
    if (offset == null || !mounted || !_contactsScrollController.hasClients) {
      return;
    }
    final maxExtent = _contactsScrollController.position.maxScrollExtent;
    _contactsScrollController.jumpTo(offset.clamp(0.0, maxExtent));
  }

  void _handleConnectorScopeChange() {
    final connector = _scopeSyncConnector;
    if (connector == null) return;
    _syncGroupScopeIfNeeded(connector);
  }

  Future<void> _loadGroups() async {
    final selfPublicKeyHex = context.read<MeshCoreConnector>().selfPublicKeyHex;
    if (selfPublicKeyHex.isEmpty) {
      return;
    }
    _groupStore.setPublicKeyHex = selfPublicKeyHex;
    final groups = await _groupStore.loadGroups();
    if (!mounted) return;
    setState(() {
      _loadedGroupScopeKeyHex = selfPublicKeyHex;
      _groups = groups;
      _ensureValidSelectedGroup();
    });
  }

  Future<void> _saveGroups() async {
    final selfPublicKeyHex = context.read<MeshCoreConnector>().selfPublicKeyHex;
    if (selfPublicKeyHex.isEmpty) {
      return;
    }
    _groupStore.setPublicKeyHex = selfPublicKeyHex;
    await _groupStore.saveGroups(_groups);
  }

  bool _hasGroupStoreScope(MeshCoreConnector connector) {
    return connector.selfPublicKeyHex.isNotEmpty;
  }

  void _syncGroupScopeIfNeeded(MeshCoreConnector connector) {
    final selfPublicKeyHex = connector.selfPublicKeyHex;
    if (selfPublicKeyHex.isEmpty ||
        selfPublicKeyHex == _loadedGroupScopeKeyHex) {
      return;
    }
    _loadGroups();
  }

  void _showGroupsUnavailableMessage(BuildContext context) {
    showDismissibleSnackBar(
      context,
      content: Text(context.l10n.common_loading),
    );
  }

  void _setupFrameListener() {
    final connector = Provider.of<MeshCoreConnector>(context, listen: false);
    // Listen for incoming text messages from the repeater
    _frameSubscription = connector.receivedFrames.listen((frame) {
      if (frame.isEmpty) return;
      final frameBuffer = BufferReader(frame);
      try {
        final code = frameBuffer.readUInt8();

        if (code == respCodeExportContact) {
          final advertPacket = frameBuffer.readRemainingBytes();
          // Validate packet has expected minimum size (98+ bytes per protocol)
          if (advertPacket.length < 98) {
            if (mounted) {
              showDismissibleSnackBar(
                context,
                content: Text(context.l10n.contacts_invalidAdvertFormat),
              );
            }
            _pendingOperations.remove(ContactOperationType.export);
            return;
          }
          final hexString = pubKeyToHex(advertPacket);
          Clipboard.setData(ClipboardData(text: "meshcore://$hexString"));
        }

        // Generic OK/ERR acks carry no command correlation, so consume only
        // the oldest pending operation per ack instead of clearing all.
        if (code == respCodeOk) {
          if (!mounted) return;
          if (_pendingOperations.isEmpty) return;
          final op = _pendingOperations.removeAt(0);
          switch (op) {
            case ContactOperationType.import:
              showDismissibleSnackBar(
                context,
                content: Text(context.l10n.contacts_contactImported),
              );
            case ContactOperationType.zeroHopShare:
              showDismissibleSnackBar(
                context,
                content: Text(context.l10n.contacts_zeroHopContactAdvertSent),
              );
            case ContactOperationType.export:
              showDismissibleSnackBar(
                context,
                content: Text(context.l10n.contacts_contactAdvertCopied),
              );
          }
        }

        if (code == respCodeErr) {
          if (!mounted) return;
          if (_pendingOperations.isEmpty) return;
          final op = _pendingOperations.removeAt(0);
          switch (op) {
            case ContactOperationType.import:
              showDismissibleSnackBar(
                context,
                content: Text(context.l10n.contacts_contactImportFailed),
              );
            case ContactOperationType.zeroHopShare:
              showDismissibleSnackBar(
                context,
                content: Text(context.l10n.contacts_zeroHopContactAdvertFailed),
              );
            case ContactOperationType.export:
              showDismissibleSnackBar(
                context,
                content: Text(context.l10n.contacts_contactAdvertCopyFailed),
              );
          }
        }
      } catch (e) {
        appLogger.error(
          'Error processing received frame: $e',
          tag: 'ContactsScreen',
        );
      }
    });
  }

  Future<void> _contactExport(Uint8List pubKey) async {
    final connector = Provider.of<MeshCoreConnector>(context, listen: false);
    final exportContactFrame = buildExportContactFrame(pubKey);
    _pendingOperations.add(ContactOperationType.export);
    try {
      await connector.sendFrame(exportContactFrame, expectsGenericAck: true);
    } catch (e) {
      _pendingOperations.remove(ContactOperationType.export);
      if (mounted) {
        showDismissibleSnackBar(
          context,
          content: Text(context.l10n.contacts_contactAdvertCopyFailed),
        );
      }
    }
  }

  Future<void> _contactZeroHop(Uint8List pubKey) async {
    final connector = Provider.of<MeshCoreConnector>(context, listen: false);
    final exportContactZeroHopFrame = buildZeroHopContact(pubKey);
    _pendingOperations.add(ContactOperationType.zeroHopShare);
    try {
      await connector.sendFrame(
        exportContactZeroHopFrame,
        expectsGenericAck: true,
      );
    } catch (e) {
      _pendingOperations.remove(ContactOperationType.zeroHopShare);
      if (mounted) {
        showDismissibleSnackBar(
          context,
          content: Text(context.l10n.contacts_zeroHopContactAdvertFailed),
        );
      }
    }
  }

  Future<void> _contactImport() async {
    final connector = Provider.of<MeshCoreConnector>(context, listen: false);
    final clipboardData = await Clipboard.getData('text/plain');
    if (clipboardData == null || clipboardData.text == null) {
      if (mounted) {
        showDismissibleSnackBar(
          context,
          content: Text(context.l10n.contacts_clipboardEmpty),
        );
      }
      return;
    }
    final text = clipboardData.text!.trim();
    if (!text.startsWith('meshcore://')) {
      if (mounted) {
        showDismissibleSnackBar(
          context,
          content: Text(context.l10n.contacts_invalidAdvertFormat),
        );
      }
      return;
    }
    final hexString = text.substring('meshcore://'.length);
    final Uint8List importContactFrame;
    try {
      final bytes = hex2Uint8List(hexString);
      importContactFrame = buildImportContactFrame(bytes);
    } catch (e) {
      if (mounted) {
        showDismissibleSnackBar(
          context,
          content: Text(context.l10n.contacts_invalidAdvertFormat),
        );
      }
      return;
    }
    _pendingOperations.add(ContactOperationType.import);
    try {
      await connector.sendFrame(importContactFrame, expectsGenericAck: true);
    } catch (e) {
      _pendingOperations.remove(ContactOperationType.import);
      if (mounted) {
        showDismissibleSnackBar(
          context,
          content: Text(context.l10n.contacts_contactImportFailed),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _measureExtraTopOffset();
    });
    // 07-selection-bugs.md: SelectionArea scoped per-screen (not globally
    // above the Navigator) so "select all" can't sweep in text from other,
    // offstage routes still mounted via maintainState:true.
    return SelectionArea(child: _screenBody(context));
  }

  Widget _screenBody(BuildContext context) {
    final connector = context.watch<MeshCoreConnector>();

    // Auto-navigate back to scanner if disconnected
    if (!checkConnectionAndNavigate(connector)) {
      return const SizedBox.shrink();
    }

    final allowBack = !connector.isConnected;
    return PopScope(
      canPop: allowBack,
      child: MeshScreenScaffold(
        extraTopOffset: _extraTopOffset,
        messages: connector.contactSyncTimedOut
            ? [
                WindaMessage(
                  text: context.l10n.contacts_syncStalled,
                  tone: WindaMessageTone.error,
                  actionLabel: context.l10n.common_resync,
                  onAction: () => connector.getContacts(),
                ),
              ]
            : const [],
        appBar: meshMainAppBar(
          context,
          title: context.l10n.contacts_title,
          menuTooltip: context.l10n.contacts_moreOptions,
          menuItemBuilder: (context) => <PopupMenuEntry<dynamic>>[
            PopupMenuItem(
              child: Row(
                children: [
                  const Icon(Icons.person_add_rounded),
                  SizedBox(width: MeshTokens.of(context).spacingXs),
                  Text(context.l10n.discoveredContacts_Title),
                ],
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const DiscoveryScreen(),
                ),
              ),
            ),
            PopupMenuItem(
              child: Row(
                children: [
                  const Icon(Icons.paste),
                  SizedBox(width: MeshTokens.of(context).spacingXs),
                  Text(context.l10n.contacts_addContactFromClipboard),
                ],
              ),
              onTap: () => _contactImport(),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              child: Row(
                children: [
                  const Icon(Icons.connect_without_contact),
                  SizedBox(width: MeshTokens.of(context).spacingXs),
                  Text(context.l10n.contacts_zeroHopAdvert),
                ],
              ),
              onTap: () => {
                connector.sendSelfAdvert(flood: false),
                showDismissibleSnackBar(
                  context,
                  content: Text(context.l10n.settings_advertisementSent),
                ),
              },
            ),
            PopupMenuItem(
              child: Row(
                children: [
                  const Icon(Icons.cell_tower),
                  SizedBox(width: MeshTokens.of(context).spacingXs),
                  Text(context.l10n.contacts_floodAdvert),
                ],
              ),
              onTap: () => {
                connector.sendSelfAdvert(flood: true),
                showDismissibleSnackBar(
                  context,
                  content: Text(context.l10n.settings_advertisementSent),
                ),
              },
            ),
            PopupMenuItem(
              child: Row(
                children: [
                  const Icon(Icons.copy),
                  SizedBox(width: MeshTokens.of(context).spacingXs),
                  Text(context.l10n.contacts_copyAdvertToClipboard),
                ],
              ),
              onTap: () => _contactExport(Uint8List.fromList([])),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              child: Row(
                children: [
                  Icon(
                    Icons.logout,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  SizedBox(width: MeshTokens.of(context).spacingXs),
                  Text(context.l10n.common_disconnect),
                ],
              ),
              onTap: () => _disconnect(context, connector),
            ),
            PopupMenuItem(
              child: Row(
                children: [
                  const Icon(Icons.settings),
                  SizedBox(width: MeshTokens.of(context).spacingXs),
                  Text(context.l10n.settings_title),
                ],
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              ),
            ),
            PopupMenuItem(
              child: Row(
                children: [
                  const Icon(Icons.palette_outlined),
                  SizedBox(width: MeshTokens.of(context).spacingXs),
                  Text(context.l10n.appSettings_quickStyleMenuItem),
                ],
              ),
              onTap: () => showQuickStylePickerDialog(context),
            ),
          ],
        ),
        // NotificationListener, not just the post-frame measurement in
        // build(): the progress winda's own AnimatedSize (winda_overlay.dart)
        // animates internally without ever calling setState on this screen,
        // so a re-measurement scheduled only from this screen's own build()
        // would sit stale for however long it takes some UNRELATED
        // connector notification to next rebuild this screen — observed as
        // the message winda sitting several seconds too low after the
        // progress winda finished collapsing (2026-09-02 feedback).
        // SizeChangedLayoutNotifier (wrapping the measured content, added at
        // the same two spots as _progressWindaKey/_searchFieldKey) fires
        // this notification on every layout pass where the wrapped
        // subtree's size changed, including ones driven purely by an
        // internal animation.
        body: NotificationListener<SizeChangedLayoutNotification>(
          onNotification: (notification) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _measureExtraTopOffset();
            });
            return true;
          },
          child: _buildContactsBody(context, connector),
        ),
        // Group management FAB stacked above the add-contact FAB (2026-08-23
        // — moved off the top bar, same visual treatment via the app-wide
        // floatingActionButtonTheme tint). Distinct heroTags: Flutter throws
        // on two FloatingActionButtons sharing the default tag.
        floatingActionButton: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FloatingActionButton(
              heroTag: 'contacts_groups_fab',
              tooltip: context.l10n.contacts_groupsSheetTitle,
              onPressed: () => _showGroupManagementSheet(
                context,
                context.read<UiViewStateService>(),
                connector.contacts,
                _sortedGroups(),
              ),
              child: const Icon(Icons.group),
            ),
            SizedBox(height: MeshTokens.of(context).spacingXs),
            FloatingActionButton(
              heroTag: 'contacts_add_fab',
              onPressed: () => _showAddContactSheet(context),
              child: const Icon(Icons.person_add),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: QuickSwitchBar(
            selectedIndex: 0,
            onDestinationSelected: (index) =>
                _handleQuickSwitch(index, context),
            contactsUnreadCount: connector.getTotalContactsUnreadCount(),
            channelsUnreadCount: connector.getTotalChannelsUnreadCount(),
          ),
        ),
      ),
    );
  }

  void _showAddContactSheet(BuildContext context) {
    showMeshSheet(
      context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BottomSheetHeader(title: context.l10n.contacts_title),
            ListTile(
              leading: const Icon(Icons.paste),
              title: Text(context.l10n.contacts_addContactFromClipboard),
              onTap: () {
                Navigator.pop(sheetContext);
                _contactImport();
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_add_rounded),
              title: Text(context.l10n.discoveredContacts_Title),
              onTap: () {
                Navigator.pop(sheetContext);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DiscoveryScreen(),
                  ),
                );
              },
            ),
            SizedBox(height: MeshTokens.of(context).spacingXs),
          ],
        ),
      ),
    );
  }

  Future<void> _disconnect(
    BuildContext context,
    MeshCoreConnector connector,
  ) async {
    await showDisconnectDialog(context, connector);
  }

  ContactGroup? _selectedGroupForName(String selectedGroupName) {
    if (selectedGroupName == contactsAllGroupsValue) return null;
    for (final group in _groups) {
      if (group.name == selectedGroupName) return group;
    }
    return null;
  }

  /// Dedupes `_groups` by name (device can report the same group twice) and
  /// sorts alphabetically — shared by the groups sheet.
  List<ContactGroup> _sortedGroups() {
    final groupsByName = <String, ContactGroup>{};
    for (final group in _groups) {
      groupsByName.putIfAbsent(group.name, () => group);
    }
    return groupsByName.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  void _ensureValidSelectedGroup() {
    final viewState = context.read<UiViewStateService>();
    if (viewState.contactsSelectedGroupName == contactsAllGroupsValue) return;
    final exists = _groups.any(
      (group) => group.name == viewState.contactsSelectedGroupName,
    );
    if (!exists) {
      viewState.setContactsSelectedGroupName(contactsAllGroupsValue);
    }
  }

  Widget _buildFilterButton(
    BuildContext context,
    UiViewStateService viewState,
  ) {
    return ContactsFilterMenu(
      sortOption: viewState.contactsSortOption,
      typeFilter: viewState.contactsTypeFilter,
      showUnreadOnly: viewState.contactsShowUnreadOnly,
      onSortChanged: (value) {
        viewState.setContactsSortOption(value);
      },
      onTypeFilterChanged: (value) {
        viewState.setContactsTypeFilter(value);
      },
      onUnreadOnlyChanged: (value) {
        viewState.setContactsShowUnreadOnly(value);
      },
    );
  }

  // Bottom-sheet group management (2026-08-23) — replaces the old top-bar
  // PopupMenuButton. Behavior mirrors RepeaterCommandDrawer's draggable
  // multi-stop sheet; visuals go through showMeshSheet/BottomSheetHeader
  // (the color-picker sheet's chrome) instead of a raw terminal-skinned
  // Container. _showGroupEditor/_confirmDeleteGroup already self-guard on
  // _hasGroupStoreScope (showing _showGroupsUnavailableMessage themselves),
  // so this sheet calls them directly without re-checking.
  Future<void> _showGroupManagementSheet(
    BuildContext context,
    UiViewStateService viewState,
    List<Contact> contacts,
    List<ContactGroup> sortedGroups,
  ) {
    return showMeshSheet<void>(
      context,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.35,
        maxChildSize: 0.9,
        snap: true,
        snapSizes: const [0.35, 0.5, 0.9],
        expand: false,
        builder: (sheetContext, scrollController) {
          final scheme = Theme.of(sheetContext).colorScheme;
          final selectedGroupName =
              _selectedGroupForName(
                viewState.contactsSelectedGroupName,
              )?.name ??
              sheetContext.l10n.listFilter_all;

          Widget checkIfSelected(String name) => name == selectedGroupName
              ? Icon(Icons.check, color: scheme.primary)
              : const SizedBox.shrink();

          return Column(
            children: [
              BottomSheetHeader(
                title: sheetContext.l10n.contacts_groupsSheetTitle,
                trailing: IconButton(
                  tooltip: sheetContext.l10n.contacts_newGroup,
                  icon: const Icon(Icons.group_add),
                  onPressed: () => _showGroupEditor(sheetContext, contacts),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    ListTile(
                      title: Text(sheetContext.l10n.listFilter_all),
                      trailing: checkIfSelected(
                        sheetContext.l10n.listFilter_all,
                      ),
                      onTap: () {
                        viewState.setContactsSelectedGroupName(
                          contactsAllGroupsValue,
                        );
                        Navigator.of(sheetContext).maybePop();
                      },
                    ),
                    ...sortedGroups.map(
                      (group) => ListTile(
                        title: Text(group.name),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            checkIfSelected(group.name),
                            IconButton(
                              tooltip: sheetContext.l10n.contacts_editGroup,
                              icon: const Icon(Icons.edit, size: 20),
                              onPressed: () => _showGroupEditor(
                                sheetContext,
                                contacts,
                                group: group,
                              ),
                            ),
                            IconButton(
                              tooltip: sheetContext.l10n.contacts_deleteGroup,
                              icon: Icon(
                                Icons.delete,
                                size: 20,
                                color: scheme.error,
                              ),
                              onPressed: () =>
                                  _confirmDeleteGroup(sheetContext, group),
                            ),
                          ],
                        ),
                        onTap: () {
                          viewState.setContactsSelectedGroupName(group.name);
                          Navigator.of(sheetContext).maybePop();
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildContactsBody(BuildContext context, MeshCoreConnector connector) {
    final t = MeshTokens.of(context);
    final viewState = context.watch<UiViewStateService>();
    final contacts = connector.contacts;
    final waitingForInitialContacts =
        connector.isConnected &&
        !connector.hasLoadedContacts &&
        !connector.isLoadingContacts;
    final waitingForFirstContact =
        connector.isLoadingContacts && contacts.isEmpty;

    if (waitingForInitialContacts || waitingForFirstContact) {
      return Stack(
        children: [
          const Positioned.fill(
            child: Center(child: CircularProgressIndicator()),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: KeyedSubtree(
              key: _progressWindaKey,
              child: SizeChangedLayoutNotifier(
                child: MeshCard(
                  margin: EdgeInsets.zero,
                  padding: EdgeInsets.zero,
                  radius: 0,
                  color: Theme.of(context).colorScheme.surface,
                  child: WindaOverlay(
                    child: WindaProgress.fromConnector(connector, context.l10n),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (contacts.isEmpty && _groups.isEmpty) {
      return EmptyState(
        icon: Icons.people_outline,
        title: context.l10n.contacts_noContacts,
        subtitle: context.l10n.contacts_contactsWillAppear,
        action: FilledButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const DiscoveryScreen()),
          ),
          icon: const Icon(Icons.person_add_rounded),
          label: Text(context.l10n.discoveredContacts_Title),
        ),
      );
    }

    final filteredAndSorted = _filterAndSortContacts(
      contacts,
      connector,
      viewState,
    );

    String hintText = "";

    switch (viewState.contactsTypeFilter) {
      case ContactTypeFilter.all:
        hintText = context.l10n.contacts_searchContacts(
          filteredAndSorted.length,
          viewState.contactsShowUnreadOnly
              ? " ${context.l10n.contacts_unread}"
              : "",
        );
        break;
      case ContactTypeFilter.users:
        hintText = context.l10n.contacts_searchUsers(
          filteredAndSorted.length,
          viewState.contactsShowUnreadOnly
              ? " ${context.l10n.contacts_unread}"
              : "",
        );
        break;
      case ContactTypeFilter.repeaters:
        hintText = context.l10n.contacts_searchRepeaters(
          filteredAndSorted.length,
          viewState.contactsShowUnreadOnly
              ? " ${context.l10n.contacts_unread}"
              : "",
        );
        break;
      case ContactTypeFilter.rooms:
        hintText = context.l10n.contacts_searchRoomServers(
          filteredAndSorted.length,
          viewState.contactsShowUnreadOnly
              ? " ${context.l10n.contacts_unread}"
              : "",
        );
        break;
      case ContactTypeFilter.favorites:
        hintText = context.l10n.contacts_searchFavorites(
          filteredAndSorted.length,
          viewState.contactsShowUnreadOnly
              ? " ${context.l10n.contacts_unread}"
              : "",
        );
        break;
    }

    return Column(
      children: [
        KeyedSubtree(
          key: _searchFieldKey,
          child: MeshCard(
            margin: EdgeInsets.zero,
            padding: EdgeInsets.zero,
            radius: 0,
            color: Theme.of(context).colorScheme.surface,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: t.spacingXs,
                vertical: t.spacingSm,
              ),
              // Full-width search field — the group selector moved to its own
              // FAB + bottom sheet (2026-08-23), so it no longer shares this row.
              child: TextField(
                controller: _searchController,
                style: Theme.of(context).textTheme.bodyMedium,
                decoration: InputDecoration(
                  hintText: hintText,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (viewState.contactsSearchText.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchDebounce?.cancel();
                            _searchDebounce = null;
                            _searchController.clear();
                            context
                                .read<UiViewStateService>()
                                .setContactsSearchText('');
                          },
                        ),
                      _buildFilterButton(context, viewState),
                    ],
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: t.spacingMd,
                    vertical: t.spacingSm,
                  ),
                ),
                onChanged: (value) {
                  _searchDebounce?.cancel();
                  _searchDebounce = Timer(
                    const Duration(milliseconds: 300),
                    () {
                      if (!mounted) return;
                      context.read<UiViewStateService>().setContactsSearchText(
                        value,
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: RefreshIndicator(
                  onRefresh: () => connector.getContacts(),
                  child: filteredAndSorted.isEmpty
                      ? LayoutBuilder(
                          builder: (context, constraints) => ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: constraints.maxHeight,
                                ),
                                child: EmptyState(
                                  icon: Icons.search_off,
                                  title: viewState.contactsShowUnreadOnly
                                      ? context.l10n.contacts_noUnreadContacts
                                      : context.l10n.contacts_noContactsFound,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: _contactsScrollController,
                          // Was a size-special literal (88) reserved as FAB
                          // clearance — left a large dead gap between the last
                          // card and QuickSwitchBar once scrolled to the end
                          // (2026-08-29 on-device feedback: should read as a
                          // normal small bottom inset, not FAB-sized).
                          padding: EdgeInsets.only(
                            bottom: MeshTokens.of(context).spacingMd,
                          ),
                          itemCount: filteredAndSorted.length,
                          itemBuilder: (context, index) {
                            final contact = filteredAndSorted[index];
                            final unreadCount = connector
                                .getUnreadCountForContact(contact);
                            return _ContactTileEntrance(
                              index: index,
                              contact: contact,
                              pathHashByteWidth: connector.pathHashByteWidth,
                              lastSeen: _resolveLastSeen(contact),
                              unreadCount: unreadCount,
                              isFavorite: contact.isFavorite,
                              onTap: () => _openChat(context, contact),
                              onLongPress: () => _showContactOptions(
                                context,
                                connector,
                                contact,
                              ),
                              pushPreservingScroll: _pushPreservingScroll,
                            );
                          },
                        ),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: KeyedSubtree(
                  key: _progressWindaKey,
                  child: SizeChangedLayoutNotifier(
                    child: MeshCard(
                      margin: EdgeInsets.zero,
                      padding: EdgeInsets.zero,
                      radius: 0,
                      color: Theme.of(context).colorScheme.surface,
                      child: WindaOverlay(
                        child: WindaProgress.fromConnector(
                          connector,
                          context.l10n,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Contact> _filterAndSortContacts(
    List<Contact> contacts,
    MeshCoreConnector connector,
    UiViewStateService viewState,
  ) {
    var filtered = contacts.where((contact) {
      if (viewState.contactsSearchText.isEmpty) return true;
      return matchesContactQuery(contact, viewState.contactsSearchText);
    }).toList();

    final selectedGroup = _selectedGroupForName(
      viewState.contactsSelectedGroupName,
    );
    if (selectedGroup != null) {
      final memberKeys = selectedGroup.memberKeys.toSet();
      filtered = filtered
          .where((contact) => memberKeys.contains(contact.publicKeyHex))
          .toList();
    }

    // Filter out own node from the list
    if (connector.selfPublicKey != null) {
      final selfPubKeyHex = pubKeyToHex(connector.selfPublicKey!);
      filtered = filtered.where((contact) {
        return contact.publicKeyHex != selfPubKeyHex;
      }).toList();
    }

    if (viewState.contactsTypeFilter != ContactTypeFilter.all) {
      filtered = filtered
          .where(
            (contact) =>
                _matchesTypeFilter(contact, viewState.contactsTypeFilter),
          )
          .toList();
    }

    if (viewState.contactsShowUnreadOnly) {
      filtered = filtered.where((contact) {
        return connector.getUnreadCountForContact(contact) > 0;
      }).toList();
    }

    switch (viewState.contactsSortOption) {
      case ContactSortOption.lastSeen:
        filtered.sort(
          (a, b) => _resolveLastSeen(b).compareTo(_resolveLastSeen(a)),
        );
        break;
      case ContactSortOption.recentMessages:
        filtered.sort((a, b) {
          final aMessages = connector.getMessages(a);
          final bMessages = connector.getMessages(b);
          final aLastMsg = aMessages.isEmpty
              ? DateTime(1970)
              : aMessages.last.timestamp;
          final bLastMsg = bMessages.isEmpty
              ? DateTime(1970)
              : bMessages.last.timestamp;
          return bLastMsg.compareTo(aLastMsg);
        });
        break;
      case ContactSortOption.name:
        filtered.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
        break;
    }

    return filtered;
  }

  bool _matchesTypeFilter(Contact contact, ContactTypeFilter typeFilter) {
    switch (typeFilter) {
      case ContactTypeFilter.all:
        return true;
      case ContactTypeFilter.favorites:
        return contact.isFavorite;
      case ContactTypeFilter.users:
        return contact.type == advTypeChat;
      case ContactTypeFilter.repeaters:
        return contact.type == advTypeRepeater;
      case ContactTypeFilter.rooms:
        return contact.type == advTypeRoom;
    }
  }

  DateTime _resolveLastSeen(Contact contact) {
    if (contact.type != advTypeChat) return contact.lastSeen;
    return contact.lastMessageAt.isAfter(contact.lastSeen)
        ? contact.lastMessageAt
        : contact.lastSeen;
  }

  void _openChat(BuildContext context, Contact contact) {
    // Check if this is a repeater
    if (contact.type == advTypeRepeater) {
      _showRepeaterLogin(context, contact);
    } else if (contact.type == advTypeRoom) {
      _showRoomLogin(context, contact, RoomLoginDestination.chat);
    } else {
      final connector = context.read<MeshCoreConnector>();
      final unread = connector.getUnreadCountForContactKey(
        contact.publicKeyHex,
      );
      connector.markContactRead(contact.publicKeyHex);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              ChatScreen(contact: contact, initialUnreadCount: unread),
        ),
      );
    }
  }

  void _handleQuickSwitch(int index, BuildContext context) {
    if (index == 0) return;
    switch (index) {
      case 1:
        Navigator.pushReplacement(
          context,
          buildQuickSwitchRoute(const ChannelsScreen(hideBackButton: true)),
        );
        break;
      case 2:
        Navigator.pushReplacement(
          context,
          buildQuickSwitchRoute(const MapScreen(hideBackButton: true)),
        );
        break;
    }
  }

  void _showRepeaterLogin(BuildContext context, Contact repeater) {
    showDialog(
      context: context,
      builder: (context) => RepeaterLoginDialog(
        repeater: repeater,
        onLogin: (password, isAdmin) {
          // Navigate to repeater hub screen after successful login
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RepeaterHubScreen(
                repeater: repeater,
                password: password,
                isAdmin: isAdmin,
              ),
            ),
          );
        },
      ),
    );
  }

  void _showRoomLogin(
    BuildContext context,
    Contact room,
    RoomLoginDestination destination,
  ) {
    showDialog(
      context: context,
      builder: (context) => RoomLoginDialog(
        room: room,
        onLogin: (password, isAdmin) {
          final connector = context.read<MeshCoreConnector>();
          final unread = connector.getUnreadCountForContactKey(
            room.publicKeyHex,
          );
          connector.markContactRead(room.publicKeyHex);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  destination == RoomLoginDestination.management
                  ? RepeaterHubScreen(
                      repeater: room,
                      password: password,
                      isAdmin: isAdmin,
                    )
                  : ChatScreen(contact: room, initialUnreadCount: unread),
            ),
          );
        },
      ),
    );
  }

  void _confirmDeleteGroup(BuildContext context, ContactGroup group) {
    if (!_hasGroupStoreScope(context.read<MeshCoreConnector>())) {
      _showGroupsUnavailableMessage(context);
      return;
    }
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.contacts_deleteGroup),
        content: Text(context.l10n.contacts_deleteGroupConfirm(group.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.l10n.common_cancel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              setState(() {
                _groups.removeWhere((g) => g.name == group.name);
                _ensureValidSelectedGroup();
              });
              await _saveGroups();
            },
            child: Text(
              context.l10n.common_delete,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }

  void _showGroupEditor(
    BuildContext context,
    List<Contact> contacts, {
    ContactGroup? group,
  }) {
    if (!_hasGroupStoreScope(context.read<MeshCoreConnector>())) {
      _showGroupsUnavailableMessage(context);
      return;
    }
    final t = MeshTokens.of(context);
    final isEditing = group != null;
    final nameController = TextEditingController(text: group?.name ?? '');
    final selectedKeys = <String>{...group?.memberKeys ?? []};
    String filterQuery = '';
    // Type filter for the member picker (2026-08-23) — reuses the same
    // ContactTypeFilter enum and _matchesTypeFilter predicate as the main
    // Contacts list filter, instead of inventing separate logic.
    var typeFilter = ContactTypeFilter.all;
    final sortedContacts = List<Contact>.from(contacts)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (builderContext, setDialogState) {
          final filteredContacts = sortedContacts
              .where((contact) => _matchesTypeFilter(contact, typeFilter))
              .where(
                (contact) =>
                    filterQuery.isEmpty ||
                    matchesContactQuery(contact, filterQuery),
              )
              .toList();
          return AlertDialog(
            title: Text(
              isEditing
                  ? context.l10n.contacts_editGroup
                  : context.l10n.contacts_newGroup,
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: context.l10n.contacts_groupName,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: t.spacingSm),
                    TextField(
                      decoration: InputDecoration(
                        hintText: context.l10n.contacts_filterContacts,
                        prefixIcon: const Icon(Icons.search),
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (value) {
                        setDialogState(() {
                          filterQuery = value.toLowerCase();
                        });
                      },
                    ),
                    SizedBox(height: t.spacingSm),
                    DropdownButtonFormField<ContactTypeFilter>(
                      key: const ValueKey('groupEditorTypeFilter'),
                      initialValue: typeFilter,
                      decoration: InputDecoration(
                        labelText: context.l10n.listFilter_filters,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: [
                        DropdownMenuItem(
                          value: ContactTypeFilter.all,
                          child: Text(context.l10n.listFilter_all),
                        ),
                        DropdownMenuItem(
                          value: ContactTypeFilter.favorites,
                          child: Text(context.l10n.listFilter_favorites),
                        ),
                        DropdownMenuItem(
                          value: ContactTypeFilter.users,
                          child: Text(context.l10n.listFilter_users),
                        ),
                        DropdownMenuItem(
                          value: ContactTypeFilter.repeaters,
                          child: Text(context.l10n.listFilter_repeaters),
                        ),
                        DropdownMenuItem(
                          value: ContactTypeFilter.rooms,
                          child: Text(context.l10n.listFilter_roomServers),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() => typeFilter = value);
                      },
                    ),
                    SizedBox(height: t.spacingSm),
                    Expanded(
                      child: filteredContacts.isEmpty
                          ? Center(
                              child: Text(
                                context.l10n.contacts_noContactsMatchFilter,
                              ),
                            )
                          : ListView.builder(
                              itemCount: filteredContacts.length,
                              itemBuilder: (context, index) {
                                final contact = filteredContacts[index];
                                final isSelected = selectedKeys.contains(
                                  contact.publicKeyHex,
                                );
                                return CheckboxListTile(
                                  value: isSelected,
                                  title: Text(contact.name),
                                  subtitle: Text(
                                    contact.typeLabel(context.l10n),
                                  ),
                                  onChanged: (value) {
                                    setDialogState(() {
                                      if (value == true) {
                                        selectedKeys.add(contact.publicKeyHex);
                                      } else {
                                        selectedKeys.remove(
                                          contact.publicKeyHex,
                                        );
                                      }
                                    });
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(context.l10n.common_cancel),
              ),
              TextButton(
                onPressed: () async {
                  final name = nameController.text.trim();
                  if (name.isEmpty) {
                    showDismissibleSnackBar(
                      context,
                      content: Text(context.l10n.contacts_groupNameRequired),
                    );
                    return;
                  }
                  if (name.toLowerCase() ==
                      contactsAllGroupsValue.toLowerCase()) {
                    showDismissibleSnackBar(
                      context,
                      content: Text(context.l10n.contacts_groupNameReserved),
                    );
                    return;
                  }
                  final exists = _groups.any((g) {
                    if (isEditing && g.name == group.name) return false;
                    return g.name.toLowerCase() == name.toLowerCase();
                  });
                  if (exists) {
                    showDismissibleSnackBar(
                      context,
                      content: Text(
                        context.l10n.contacts_groupAlreadyExists(name),
                      ),
                    );
                    return;
                  }
                  setState(() {
                    final viewState = context.read<UiViewStateService>();
                    if (isEditing) {
                      final index = _groups.indexWhere(
                        (g) => g.name == group.name,
                      );
                      if (index != -1) {
                        final wasSelected =
                            viewState.contactsSelectedGroupName == group.name;
                        _groups[index] = ContactGroup(
                          name: name,
                          memberKeys: selectedKeys.toList(),
                        );
                        if (wasSelected) {
                          viewState.setContactsSelectedGroupName(name);
                        }
                      }
                    } else {
                      _groups.add(
                        ContactGroup(
                          name: name,
                          memberKeys: selectedKeys.toList(),
                        ),
                      );
                      viewState.setContactsSelectedGroupName(name);
                    }
                    _ensureValidSelectedGroup();
                  });
                  await _saveGroups();
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                  }
                },
                child: Text(
                  isEditing
                      ? context.l10n.common_save
                      : context.l10n.common_create,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showContactOptions(
    BuildContext context,
    MeshCoreConnector connector,
    Contact contact,
  ) {
    final t = MeshTokens.of(context);
    final isRepeater = contact.type == advTypeRepeater;
    final isRoom = contact.type == advTypeRoom;
    final isFavorite = contact.isFavorite;

    showMeshSheet(
      context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BottomSheetHeader(
              title: contact.name,
              subtitle: contact.typeLabel(context.l10n),
            ),
            if (isRepeater) ...[
              ListTile(
                leading: Icon(
                  Icons.radar,
                  color: MeshTokens.of(context).signal,
                ),
                title: Text(context.l10n.contacts_ping),
                onTap: () {
                  Navigator.pop(sheetContext);
                  final hw = context
                      .read<MeshCoreConnector>()
                      .pathHashByteWidth;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PathTraceMapScreen(
                        title: context.l10n.contacts_repeaterPing,
                        path: contact.pathBytesForDisplay.isNotEmpty
                            ? contact.pathBytesForDisplay
                            : _contactPathPrefix(contact, hw),
                        flipPathAround: true,
                        targetContact: contact,
                        pathHashByteWidth: hw,
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.cell_tower,
                  color: MeshTokens.of(context).warn,
                ),
                title: Text(context.l10n.contacts_manageRepeater),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showRepeaterLogin(context, contact);
                },
              ),
            ] else if (isRoom) ...[
              ListTile(
                leading: Icon(
                  Icons.radar,
                  color: MeshTokens.of(context).signal,
                ),
                title: Text(context.l10n.contacts_pathTrace),
                onTap: () {
                  Navigator.pop(sheetContext);
                  final hw = context
                      .read<MeshCoreConnector>()
                      .pathHashByteWidth;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PathTraceMapScreen(
                        title: contact.pathBytesForDisplay.isNotEmpty
                            ? context.l10n.contacts_roomPathTrace
                            : context.l10n.contacts_roomPing,
                        path: contact.pathBytesForDisplay.isNotEmpty
                            ? contact.pathBytesForDisplay
                            : _contactPathPrefix(contact, hw),
                        flipPathAround: true,
                        targetContact: contact,
                        pathHashByteWidth: hw,
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.meeting_room,
                  color: MeshTokens.of(context).primary,
                ),
                title: Text(context.l10n.contacts_roomLogin),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showRoomLogin(context, contact, RoomLoginDestination.chat);
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.room_preferences,
                  color: MeshTokens.of(context).warn,
                ),
                title: Text(context.l10n.room_management),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showRoomLogin(
                    context,
                    contact,
                    RoomLoginDestination.management,
                  );
                },
              ),
            ] else ...[
              if (contact.pathLength > 0)
                ListTile(
                  leading: Icon(
                    Icons.radar,
                    color: MeshTokens.of(context).signal,
                  ),
                  title: Text(context.l10n.contacts_chatTraceRoute),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    final hw = context
                        .read<MeshCoreConnector>()
                        .pathHashByteWidth;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PathTraceMapScreen(
                          title: context.l10n.contacts_pathTraceTo(
                            contact.name,
                          ),
                          path: contact.pathBytesForDisplay,
                          flipPathAround: true,
                          targetContact: contact,
                          pathHashByteWidth: hw,
                        ),
                      ),
                    );
                  },
                ),
            ],
            ListTile(
              leading: const Icon(Icons.route_outlined),
              title: Text(context.l10n.contacts_showAdvertPath),
              onTap: () async {
                Navigator.pop(sheetContext);
                final result = await connector.getAdvertPath(contact);
                if (!context.mounted) return;
                if (result == null) {
                  showDismissibleSnackBar(
                    context,
                    content: Text(context.l10n.contacts_advertPathNotFound),
                    duration: const Duration(seconds: 2),
                  );
                  return;
                }
                final hw = connector.pathHashByteWidth;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PathTraceMapScreen(
                      title: context.l10n.contacts_advertPathTraceTo(
                        contact.name,
                      ),
                      path: result.pathHash,
                      flipPathAround: true,
                      targetContact: contact,
                      pathHashByteWidth: hw,
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(
                isFavorite ? Icons.star : Icons.star_border,
                color: MeshTokens.of(context).warn,
              ),
              title: Text(
                isFavorite
                    ? context.l10n.listFilter_removeFromFavorites
                    : context.l10n.listFilter_addToFavorites,
              ),
              onTap: () async {
                Navigator.pop(sheetContext);
                await connector.setContactFlags(
                  contact,
                  isFavorite: !isFavorite,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: Text(context.l10n.contacts_ShareContact),
              onTap: () {
                Navigator.pop(sheetContext);
                _contactExport(contact.publicKey);
              },
            ),
            ListTile(
              leading: const Icon(Icons.connect_without_contact),
              title: Text(context.l10n.contacts_ShareContactZeroHop),
              onTap: () {
                Navigator.pop(sheetContext);
                _contactZeroHop(contact.publicKey);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.delete,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                context.l10n.contacts_deleteContact,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                _confirmDelete(context, connector, contact);
              },
            ),
            SizedBox(height: t.spacingXs),
          ],
        ),
      ),
    );
  }

  Uint8List _contactPathPrefix(Contact contact, int hashByteWidth) {
    if (contact.publicKey.isEmpty) return Uint8List(0);
    final width = hashByteWidth
        .clamp(1, pubKeySize)
        .toInt()
        .clamp(1, contact.publicKey.length)
        .toInt();
    return Uint8List.fromList(contact.publicKey.sublist(0, width));
  }

  void _confirmDelete(
    BuildContext context,
    MeshCoreConnector connector,
    Contact contact,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.contacts_deleteContact),
        content: Text(context.l10n.contacts_removeConfirm(contact.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.l10n.common_cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              connector.removeContact(contact);
            },
            child: Text(
              context.l10n.common_delete,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  final Contact contact;
  final int pathHashByteWidth;
  final DateTime lastSeen;
  final int unreadCount;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final Future<void> Function(Route<void> route) pushPreservingScroll;

  const _ContactTile({
    required this.contact,
    required this.pathHashByteWidth,
    required this.lastSeen,
    required this.unreadCount,
    required this.isFavorite,
    required this.onTap,
    required this.onLongPress,
    required this.pushPreservingScroll,
  });

  /// Node-type avatar color — delegates to [colorForContactType] (shared
  /// with [ContactTypeBadge] in mesh_ui.dart) so avatar and type-pill can
  /// never independently drift again (2026-08-19 refinement; they already
  /// had, for Sensor — see that function's doc comment).
  Color _avatarColor(BuildContext context) {
    return colorForContactType(MeshTokens.of(context), contact.type);
  }

  /// Node-type avatar icon. Returns null for chat nodes so AvatarCircle shows initials.
  IconData? _avatarIcon() {
    switch (contact.type) {
      case advTypeRepeater:
        return Icons.cell_tower;
      case advTypeRoom:
        return Icons.meeting_room;
      case advTypeSensor:
        return Icons.sensors;
      default:
        return null; // chat uses initials
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = MeshTokens.of(context);
    final emoji = firstEmoji(contact.name);
    final isChat = contact.type == advTypeChat;
    final pathLen = contact.pathBytesForDisplay.length;
    final hasPath = pathLen > 0 || contact.pathLength == 0;
    // Repeater/Room: the whole-tile tap is a login popup (_openChat's own
    // dispatch) — scoped to the avatar only as of 2026-08-19 (was
    // previously reachable from anywhere on the card). Chat/Sensor:
    // unchanged, whole-tile tap still opens ChatScreen via MeshCard.onTap
    // below.
    final needsAvatarLogin =
        contact.type == advTypeRepeater || contact.type == advTypeRoom;

    return GestureDetector(
      onSecondaryTapUp: PlatformInfo.isDesktop ? (_) => onLongPress() : null,
      child: MeshCard(
        onTap: needsAvatarLogin ? null : onTap,
        onLongPress: onLongPress,
        padding: EdgeInsets.all(t.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header: avatar + name + node-type pill (+ unread badge), all
            // vertically centered on the avatar (2026-08-20 refinement —
            // was CrossAxisAlignment.start, which top-aligned the avatar
            // against the old two-line Expanded content instead).
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Avatar — sole login tap-target for Repeater/Room (see
                // needsAvatarLogin above); inert tap-wise for Chat/Sensor,
                // whose login-equivalent (opening ChatScreen) is already the
                // whole tile's job via MeshCard.onTap.
                GestureDetector(
                  onTap: needsAvatarLogin ? onTap : null,
                  child: AvatarCircle(
                    name: contact.name,
                    size: 42,
                    color: isChat ? null : _avatarColor(context),
                    icon: _avatarIcon(),
                    emoji: emoji,
                    freshnessColor: freshnessOf(
                      lastSeen,
                    ).colorOf(MeshTokens.of(context)),
                  ),
                ),
                SizedBox(width: t.spacingSm),
                Expanded(
                  child: Text(
                    contact.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: unreadCount > 0
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                SizedBox(width: t.spacingXs),
                ContactTypeBadge(
                  type: contact.type,
                  label: contact.typeLabel(context.l10n),
                ),
                if (unreadCount > 0) ...[
                  SizedBox(width: t.spacingXs),
                  // Clamp text scale to prevent overflow next to the pill.
                  MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      textScaler: TextScaler.linear(
                        MediaQuery.textScalerOf(
                          context,
                        ).scale(1.0).clamp(1.0, 1.3),
                      ),
                    ),
                    child: UnreadBadge(count: unreadCount),
                  ),
                ],
              ],
            ),
            SizedBox(height: t.spacingSm),
            // Delicate rule (DottedSeparator, shared with chat bubble
            // footers) cutting the header off the status-badge row below it
            // — full card width, 2026-08-20 refinement.
            DottedSeparator(color: scheme.outlineVariant),
            // Same token as the card's own padding, so the gap above the
            // badge row always equals the card padding below it.
            SizedBox(height: t.spacingMd),
            // Fixed-order status badges (2026-08-19 accepted mockup:
            // .mockups/contact-tile-badges.html; moved below the header and
            // left-aligned to the full card width, labels at 3/4 size,
            // 2026-08-20 refinement:
            // .mockups/contact-tile-dashed-separator.html) — replaces the
            // old separate favorite star / location pin / path-label /
            // RouteChip elements with one consistent, always-rendered set
            // so a badge's position never depends on its state.
            ContactBadgeRow(
              isFavorite: isFavorite,
              hasLocation: contact.hasLocation,
              isSmazEnabled: context
                  .read<MeshCoreConnector>()
                  .isContactSmazEnabled(contact.publicKeyHex),
              routeLabel: hasPath
                  ? contact.pathLabel(
                      context.l10n,
                      pathHashByteWidth: pathHashByteWidth,
                    )
                  : null,
              languageCode: context
                  .watch<MeshCoreConnector>()
                  .getContactTranslationLanguage(contact.publicKeyHex),
              timeLabel: _formatLastSeen(context, lastSeen),
              isUnread: unreadCount > 0,
              isMuted: context.watch<AppSettingsService>().isContactMuted(
                contact.publicKeyHex,
              ),
              onLanguageTap: () =>
                  _showContactTranslationSheet(context, contact),
              onMuteTap: () {
                final settings = context.read<AppSettingsService>();
                if (settings.isContactMuted(contact.publicKeyHex)) {
                  settings.unmuteContact(contact.publicKeyHex);
                } else {
                  settings.muteContact(contact.publicKeyHex);
                }
              },
              onFavoriteTap: () {
                context.read<MeshCoreConnector>().setContactFlags(
                  contact,
                  isFavorite: !isFavorite,
                );
              },
              onGpsTap: () => pushPreservingScroll(
                MaterialPageRoute(
                  builder: (context) => ContactLocationMapScreen(
                    position: LatLng(
                      contact.latitude ?? 0.0,
                      contact.longitude ?? 0.0,
                    ),
                    contactName: contact.name,
                  ),
                ),
              ),
              onRouteTap: () => pushPreservingScroll(
                MaterialPageRoute(
                  builder: (context) => PathTraceMapScreen(
                    title: context.l10n.contacts_pathTraceTo(contact.name),
                    path: contact.pathBytesForDisplay,
                    flipPathAround: true,
                    targetContact: contact,
                    pathHashByteWidth: pathHashByteWidth,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatLastSeen(BuildContext context, DateTime lastSeen) =>
      formatLastSeenLabel(context, lastSeen);

  Future<void> _showContactTranslationSheet(
    BuildContext context,
    Contact contact,
  ) async {
    final connector = context.read<MeshCoreConnector>();
    final l10n = context.l10n;
    final result = await showMeshSelectionSheet<String?>(
      context,
      title: l10n.translation_messageTranslation,
      subtitle: contact.name,
      toggleTitle: l10n.translation_translateBeforeSending,
      toggleSubtitle: l10n.translation_composerEnabledHint,
      toggleValue: connector.isContactTranslateBeforeSending(
        contact.publicKeyHex,
      ),
      selectedValue: connector.getContactTranslationLanguage(
        contact.publicKeyHex,
      ),
      options: [
        MeshSelectionOption<String?>(
          value: null,
          label: l10n.translation_useAppLanguage,
        ),
        for (final option in supportedTranslationLanguages)
          MeshSelectionOption<String?>(
            value: option.code,
            label: option.label,
            trailing: option.code.toUpperCase(),
          ),
      ],
    );
    if (result == null) return;
    await connector.setContactTranslation(
      contact.publicKeyHex,
      languageCode: result.value,
      translateBeforeSending: result.toggleValue ?? false,
    );
  }
}

// Wrap each contact tile with staggered entrance.
class _ContactTileEntrance extends StatelessWidget {
  final int index;
  final Contact contact;
  final int pathHashByteWidth;
  final DateTime lastSeen;
  final int unreadCount;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final Future<void> Function(Route<void> route) pushPreservingScroll;

  const _ContactTileEntrance({
    required this.index,
    required this.contact,
    required this.pathHashByteWidth,
    required this.lastSeen,
    required this.unreadCount,
    required this.isFavorite,
    required this.onTap,
    required this.onLongPress,
    required this.pushPreservingScroll,
  });

  @override
  Widget build(BuildContext context) {
    return ListEntrance(
      index: index,
      child: _ContactTile(
        contact: contact,
        pathHashByteWidth: pathHashByteWidth,
        lastSeen: lastSeen,
        unreadCount: unreadCount,
        isFavorite: isFavorite,
        onTap: onTap,
        onLongPress: onLongPress,
        pushPreservingScroll: pushPreservingScroll,
      ),
    );
  }
}
