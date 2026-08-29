import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:meshnomad/storage/channel_message_store.dart';
import 'package:meshnomad/utils/keys.dart';
import 'package:meshnomad/utils/platform_info.dart';
import 'package:meshnomad/widgets/app_bar.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../connector/meshcore_connector.dart';
import '../l10n/l10n.dart';
import '../services/app_settings_service.dart';
import '../services/ui_view_state_service.dart';
import '../models/channel.dart';
import '../models/community.dart';
import '../models/translation_support.dart';
import '../storage/community_store.dart';
import '../theme/mesh_tokens.dart';
import '../utils/dialog_utils.dart';
import '../utils/disconnect_navigation_mixin.dart';
import '../utils/last_seen_label.dart';
import '../utils/route_transitions.dart';
import '../widgets/dotted_separator.dart';
import '../widgets/list_filter_widget.dart';
import '../widgets/empty_state.dart';
import '../widgets/mesh_selection_sheet.dart';
import '../widgets/mesh_ui.dart';
import '../widgets/qr_code_display.dart';
import '../widgets/quick_style_picker_dialog.dart';
import '../widgets/quick_switch_bar.dart';
import '../widgets/unread_badge.dart';
import '../helpers/gif_helper.dart';
import '../helpers/snack_bar_builder.dart';
import 'channel_chat_screen.dart';
import 'community_qr_scanner_screen.dart';
import 'contacts_screen.dart';
import 'map_screen.dart';
import 'settings_screen.dart';
import '../widgets/mesh_dashed_divider.dart';

class ChannelsScreen extends StatefulWidget {
  final bool hideBackButton;

  const ChannelsScreen({super.key, this.hideBackButton = false});

  @override
  State<ChannelsScreen> createState() => _ChannelsScreenState();
}

class _ChannelsScreenState extends State<ChannelsScreen>
    with DisconnectNavigationMixin {
  final TextEditingController _searchController = TextEditingController();
  final CommunityStore _communityStore = CommunityStore();
  final CommunityPskIndex _communityIndex = CommunityPskIndex();
  List<Community> _communities = [];
  Timer? _searchDebounce;

  ChannelMessageStore get _channelMessageStore => ChannelMessageStore();

  @override
  void initState() {
    super.initState();
    _searchController.text = context
        .read<UiViewStateService>()
        .channelsSearchText;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MeshCoreConnector>().getChannels();
      _loadCommunities();
    });
  }

  Future<void> _loadCommunities() async {
    final connector = context.read<MeshCoreConnector>();
    _communityStore.setPublicKeyHex = connector.selfPublicKeyHex;
    final communities = await _communityStore.loadCommunities();
    if (mounted) {
      setState(() {
        _communities = communities;
        _communityIndex.initialize(communities);
      });
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 07-selection-bugs.md: SelectionArea scoped per-screen (not globally
    // above the Navigator) so "select all" can't sweep in text from other,
    // offstage routes still mounted via maintainState:true.
    return SelectionArea(child: _screenBody(context));
  }

  Widget _screenBody(BuildContext context) {
    final connector = context.watch<MeshCoreConnector>();
    final viewState = context.watch<UiViewStateService>();

    final channelMessageStore = ChannelMessageStore();
    channelMessageStore.setPublicKeyHex = connector.selfPublicKeyHex;

    // Auto-navigate back to scanner if disconnected
    if (!checkConnectionAndNavigate(connector)) {
      return const SizedBox.shrink();
    }

    final allowBack = !connector.isConnected;

    return PopScope(
      canPop: allowBack,
      child: Scaffold(
        appBar: meshMainAppBar(
          context,
          title: context.l10n.channels_title,
          // onTap handlers run after the menu route pops, so they must
          // capture the screen's context — not the itemBuilder's menu
          // context, which is deactivated by then.
          menuItemBuilder: (menuContext) => [
            PopupMenuItem(
              child: Row(
                children: [
                  Icon(
                    Icons.logout,
                    color: Theme.of(menuContext).colorScheme.error,
                  ),
                  SizedBox(width: MeshTokens.of(menuContext).spacingXs),
                  Text(menuContext.l10n.common_disconnect),
                ],
              ),
              onTap: () => _disconnect(context),
            ),
            PopupMenuItem(
              child: Row(
                children: [
                  const Icon(Icons.groups),
                  SizedBox(width: MeshTokens.of(menuContext).spacingXs),
                  Text(menuContext.l10n.community_manageCommunities),
                ],
              ),
              onTap: () => _showManageCommunitiesDialog(context),
            ),
            PopupMenuItem(
              child: Row(
                children: [
                  const Icon(Icons.settings),
                  SizedBox(width: MeshTokens.of(menuContext).spacingXs),
                  Text(menuContext.l10n.settings_title),
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
                  SizedBox(width: MeshTokens.of(menuContext).spacingXs),
                  Text(menuContext.l10n.appSettings_quickStyleMenuItem),
                ],
              ),
              onTap: () => showQuickStylePickerDialog(context),
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: () async {
            await context.read<MeshCoreConnector>().getChannels(force: true);
          },
          child: () {
            final channels = connector.channels;
            final waitingForFirstChannel =
                connector.isLoadingChannels && channels.isEmpty;

            // Only block the list while the first channel is actively loading.
            // If the initial sync aborts, show cached/partial channels instead
            // of trapping the user behind an idle spinner.
            if (waitingForFirstChannel) {
              return const Center(child: CircularProgressIndicator());
            }

            if (channels.isEmpty) {
              return ListView(
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height - 200,
                    child: EmptyState(
                      icon: Icons.tag,
                      title: context.l10n.channels_noChannelsConfigured,
                      action: FilledButton.icon(
                        onPressed: () => _addPublicChannel(context, connector),
                        icon: const Icon(Icons.public),
                        label: Text(context.l10n.channels_addPublicChannel),
                      ),
                    ),
                  ),
                ],
              );
            }

            final filteredChannels = _filterAndSortChannels(
              channels,
              connector,
              viewState,
            );

            return Column(
              children: [
                Padding(
                  padding: EdgeInsets.all(MeshTokens.of(context).spacingXs),
                  child: TextField(
                    controller: _searchController,
                    style: Theme.of(context).textTheme.bodyMedium,
                    decoration: InputDecoration(
                      hintText: context.l10n.channels_searchChannels,
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (viewState.channelsSearchText.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchDebounce?.cancel();
                                _searchDebounce = null;
                                _searchController.clear();
                                context
                                    .read<UiViewStateService>()
                                    .setChannelsSearchText('');
                              },
                            ),
                          _buildFilterButton(viewState),
                        ],
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: MeshTokens.of(context).spacingMd,
                        vertical: MeshTokens.of(context).spacingSm,
                      ),
                    ),
                    onChanged: (value) {
                      _searchDebounce?.cancel();
                      _searchDebounce = Timer(
                        const Duration(milliseconds: 300),
                        () {
                          if (!mounted) return;
                          context
                              .read<UiViewStateService>()
                              .setChannelsSearchText(value);
                        },
                      );
                    },
                  ),
                ),
                Expanded(
                  child: filteredChannels.isEmpty
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
                                  title: context.l10n.channels_noChannelsFound,
                                ),
                              ),
                            ],
                          ),
                        )
                      : (viewState.channelsSortOption ==
                                ChannelSortOption.manual &&
                            viewState.channelsSearchText.isEmpty &&
                            // Reordering a filtered subset would persist a
                            // partial order — drag mode needs the full list.
                            viewState.channelsTypeFilter ==
                                ChannelTypeFilter.all &&
                            !viewState.channelsShowUnreadOnly)
                      ? ReorderableListView.builder(
                          // Insets match the contacts list exactly
                          // (2026-08-29): no extra top padding (the search
                          // field's own 16 inset provides the gap — the
                          // first card must start at the same height as on
                          // Contacts), small bottom inset instead of the
                          // old FAB-sized 88 literal.
                          padding: EdgeInsets.only(
                            bottom: MeshTokens.of(context).spacingMd,
                          ),
                          buildDefaultDragHandles: false,
                          itemCount: filteredChannels.length,
                          onReorderItem: (oldIndex, newIndex) {
                            final reordered = List<Channel>.from(
                              filteredChannels,
                            );
                            final item = reordered.removeAt(oldIndex);
                            reordered.insert(newIndex, item);
                            unawaited(
                              connector.setChannelOrder(
                                reordered.map((c) => c.index).toList(),
                              ),
                            );
                          },
                          itemBuilder: (context, index) {
                            final channel = filteredChannels[index];
                            return _buildChannelTile(
                              context,
                              connector,
                              channelMessageStore,
                              channel,
                              showDragHandle: true,
                              dragIndex: index,
                              listIndex: index,
                            );
                          },
                        )
                      : ListView.builder(
                          // Same insets as above.
                          padding: EdgeInsets.only(
                            bottom: MeshTokens.of(context).spacingMd,
                          ),
                          itemCount: filteredChannels.length,
                          itemBuilder: (context, index) {
                            final channel = filteredChannels[index];
                            return _buildChannelTile(
                              context,
                              connector,
                              channelMessageStore,
                              channel,
                              listIndex: index,
                            );
                          },
                        ),
                ),
              ],
            );
          }(),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showAddChannelDialog(context),
          tooltip: context.l10n.channels_addChannel,
          child: const Icon(Icons.add),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: QuickSwitchBar(
            selectedIndex: 1,
            onDestinationSelected: (index) =>
                _handleQuickSwitch(index, context),
            contactsUnreadCount: connector.getTotalContactsUnreadCount(),
            channelsUnreadCount: connector.getTotalChannelsUnreadCount(),
          ),
        ),
      ),
    );
  }

  Widget _buildChannelTile(
    BuildContext context,
    MeshCoreConnector connector,
    ChannelMessageStore channelMessageStore,
    Channel channel, {
    bool showDragHandle = false,
    int? dragIndex,
    int listIndex = 0,
  }) {
    final unreadCount = connector.getUnreadCountForChannel(channel);
    final isMuted = context.watch<AppSettingsService>().isChannelMuted(
      channel.name,
    );
    final scheme = Theme.of(context).colorScheme;
    final t = MeshTokens.of(context);

    // Determine icon, colors and the header type-pill label per channel type
    IconData icon;
    Color iconColor;
    String typeLabel;
    final ChannelType channelType = Channel.getChannelType(
      channel,
      _communityIndex,
    );
    final bool isCommunityChannel = Channel.isCommunityChannel(channelType);
    switch (channelType) {
      case ChannelType.communityPublic:
      case ChannelType.communityHashtag:
        icon = Icons.groups;
        iconColor = t.secondary;
        typeLabel = context.l10n.channelType_community;
      case ChannelType.public:
        icon = Icons.public;
        iconColor = t.signal;
        typeLabel = context.l10n.channelType_public;
      case ChannelType.hashtag:
        icon = Icons.tag;
        iconColor = t.primary;
        typeLabel = context.l10n.channelType_hashtag;
      case ChannelType.private:
        icon = Icons.lock;
        iconColor = t.primary;
        typeLabel = context.l10n.channelType_private;
    }

    // Last message preview
    final messages = connector.getChannelMessages(channel);
    final lastMessage = messages.isNotEmpty ? messages.last : null;
    final lastMessageText = lastMessage?.text ?? '';
    final lastPreview =
        lastMessageText.isNotEmpty &&
            GifHelper.parseGif(lastMessageText) != null
        ? context.l10n.chat_receivedGif
        : lastMessageText;
    final lastTime = lastMessage?.timestamp;

    final channelLabel = channel.name.isEmpty
        ? context.l10n.channels_channelIndex(channel.index)
        : channel.name;

    final isFavorite = connector.isChannelFavorite(channel.index);
    final channelLang = connector.getChannelTranslationLanguage(channel.index);
    final hasRegion = connector.hasChannelRegion(channel.index);

    // 2026-08-29 channel-card parity redesign (accepted mockup
    // .mockups/channel-card-parity.html, wariant 3b): same geometry as the
    // contact card — default MeshCard margin, uniform spacingMd padding,
    // header centered on the avatar with a type pill, DottedSeparator, then
    // a fixed-order badge row (CH → REGION → TIME, always rendered, ghosted
    // when inactive) with translate/mute/favorite icons on the right, and a
    // one-line last-message quote in the stepper value-pill style below.
    return ListEntrance(
      key: ValueKey('channel_entrance_${channel.index}'),
      index: dragIndex ?? listIndex,
      child: MeshCard(
        key: ValueKey('channel_${channel.index}'),
        padding: EdgeInsets.all(t.spacingMd),
        onTap: () {
          HapticFeedback.selectionClick();
          final unread = connector.getUnreadCountForChannelIndex(channel.index);
          connector.markChannelRead(channel.index);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChannelChatScreen(
                channel: channel,
                initialUnreadCount: unread,
              ),
            ),
          );
        },
        onLongPress: () => _showChannelActions(
          this.context,
          connector,
          channelMessageStore,
          channel,
        ),
        onSecondaryTap: PlatformInfo.isDesktop
            ? () => _showChannelActions(
                this.context,
                connector,
                channelMessageStore,
                channel,
              )
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AvatarCircle(
                      name: channelLabel,
                      size: 42,
                      color: iconColor,
                      icon: icon,
                    ),
                    if (isCommunityChannel)
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: t.secondary,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: scheme.surfaceContainerLow,
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            Icons.people,
                            size: 8,
                            color: t.secondaryInk,
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(width: t.spacingSm),
                Expanded(
                  child: Text(
                    channelLabel,
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
                MeshTypePill(label: typeLabel, color: iconColor),
                if (unreadCount > 0) ...[
                  SizedBox(width: t.spacingXs),
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
                if (showDragHandle && dragIndex != null) ...[
                  SizedBox(width: t.spacingXxs),
                  ReorderableDragStartListener(
                    index: dragIndex,
                    child: Padding(
                      padding: EdgeInsets.only(left: t.spacingXs),
                      child: Icon(
                        Icons.drag_handle,
                        size: 18,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            SizedBox(height: t.spacingSm),
            DottedSeparator(color: scheme.outlineVariant),
            // Same token as the card's own padding — gap above the badge row
            // equals the card padding below it (contact-card rule).
            SizedBox(height: t.spacingMd),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: t.spacingXxs,
                    runSpacing: t.spacingXxs,
                    children: [
                      MeshStatusBadge(
                        label: 'CH ${channel.index}',
                        color: scheme.onSurfaceVariant,
                        active: true,
                      ),
                      MeshStatusBadge(
                        label: hasRegion
                            ? connector.getChannelRegion(channel.index)
                            : context.l10n.channels_badgeRegion,
                        color: t.routeActive,
                        active: hasRegion,
                        fillColor: hasRegion
                            ? t.routeActive.withValues(alpha: 0.2)
                            : null,
                      ),
                      MeshStatusBadge(
                        label: 'Smaz',
                        color: scheme.onSurfaceVariant,
                        active: connector.isChannelSmazEnabled(channel.index),
                      ),
                      // Per-channel translation language (2026-08-29,
                      // replaces the translate icon; moved into the pill row
                      // between SMAZ and TIME per user feedback): the
                      // channel's assigned 2-letter code, ghosted "AUTO"
                      // when inheriting the app-wide setting; always
                      // tappable — shortcut to the language selection sheet
                      // for THIS channel only.
                      MeshStatusBadge(
                        label: channelLang?.toUpperCase() ?? 'AUTO',
                        color: t.primary,
                        active: channelLang != null,
                        fillColor: channelLang != null
                            ? t.primary.withValues(alpha: 0.2)
                            : null,
                        onTap: () => _showChannelTranslationSheet(
                          this.context,
                          connector,
                          channel,
                          channelLabel,
                        ),
                      ),
                      MeshStatusBadge(
                        label: lastTime != null
                            ? formatLastSeenLabel(context, lastTime)
                            : '—',
                        color: unreadCount > 0
                            ? t.primary
                            : scheme.onSurfaceVariant,
                        active: lastTime != null,
                        fillColor: lastTime != null
                            ? (unreadCount > 0
                                      ? t.primary
                                      : scheme.onSurfaceVariant)
                                  .withValues(alpha: 0.2)
                            : null,
                      ),
                    ],
                  ),
                ),
                SizedBox(width: t.spacingXxs),
                GestureDetector(
                  onTap: () {
                    final settings = context.read<AppSettingsService>();
                    if (isMuted) {
                      settings.unmuteChannel(channel.name);
                    } else {
                      settings.muteChannel(channel.name);
                    }
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Opacity(
                    opacity: isMuted ? 1.0 : 0.30,
                    child: Icon(
                      isMuted ? Icons.notifications_off : Icons.notifications,
                      size: 18,
                      color: t.warn,
                    ),
                  ),
                ),
                SizedBox(width: t.spacingXxs),
                GestureDetector(
                  onTap: () =>
                      connector.setChannelFavorite(channel.index, !isFavorite),
                  behavior: HitTestBehavior.opaque,
                  child: Opacity(
                    opacity: isFavorite ? 1.0 : 0.30,
                    child: Icon(
                      isFavorite ? Icons.star : Icons.star_border,
                      size: 18,
                      color: t.warn,
                    ),
                  ),
                ),
              ],
            ),
            if (lastPreview.isNotEmpty) ...[
              SizedBox(height: t.spacingSm),
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  horizontal: t.spacingMd,
                  vertical: t.spacingXxs + 2,
                ),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(t.sm),
                ),
                child: Text(
                  lastPreview,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.mono(fontSize: 12, color: scheme.primary),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showChannelTranslationSheet(
    BuildContext context,
    MeshCoreConnector connector,
    Channel channel,
    String channelLabel,
  ) async {
    final l10n = context.l10n;
    final result = await showMeshSelectionSheet<String?>(
      context,
      title: l10n.translation_messageTranslation,
      subtitle: channelLabel,
      toggleTitle: l10n.translation_translateBeforeSending,
      toggleSubtitle: l10n.translation_composerEnabledHint,
      toggleValue: connector.isChannelTranslateBeforeSending(channel.index),
      selectedValue: connector.getChannelTranslationLanguage(channel.index),
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
    await connector.setChannelTranslation(
      channel.index,
      languageCode: result.value,
      translateBeforeSending: result.toggleValue ?? false,
    );
  }

  void _showChannelActions(
    BuildContext context,
    MeshCoreConnector connector,
    ChannelMessageStore channelMessageStore,
    Channel channel,
  ) {
    final parentContext = context;
    final settingsService = context.read<AppSettingsService>();
    final isMuted = settingsService.isChannelMuted(channel.name);

    showModalBottomSheet(
      context: parentContext,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(sheetContext.l10n.channels_editChannel),
              onTap: () async {
                Navigator.pop(sheetContext);
                await Future.delayed(const Duration(milliseconds: 100));
                if (parentContext.mounted) {
                  _showEditChannelDialog(parentContext, connector, channel);
                }
              },
            ),
            ListTile(
              leading: Icon(
                isMuted
                    ? Icons.notifications_outlined
                    : Icons.notifications_off_outlined,
              ),
              title: Text(
                isMuted
                    ? sheetContext.l10n.channels_unmuteChannel
                    : sheetContext.l10n.channels_muteChannel,
              ),
              onTap: () async {
                Navigator.pop(sheetContext);
                if (isMuted) {
                  await settingsService.unmuteChannel(channel.name);
                } else {
                  await settingsService.muteChannel(channel.name);
                }
              },
            ),
            ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: Theme.of(sheetContext).colorScheme.error,
              ),
              title: Text(
                sheetContext.l10n.channels_deleteChannel,
                style: TextStyle(
                  color: Theme.of(sheetContext).colorScheme.error,
                ),
              ),
              onTap: () async {
                Navigator.pop(sheetContext);
                await Future.delayed(const Duration(milliseconds: 100));
                if (parentContext.mounted) {
                  _confirmDeleteChannel(
                    parentContext,
                    connector,
                    channelMessageStore,
                    channel,
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _handleQuickSwitch(int index, BuildContext context) {
    if (index == 1) return;
    switch (index) {
      case 0:
        Navigator.pushReplacement(
          context,
          buildQuickSwitchRoute(const ContactsScreen(hideBackButton: true)),
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

  Future<void> _disconnect(BuildContext context) async {
    final connector = context.read<MeshCoreConnector>();
    await showDisconnectDialog(context, connector);
  }

  Widget _buildFilterButton(UiViewStateService viewState) {
    // Sort + Filters, parity with the contacts menu (2026-08-29) — the
    // filter set matches what channels actually are: favorites + the four
    // channel types + unread-only.
    return SortFilterMenu<_ChannelsFilterAction>(
      tooltip: context.l10n.listFilter_tooltip,
      sections: [
        SortFilterMenuSection<_ChannelsFilterAction>(
          title: context.l10n.channels_sortBy,
          options: [
            SortFilterMenuOption(
              value: const _ChannelSortAction(ChannelSortOption.manual),
              label: context.l10n.channels_sortManual,
              checked: viewState.channelsSortOption == ChannelSortOption.manual,
            ),
            SortFilterMenuOption(
              value: const _ChannelSortAction(ChannelSortOption.name),
              label: context.l10n.channels_sortAZ,
              checked: viewState.channelsSortOption == ChannelSortOption.name,
            ),
            SortFilterMenuOption(
              value: const _ChannelSortAction(ChannelSortOption.latestMessages),
              label: context.l10n.channels_sortLatestMessages,
              checked:
                  viewState.channelsSortOption ==
                  ChannelSortOption.latestMessages,
            ),
            SortFilterMenuOption(
              value: const _ChannelSortAction(ChannelSortOption.unread),
              label: context.l10n.channels_sortUnread,
              checked: viewState.channelsSortOption == ChannelSortOption.unread,
            ),
          ],
        ),
        SortFilterMenuSection<_ChannelsFilterAction>(
          title: context.l10n.listFilter_filters,
          options: [
            SortFilterMenuOption(
              value: const _ChannelTypeFilterAction(ChannelTypeFilter.all),
              label: context.l10n.listFilter_all,
              checked: viewState.channelsTypeFilter == ChannelTypeFilter.all,
            ),
            SortFilterMenuOption(
              value: const _ChannelTypeFilterAction(
                ChannelTypeFilter.favorites,
              ),
              label: context.l10n.listFilter_favorites,
              checked:
                  viewState.channelsTypeFilter == ChannelTypeFilter.favorites,
            ),
            SortFilterMenuOption(
              value: const _ChannelTypeFilterAction(ChannelTypeFilter.public),
              label: context.l10n.channelType_public,
              checked: viewState.channelsTypeFilter == ChannelTypeFilter.public,
            ),
            SortFilterMenuOption(
              value: const _ChannelTypeFilterAction(ChannelTypeFilter.hashtag),
              label: context.l10n.channelType_hashtag,
              checked:
                  viewState.channelsTypeFilter == ChannelTypeFilter.hashtag,
            ),
            SortFilterMenuOption(
              value: const _ChannelTypeFilterAction(ChannelTypeFilter.private),
              label: context.l10n.channelType_private,
              checked:
                  viewState.channelsTypeFilter == ChannelTypeFilter.private,
            ),
            SortFilterMenuOption(
              value: const _ChannelTypeFilterAction(
                ChannelTypeFilter.community,
              ),
              label: context.l10n.channelType_community,
              checked:
                  viewState.channelsTypeFilter == ChannelTypeFilter.community,
            ),
            SortFilterMenuOption(
              value: const _ChannelToggleUnreadAction(),
              label: context.l10n.listFilter_unreadOnly,
              checked: viewState.channelsShowUnreadOnly,
              isToggle: true,
            ),
          ],
        ),
      ],
      onSelected: (action) {
        switch (action) {
          case _ChannelSortAction(:final option):
            viewState.setChannelsSortOption(option);
          case _ChannelTypeFilterAction(:final filter):
            viewState.setChannelsTypeFilter(filter);
          case _ChannelToggleUnreadAction():
            viewState.setChannelsShowUnreadOnly(
              !viewState.channelsShowUnreadOnly,
            );
        }
      },
    );
  }

  List<Channel> _filterAndSortChannels(
    List<Channel> channels,
    MeshCoreConnector connector,
    UiViewStateService viewState,
  ) {
    bool matchesTypeFilter(Channel channel) {
      final type = Channel.getChannelType(channel, _communityIndex);
      return switch (viewState.channelsTypeFilter) {
        ChannelTypeFilter.all => true,
        ChannelTypeFilter.favorites => connector.isChannelFavorite(
          channel.index,
        ),
        ChannelTypeFilter.public => type == ChannelType.public,
        ChannelTypeFilter.hashtag => type == ChannelType.hashtag,
        ChannelTypeFilter.private => type == ChannelType.private,
        ChannelTypeFilter.community => Channel.isCommunityChannel(type),
      };
    }

    var filtered = channels.where((channel) {
      if (!matchesTypeFilter(channel)) return false;
      if (viewState.channelsShowUnreadOnly &&
          connector.getUnreadCountForChannel(channel) == 0) {
        return false;
      }
      if (viewState.channelsSearchText.isEmpty) return true;
      final label = _normalizeChannelName(channel);
      return label.toLowerCase().contains(
        viewState.channelsSearchText.toLowerCase(),
      );
    }).toList();

    int compareByName(Channel a, Channel b) {
      final nameA = _normalizeChannelName(a);
      final nameB = _normalizeChannelName(b);
      return nameA.toLowerCase().compareTo(nameB.toLowerCase());
    }

    switch (viewState.channelsSortOption) {
      case ChannelSortOption.manual:
        break;
      case ChannelSortOption.latestMessages:
        filtered.sort((a, b) {
          final aMessages = connector.getChannelMessages(a);
          final bMessages = connector.getChannelMessages(b);
          final aLast = aMessages.isEmpty
              ? DateTime(1970)
              : aMessages.last.timestamp;
          final bLast = bMessages.isEmpty
              ? DateTime(1970)
              : bMessages.last.timestamp;
          final timeCompare = bLast.compareTo(aLast);
          if (timeCompare != 0) return timeCompare;
          return compareByName(a, b);
        });
        break;
      case ChannelSortOption.unread:
        filtered.sort((a, b) {
          final aUnread = connector.getUnreadCountForChannel(a);
          final bUnread = connector.getUnreadCountForChannel(b);
          final unreadCompare = bUnread.compareTo(aUnread);
          if (unreadCompare != 0) return unreadCompare;
          return compareByName(a, b);
        });
        break;
      case ChannelSortOption.name:
        filtered.sort(compareByName);
        break;
    }

    return filtered;
  }

  String _normalizeChannelName(Channel channel) {
    if (channel.name.isEmpty) {
      return 'Channel ${channel.index}'; // Fallback for sorting
    }
    final trimmed = channel.name.trim();
    if (trimmed.startsWith('#') && trimmed.length > 1) {
      return trimmed.substring(1);
    }
    return trimmed;
  }

  void _showAddChannelDialog(BuildContext context) {
    final connector = context.read<MeshCoreConnector>();
    final nextIndex = _findNextAvailableIndex(
      connector.channels,
      connector.maxChannels,
    );
    final hasPublicChannel = connector.channels.any((c) => c.isPublicChannel);
    int? selectedOption;
    final nameController = TextEditingController();
    final pskController = TextEditingController();
    final hashtagController = TextEditingController();
    bool addPublicChannel = true;
    bool isRegularHashtag = true;
    Community? selectedCommunity;

    _communityStore.setPublicKeyHex = connector.selfPublicKeyHex;

    showMeshSheet(
      context,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          Widget buildOptionCard({
            required int optionIndex,
            required IconData icon,
            required String title,
            required String subtitle,
            bool enabled = true,
          }) {
            final isSelected = selectedOption == optionIndex;
            final cardScheme = Theme.of(sheetContext).colorScheme;
            return MeshCard(
              margin: EdgeInsets.symmetric(
                horizontal: MeshTokens.of(sheetContext).spacingMd,
                vertical: MeshTokens.of(sheetContext).spacingXxs,
              ),
              padding: EdgeInsets.symmetric(
                horizontal: MeshTokens.of(sheetContext).spacingSm,
                vertical: MeshTokens.of(sheetContext).spacingSm,
              ), // spacing: vertical 10->Sm (+2px)
              borderColor: isSelected && enabled
                  ? MeshTokens.of(sheetContext).primaryLine
                  : null,
              color: isSelected && enabled
                  ? MeshTokens.of(sheetContext).primaryBg
                  : null,
              onTap: enabled
                  ? () {
                      setSheetState(() {
                        selectedOption = optionIndex;
                        nameController.clear();
                        pskController.clear();
                        hashtagController.clear();
                      });
                    }
                  : null,
              child: Row(
                children: [
                  AvatarCircle(
                    name: title,
                    size: 38,
                    color: enabled
                        ? (isSelected
                              ? MeshTokens.of(sheetContext).primary
                              : cardScheme.onSurfaceVariant)
                        : cardScheme.outline,
                    icon: icon,
                  ),
                  SizedBox(width: MeshTokens.of(sheetContext).spacingSm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: Theme.of(sheetContext).textTheme.bodyMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w500,
                                color: enabled ? null : cardScheme.outline,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: Theme.of(sheetContext).textTheme.bodySmall
                              ?.copyWith(
                                color: enabled
                                    ? cardScheme.onSurfaceVariant
                                    : cardScheme.outline,
                              ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (enabled)
                    Icon(
                      Icons.chevron_right,
                      color: isSelected
                          ? MeshTokens.of(sheetContext).primary
                          : cardScheme.onSurfaceVariant,
                      size: 20,
                    ),
                ],
              ),
            );
          }

          Widget? buildExpandedContent(
            ChannelMessageStore channelMessageStore,
          ) {
            switch (selectedOption) {
              case 0: // Create Private Channel
                return Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: MeshTokens.of(sheetContext).spacingMd,
                        vertical: MeshTokens.of(sheetContext).spacingXs,
                      ),
                      child: TextField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: sheetContext.l10n.channels_channelName,
                          border: const OutlineInputBorder(),
                        ),
                        maxLength: 31,
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: MeshTokens.of(sheetContext).spacingMd,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: FilledButton(
                              onPressed: () async {
                                final name = nameController.text.trim();
                                if (name.isEmpty) {
                                  showDismissibleSnackBar(
                                    context,
                                    content: Text(
                                      sheetContext
                                          .l10n
                                          .channels_enterChannelName,
                                    ),
                                  );
                                  return;
                                }
                                final psk = randomBytes(16);
                                Navigator.pop(sheetContext);
                                await connector.setChannel(
                                  nextIndex,
                                  name,
                                  psk,
                                );
                                await channelMessageStore.clearChannelMessages(
                                  nextIndex,
                                );
                                if (context.mounted) {
                                  showDismissibleSnackBar(
                                    context,
                                    content: Text(
                                      context.l10n.channels_channelAdded(name),
                                    ),
                                  );
                                }
                              },
                              child: Text(sheetContext.l10n.common_create),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: MeshTokens.of(sheetContext).spacingXs),
                  ],
                );

              case 1: // Join Private Channel
                return Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: MeshTokens.of(sheetContext).spacingMd,
                        vertical: MeshTokens.of(sheetContext).spacingXs,
                      ),
                      child: TextField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: sheetContext.l10n.channels_channelName,
                          border: const OutlineInputBorder(),
                        ),
                        maxLength: 31,
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: MeshTokens.of(sheetContext).spacingMd,
                        vertical: MeshTokens.of(sheetContext).spacingXs,
                      ),
                      child: TextField(
                        controller: pskController,
                        decoration: InputDecoration(
                          labelText: sheetContext.l10n.channels_pskHex,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: MeshTokens.of(sheetContext).spacingMd,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: FilledButton(
                              onPressed: () {
                                final name = nameController.text.trim();
                                final pskHex = pskController.text.trim();
                                if (name.isEmpty) {
                                  showDismissibleSnackBar(
                                    context,
                                    content: Text(
                                      sheetContext
                                          .l10n
                                          .channels_enterChannelName,
                                    ),
                                  );
                                  return;
                                }
                                Uint8List psk;
                                try {
                                  psk = Channel.parsePskHex(pskHex);
                                } on FormatException {
                                  showDismissibleSnackBar(
                                    context,
                                    content: Text(
                                      sheetContext.l10n.channels_pskMustBe32Hex,
                                    ),
                                  );
                                  return;
                                }
                                Navigator.pop(sheetContext);
                                connector.setChannel(nextIndex, name, psk);
                                if (context.mounted) {
                                  showDismissibleSnackBar(
                                    context,
                                    content: Text(
                                      context.l10n.channels_channelAdded(name),
                                    ),
                                  );
                                }
                              },
                              child: Text(sheetContext.l10n.common_add),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: MeshTokens.of(sheetContext).spacingXs),
                  ],
                );

              case 2: // Join Public Channel
                return Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: MeshTokens.of(sheetContext).spacingMd,
                    vertical: MeshTokens.of(sheetContext).spacingXs,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            final psk = Channel.parsePskHex(
                              Channel.publicChannelPsk,
                            );
                            Navigator.pop(sheetContext);
                            connector.setChannel(
                              nextIndex,
                              context.l10n.channels_public,
                              psk,
                            );
                            if (context.mounted) {
                              showDismissibleSnackBar(
                                context,
                                content: Text(
                                  context.l10n.channels_publicChannelAdded,
                                ),
                              );
                            }
                          },
                          child: Text(sheetContext.l10n.common_add),
                        ),
                      ),
                    ],
                  ),
                );

              case 3: // Join Hashtag Channel
                return Column(
                  children: [
                    // Only show type selection if user has communities
                    if (_communities.isNotEmpty) ...[
                      RadioGroup<bool>(
                        groupValue: isRegularHashtag,
                        onChanged: (v) => setSheetState(() {
                          if (v == null) return;
                          isRegularHashtag = v;
                          if (isRegularHashtag) {
                            selectedCommunity = null;
                          } else if (selectedCommunity == null &&
                              _communities.isNotEmpty) {
                            selectedCommunity = _communities.first;
                          }
                        }),
                        child: Column(
                          children: [
                            RadioListTile<bool>(
                              value: true,
                              title: Text(
                                sheetContext.l10n.community_regularHashtag,
                              ),
                              subtitle: Text(
                                sheetContext.l10n.community_regularHashtagDesc,
                              ),
                              dense: true,
                            ),
                            RadioListTile<bool>(
                              value: false,
                              title: Text(
                                sheetContext.l10n.community_communityHashtag,
                              ),
                              subtitle: Text(
                                sheetContext
                                    .l10n
                                    .community_communityHashtagDesc,
                              ),
                              dense: true,
                            ),
                          ],
                        ),
                      ),
                    ],
                    // Community dropdown (only if community hashtag selected)
                    if (!isRegularHashtag && _communities.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: MeshTokens.of(sheetContext).spacingMd,
                          vertical: MeshTokens.of(sheetContext).spacingXs,
                        ),
                        child: DropdownButtonFormField<Community>(
                          initialValue: selectedCommunity,
                          items: _communities
                              .map(
                                (c) => DropdownMenuItem(
                                  value: c,
                                  child: Text(c.name),
                                ),
                              )
                              .toList(),
                          onChanged: (c) =>
                              setSheetState(() => selectedCommunity = c),
                          decoration: InputDecoration(
                            labelText:
                                sheetContext.l10n.community_selectCommunity,
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.groups),
                          ),
                        ),
                      ),
                    // Hashtag name input
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: MeshTokens.of(sheetContext).spacingMd,
                        vertical: MeshTokens.of(sheetContext).spacingXs,
                      ),
                      child: TextField(
                        controller: hashtagController,
                        decoration: InputDecoration(
                          labelText: sheetContext.l10n.channels_enterHashtag,
                          hintText: sheetContext.l10n.channels_hashtagHint,
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.tag),
                        ),
                        maxLength: 31,
                      ),
                    ),
                    // Privacy hint for community hashtags
                    if (!isRegularHashtag)
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: MeshTokens.of(sheetContext).spacingMd,
                        ),
                        child: Text(
                          sheetContext.l10n.community_hashtagPrivacyHint,
                          style: Theme.of(sheetContext).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  sheetContext,
                                ).colorScheme.onSurfaceVariant,
                                fontStyle: FontStyle.italic,
                              ),
                        ),
                      ),
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: MeshTokens.of(sheetContext).spacingMd,
                        vertical: MeshTokens.of(sheetContext).spacingXs,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: FilledButton(
                              onPressed: () async {
                                var hashtag = hashtagController.text.trim();
                                if (hashtag.isEmpty) {
                                  showDismissibleSnackBar(
                                    context,
                                    content: Text(
                                      sheetContext
                                          .l10n
                                          .channels_enterChannelName,
                                    ),
                                  );
                                  return;
                                }

                                // Normalize hashtag name (remove leading # if present)
                                if (hashtag.startsWith('#')) {
                                  hashtag = hashtag.substring(1);
                                }
                                final String channelName;

                                final Uint8List psk;
                                if (isRegularHashtag) {
                                  channelName = '#$hashtag';
                                  // Regular hashtag - public derivation using SHA256
                                  psk = Channel.derivePskFromHashtag(hashtag);
                                } else {
                                  // Community hashtag - HMAC derivation from community secret
                                  if (selectedCommunity == null) {
                                    showDismissibleSnackBar(
                                      sheetContext,
                                      content: Text(
                                        sheetContext
                                            .l10n
                                            .community_selectCommunity,
                                      ),
                                    );
                                    return;
                                  }
                                  channelName =
                                      '${selectedCommunity!.name} #$hashtag';
                                  psk = selectedCommunity!
                                      .deriveCommunityHashtagPsk(hashtag);
                                  // Track in community's hashtag list
                                  await _communityStore.addHashtagChannel(
                                    selectedCommunity!.id,
                                    hashtag,
                                  );
                                  _loadCommunities();
                                }

                                if (sheetContext.mounted) {
                                  Navigator.pop(sheetContext);
                                }
                                connector.setChannel(
                                  nextIndex,
                                  channelName,
                                  psk,
                                );
                                if (context.mounted) {
                                  showDismissibleSnackBar(
                                    context,
                                    content: Text(
                                      context.l10n.channels_channelAdded(
                                        channelName,
                                      ),
                                    ),
                                  );
                                }
                              },
                              child: Text(sheetContext.l10n.common_add),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );

              case 4: // Scan Community QR
                return Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: MeshTokens.of(sheetContext).spacingMd,
                    vertical: MeshTokens.of(sheetContext).spacingXs,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () async {
                            Navigator.pop(sheetContext);
                            if (context.mounted) {
                              final result = await Navigator.push<Community>(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const CommunityQrScannerScreen(),
                                ),
                              );
                              // Result handled by scanner screen
                              if (result != null && context.mounted) {
                                // Community was joined, refresh might be needed
                              }
                            }
                          },
                          icon: const Icon(Icons.qr_code_scanner),
                          label: Text(sheetContext.l10n.community_scanQr),
                        ),
                      ),
                    ],
                  ),
                );

              case 5: // Create Community
                return Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: MeshTokens.of(sheetContext).spacingMd,
                        vertical: MeshTokens.of(sheetContext).spacingXs,
                      ),
                      child: TextField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: sheetContext.l10n.community_name,
                          hintText: sheetContext.l10n.community_enterName,
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.groups),
                        ),
                        maxLength: 31,
                      ),
                    ),
                    CheckboxListTile(
                      value: addPublicChannel,
                      onChanged: (value) {
                        setSheetState(() {
                          addPublicChannel = value ?? true;
                        });
                      },
                      title: Text(sheetContext.l10n.community_addPublicChannel),
                      subtitle: Text(
                        sheetContext.l10n.community_addPublicChannelHint,
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: MeshTokens.of(sheetContext).spacingMd,
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: MeshTokens.of(sheetContext).spacingMd,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: FilledButton(
                              onPressed: () async {
                                final name = nameController.text.trim();
                                final publicLabel =
                                    context.l10n.channels_public;
                                if (name.isEmpty) {
                                  showDismissibleSnackBar(
                                    context,
                                    content: Text(
                                      sheetContext.l10n.community_enterName,
                                    ),
                                  );
                                  return;
                                }

                                // Create community with random secret
                                final community = Community.create(
                                  id: const Uuid().v4(),
                                  name: name,
                                );

                                // Save to store
                                await _communityStore.addCommunity(community);

                                // Optionally add the community public channel to the device
                                if (addPublicChannel) {
                                  final psk = community
                                      .deriveCommunityPublicPsk();
                                  final channelName =
                                      '${community.name} $publicLabel';
                                  connector.setChannel(
                                    nextIndex,
                                    channelName,
                                    psk,
                                  );
                                }

                                if (sheetContext.mounted) {
                                  Navigator.pop(sheetContext);
                                }

                                // Refresh communities list
                                _loadCommunities();

                                if (context.mounted) {
                                  showDismissibleSnackBar(
                                    context,
                                    content: Text(
                                      context.l10n.community_created(name),
                                    ),
                                  );

                                  // Show QR code dialog
                                  await QrCodeShareDialog.show(
                                    context: context,
                                    data: community.toQrJson(),
                                    title: context.l10n.community_qrTitle,
                                    instructions: context.l10n
                                        .community_qrInstructions(name),
                                    embeddedImage: Image.asset(
                                      'assets/images/mesh-icon.png',
                                      width: 40,
                                      height: 40,
                                    ),
                                  );
                                }
                              },
                              child: Text(sheetContext.l10n.common_create),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: MeshTokens.of(sheetContext).spacingXs),
                  ],
                );

              default:
                return null;
            }
          }

          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.7,
            minChildSize: 0.4,
            maxChildSize: 0.95,
            builder: (_, scrollController) => Column(
              children: [
                BottomSheetHeader(title: sheetContext.l10n.channels_addChannel),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: EdgeInsets.only(
                      bottom: MeshTokens.of(sheetContext).spacingLg,
                    ),
                    children: [
                      buildOptionCard(
                        optionIndex: 0,
                        icon: Icons.add,
                        title: sheetContext.l10n.channels_createPrivateChannel,
                        subtitle:
                            sheetContext.l10n.channels_createPrivateChannelDesc,
                      ),
                      if (selectedOption == 0)
                        buildExpandedContent(_channelMessageStore)!,
                      buildOptionCard(
                        optionIndex: 1,
                        icon: Icons.lock,
                        title: sheetContext.l10n.channels_joinPrivateChannel,
                        subtitle:
                            sheetContext.l10n.channels_joinPrivateChannelDesc,
                      ),
                      if (selectedOption == 1)
                        buildExpandedContent(_channelMessageStore)!,
                      if (!hasPublicChannel) ...[
                        buildOptionCard(
                          optionIndex: 2,
                          icon: Icons.public,
                          title: sheetContext.l10n.channels_joinPublicChannel,
                          subtitle:
                              sheetContext.l10n.channels_joinPublicChannelDesc,
                        ),
                        if (selectedOption == 2)
                          buildExpandedContent(_channelMessageStore)!,
                      ],
                      buildOptionCard(
                        optionIndex: 3,
                        icon: Icons.tag,
                        title: sheetContext.l10n.channels_joinHashtagChannel,
                        subtitle:
                            sheetContext.l10n.channels_joinHashtagChannelDesc,
                      ),
                      if (selectedOption == 3)
                        buildExpandedContent(_channelMessageStore)!,
                      buildOptionCard(
                        optionIndex: 4,
                        icon: Icons.qr_code_scanner,
                        title: sheetContext.l10n.community_scanQr,
                        subtitle: sheetContext.l10n.community_join,
                      ),
                      if (selectedOption == 4)
                        buildExpandedContent(_channelMessageStore)!,
                      buildOptionCard(
                        optionIndex: 5,
                        icon: Icons.groups,
                        title: sheetContext.l10n.community_create,
                        subtitle: sheetContext.l10n.community_createDesc,
                      ),
                      if (selectedOption == 5)
                        buildExpandedContent(_channelMessageStore)!,
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showEditChannelDialog(
    BuildContext context,
    MeshCoreConnector connector,
    Channel channel,
  ) {
    final appSettingsService = Provider.of<AppSettingsService>(
      context,
      listen: false,
    );
    final nameController = TextEditingController(text: channel.name);
    final pskController = TextEditingController(text: channel.pskHex);
    bool smazEnabled = connector.isChannelSmazEnabled(channel.index);
    bool cyr2latEnabled = connector.isChannelCyr2LatEnabled(channel.index);
    String? selectedCyr2LatProfileId = connector.getChannelCyr2LatProfileId(
      channel.index,
    );

    showMeshSheet(
      context,
      builder: (sheetContext) => StatefulBuilder(
        // Winda template (2026-08-29): content-hugging height instead of the
        // old fixed DraggableScrollableSheet(initialChildSize: 0.65) that
        // left dead space below short content, and a SafeArea'd footer so
        // Cancel/Save never land under the Android system bars.
        builder: (sheetContext, setSheetState) => SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BottomSheetHeader(
                title: sheetContext.l10n.channels_editChannelTitle(
                  channel.index,
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: EdgeInsets.symmetric(
                    horizontal: MeshTokens.of(sheetContext).spacingMd,
                  ),
                  children: [
                    SizedBox(height: MeshTokens.of(sheetContext).spacingXs),
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: sheetContext.l10n.channels_channelName,
                        border: const OutlineInputBorder(),
                      ),
                      maxLength: 31,
                    ),
                    SizedBox(height: MeshTokens.of(sheetContext).spacingMd),
                    TextField(
                      controller: pskController,
                      decoration: InputDecoration(
                        labelText: sheetContext.l10n.channels_pskHex,
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.casino),
                          tooltip: sheetContext.l10n.channels_generateRandomPsk,
                          onPressed: () {
                            final bytes = randomBytes(16);
                            pskController.text = Channel.formatPskHex(bytes);
                          },
                        ),
                      ),
                    ),
                    SizedBox(height: MeshTokens.of(sheetContext).spacingMd),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(sheetContext.l10n.channels_smazCompression),
                      value: smazEnabled,
                      onChanged: (value) => setSheetState(() {
                        smazEnabled = value;
                        if (smazEnabled) {
                          cyr2latEnabled = false;
                        }
                      }),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        sheetContext.l10n.channels_cyr2latCompression,
                      ),
                      subtitle: Text(
                        sheetContext.l10n.channels_cyr2latCompressionDscr,
                      ),
                      value: cyr2latEnabled,
                      onChanged: (value) => setSheetState(() {
                        cyr2latEnabled = value;
                        if (cyr2latEnabled) {
                          smazEnabled = false;
                        }
                      }),
                    ),
                    if (cyr2latEnabled) ...[
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          0,
                          MeshTokens.of(sheetContext).spacingXs,
                          0,
                          MeshTokens.of(sheetContext).spacingXs,
                        ),
                        child: DropdownButtonFormField<String>(
                          initialValue: selectedCyr2LatProfileId,
                          decoration: InputDecoration(
                            labelText: sheetContext
                                .l10n
                                .channels_cyr2latSettingsSubheading,
                            border: const OutlineInputBorder(),
                          ),
                          items: appSettingsService.settings.cyr2latProfiles
                              .map((profile) {
                                return DropdownMenuItem(
                                  value: profile.id,
                                  child: Text(profile.name),
                                );
                              })
                              .toList(),
                          onChanged: (value) => setSheetState(() {
                            selectedCyr2LatProfileId = value;
                          }),
                        ),
                      ),
                    ],
                    SizedBox(height: MeshTokens.of(sheetContext).spacingLg),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  MeshTokens.of(sheetContext).spacingMd,
                  MeshTokens.of(sheetContext).spacingXs,
                  MeshTokens.of(sheetContext).spacingMd,
                  MeshTokens.of(sheetContext).spacingMd,
                ),
                child: Row(
                  children: [
                    Expanded(
                      // Winda template: Cancel is a bare text button — no
                      // fill, no border (2026-08-29 user spec).
                      child: TextButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        child: Text(sheetContext.l10n.common_cancel),
                      ),
                    ),
                    SizedBox(width: MeshTokens.of(sheetContext).spacingSm),
                    Expanded(
                      child: FilledButton(
                        onPressed: () async {
                          final name = nameController.text.trim();
                          final pskHex = pskController.text.trim();

                          Uint8List psk;
                          try {
                            psk = Channel.parsePskHex(pskHex);
                          } on FormatException {
                            showDismissibleSnackBar(
                              sheetContext,
                              content: Text(
                                sheetContext.l10n.channels_pskMustBe32Hex,
                              ),
                            );
                            return;
                          }

                          Navigator.pop(sheetContext);
                          try {
                            await connector.setChannel(
                              channel.index,
                              name,
                              psk,
                            );
                            await connector.setChannelSmazEnabled(
                              channel.index,
                              smazEnabled,
                            );
                            await connector.setChannelCyr2LatEnabled(
                              channel.index,
                              cyr2latEnabled,
                            );
                            await connector.setChannelCyr2LatProfileId(
                              channel.index,
                              selectedCyr2LatProfileId,
                            );
                            if (!context.mounted) return;
                            showDismissibleSnackBar(
                              context,
                              content: Text(
                                context.l10n.channels_channelUpdated(name),
                              ),
                            );
                          } catch (e, st) {
                            debugPrint(st.toString());
                            if (!context.mounted) return;
                            showDismissibleSnackBar(
                              context,
                              content: Text(
                                context.l10n.channels_channelUpdateFailed('$e'),
                              ),
                            );
                          }
                        },
                        child: Text(sheetContext.l10n.common_save),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeleteChannel(
    BuildContext context,
    MeshCoreConnector connector,
    ChannelMessageStore channelMessageStore,
    Channel channel,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.l10n.channels_deleteChannel),
        content: Text(
          dialogContext.l10n.channels_deleteChannelConfirm(channel.name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(dialogContext.l10n.common_cancel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await connector.deleteChannel(channel.index);

                await channelMessageStore.clearChannelMessages(channel.index);

                if (!context.mounted) return;

                showDismissibleSnackBar(
                  context,
                  content: Text(
                    context.l10n.channels_channelDeleted(channel.name),
                  ),
                );
              } catch (e, st) {
                if (!context.mounted) return;

                showDismissibleSnackBar(
                  context,
                  content: Text(
                    context.l10n.channels_channelDeleteFailed(channel.name),
                  ),
                );

                // Preserve existing logging (if it was there)
                debugPrint('Failed to delete channel: $e\n$st');
              }
            },
            child: Text(
              dialogContext.l10n.common_delete,
              style: TextStyle(
                color: Theme.of(dialogContext).colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _addPublicChannel(BuildContext context, MeshCoreConnector connector) {
    final psk = Channel.parsePskHex(Channel.publicChannelPsk);
    connector.setChannel(0, context.l10n.channels_public, psk);
    showDismissibleSnackBar(
      context,
      content: Text(context.l10n.channels_publicChannelAdded),
    );
  }

  int _findNextAvailableIndex(List<Channel> channels, int maxChannels) {
    final usedIndices = channels.map((c) => c.index).toSet();
    for (int i = 0; i < maxChannels; i++) {
      if (!usedIndices.contains(i)) return i;
    }
    return 0;
  }

  void _showManageCommunitiesDialog(BuildContext context) {
    showMeshSheet(
      context,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            BottomSheetHeader(
              title: sheetContext.l10n.community_manageCommunities,
            ),
            const MeshDashedDivider(),
            Expanded(
              child: _communities.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.groups_outlined,
                            size: 64,
                            color: Theme.of(sheetContext)
                                .colorScheme
                                .onSurfaceVariant
                                .withValues(alpha: 0.6),
                          ),
                          SizedBox(
                            height: MeshTokens.of(sheetContext).spacingMd,
                          ),
                          Text(
                            sheetContext.l10n.community_noCommunities,
                            style: TextStyle(
                              fontSize: 16,
                              color: Theme.of(
                                sheetContext,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          SizedBox(
                            height: MeshTokens.of(sheetContext).spacingXs,
                          ),
                          Text(
                            sheetContext.l10n.community_scanOrCreate,
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(sheetContext)
                                  .colorScheme
                                  .onSurfaceVariant
                                  .withValues(alpha: 0.8),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: _communities.length,
                      itemBuilder: (context, index) {
                        final community = _communities[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: MeshTokens.of(context).secondaryBg,
                            child: Icon(
                              Icons.groups,
                              color: MeshTokens.of(context).secondary,
                            ),
                          ),
                          title: Text(community.name),
                          subtitle: Text(
                            context.l10n.channels_communityShortId(
                              community.shortCommunityId,
                            ),
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) {
                              Navigator.pop(sheetContext);
                              // Use the screen's context: the sheet item's
                              // context is deactivated once the sheet pops.
                              if (value == 'share') {
                                _showCommunityQrDialog(this.context, community);
                              } else if (value == 'leave') {
                                _confirmLeaveCommunity(this.context, community);
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'share',
                                child: Row(
                                  children: [
                                    const Icon(Icons.qr_code),
                                    SizedBox(
                                      width: MeshTokens.of(context).spacingSm,
                                    ),
                                    Text(context.l10n.community_showQr),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'leave',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.exit_to_app,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.error,
                                    ),
                                    SizedBox(
                                      width: MeshTokens.of(context).spacingSm,
                                    ),
                                    Text(
                                      context.l10n.community_delete,
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.error,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          onTap: () {
                            Navigator.pop(sheetContext);
                            _showCommunityQrDialog(context, community);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCommunityQrDialog(BuildContext context, Community community) {
    QrCodeShareDialog.show(
      context: context,
      data: community.toQrJson(),
      title: context.l10n.community_qrTitle,
      instructions: context.l10n.community_qrInstructions(community.name),
      embeddedImage: Image.asset(
        'assets/images/mesh-icon.png',
        width: 40,
        height: 40,
      ),
    );
  }

  void _confirmLeaveCommunity(BuildContext context, Community community) {
    final connector = context.read<MeshCoreConnector>();

    // Find all channels that belong to this community
    List<Channel> communityChannels = [];
    final publicPskHex = Channel.formatPskHex(
      community.deriveCommunityPublicPsk(),
    );

    for (final channel in connector.channels) {
      // Check if it's the public channel
      if (channel.pskHex == publicPskHex) {
        communityChannels.add(channel);
        continue;
      }
      // Check if it's a hashtag channel
      for (final hashtag in community.hashtagChannels) {
        final hashtagPskHex = Channel.formatPskHex(
          community.deriveCommunityHashtagPsk(hashtag),
        );
        if (channel.pskHex == hashtagPskHex) {
          communityChannels.add(channel);
          break;
        }
      }
    }

    final channelCount = communityChannels.length;
    _communityStore.setPublicKeyHex = connector.selfPublicKeyHex;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.l10n.community_delete),
        content: Text(
          channelCount > 0
              ? '${dialogContext.l10n.community_deleteConfirm(community.name)}\n\n${dialogContext.l10n.community_deleteChannelsWarning(channelCount)}'
              : dialogContext.l10n.community_deleteConfirm(community.name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(dialogContext.l10n.common_cancel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);

              // Delete all community channels from the device
              for (final channel in communityChannels) {
                await connector.deleteChannel(channel.index);
              }

              // Remove community from store
              await _communityStore.removeCommunity(community.id);
              _loadCommunities();

              if (context.mounted) {
                showDismissibleSnackBar(
                  context,
                  content: Text(context.l10n.community_deleted(community.name)),
                );
              }
            },
            child: Text(
              dialogContext.l10n.community_delete,
              style: TextStyle(
                color: Theme.of(dialogContext).colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

sealed class _ChannelsFilterAction {
  const _ChannelsFilterAction();
}

class _ChannelSortAction extends _ChannelsFilterAction {
  final ChannelSortOption option;
  const _ChannelSortAction(this.option);
}

class _ChannelTypeFilterAction extends _ChannelsFilterAction {
  final ChannelTypeFilter filter;
  const _ChannelTypeFilterAction(this.filter);
}

class _ChannelToggleUnreadAction extends _ChannelsFilterAction {
  const _ChannelToggleUnreadAction();
}
