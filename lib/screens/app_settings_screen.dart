import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../connector/meshcore_connector.dart';
import '../l10n/l10n.dart';
import '../models/app_settings.dart';
import '../models/translation_support.dart';
import '../services/app_settings_service.dart';
import '../services/map_tile_cache_service.dart';
import '../services/notification_service.dart';
import '../services/translation_service.dart';
import '../theme/dashed_rounded_border.dart';
import '../theme/mesh_tokens.dart';
import '../theme/styles/style_registry.dart';
import '../widgets/adaptive_app_bar_title.dart';
import '../widgets/settings_value_stepper.dart';
import '../widgets/app_bar.dart';
import '../widgets/mesh_ui.dart';
import '../widgets/theme_profile_selector.dart';
import '../helpers/snack_bar_builder.dart';
import 'auto_route_rotation_screen.dart';
import 'custom_style_editor_screen.dart';
import 'map_cache_screen.dart';
import '../widgets/mesh_dashed_divider.dart';

class AppSettingsScreen extends StatelessWidget {
  const AppSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 07-selection-bugs.md: SelectionArea scoped per-screen (not globally
    // above the Navigator) so "select all" can't sweep in text from other,
    // offstage routes still mounted via maintainState:true.
    return SelectionArea(child: _screenBody(context));
  }

  Widget _screenBody(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Circular/accent app-bar family (2026-08-29, matching Flasher and
        // the companion-connect screens) — see
        // docs/superpowers/meshnomad-vault/templates/ui-patterns/app-bar-schema.md.
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Theme.of(context).colorScheme.primary,
          ),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: AdaptiveAppBarTitle(context.l10n.appSettings_title),
        centerTitle: true,
        actions: const [CircleQuickAccessMenuButton()],
      ),
      body: SafeArea(
        top: false,
        child:
            Consumer3<
              AppSettingsService,
              MeshCoreConnector,
              TranslationService
            >(
              builder:
                  (
                    context,
                    settingsService,
                    connector,
                    translationService,
                    child,
                  ) {
                    final t = MeshTokens.of(context);
                    return ListView(
                      key: const ValueKey('appSettingsMainList'),
                      padding: EdgeInsets.fromLTRB(
                        0,
                        t.spacingXs,
                        0,
                        t.spacingLg,
                      ),
                      children: [
                        // APPEARANCE
                        SectionHeader(context.l10n.appSettings_appearance),
                        MeshCard(
                          padding: EdgeInsets.zero,
                          child: _buildAppearanceContent(
                            context,
                            settingsService,
                          ),
                        ),

                        // NOTIFICATIONS
                        SectionHeader(context.l10n.appSettings_notifications),
                        MeshCard(
                          padding: EdgeInsets.zero,
                          child: _buildNotificationsContent(
                            context,
                            settingsService,
                          ),
                        ),

                        // MESSAGING
                        SectionHeader(context.l10n.appSettings_messaging),
                        MeshCard(
                          padding: EdgeInsets.zero,
                          child: _buildMessagingContent(
                            context,
                            settingsService,
                          ),
                        ),

                        // MAP
                        SectionHeader(context.l10n.appSettings_mapDisplay),
                        MeshCard(
                          padding: EdgeInsets.zero,
                          child: _buildMapContent(context, settingsService),
                        ),

                        // TRANSLATION (non-web only)
                        if (!kIsWeb) ...[
                          SectionHeader(context.l10n.translation_title),
                          MeshCard(
                            padding: EdgeInsets.zero,
                            child: _buildTranslationContent(
                              context,
                              settingsService,
                              translationService,
                            ),
                          ),
                        ],

                        // CYR2LAT
                        SectionHeader(
                          context.l10n.channels_cyr2latSettingsHeading,
                        ),
                        MeshCard(
                          padding: EdgeInsets.fromLTRB(
                            t.spacingMd,
                            t.spacingXxs,
                            t.spacingMd,
                            t.spacingMd,
                          ),
                          child: _buildCyr2LatContent(context, settingsService),
                        ),

                        // DEBUG
                        SectionHeader(context.l10n.appSettings_debugCard),
                        MeshCard(
                          padding: EdgeInsets.zero,
                          child: _buildDebugContent(context, settingsService),
                        ),
                      ],
                    );
                  },
            ),
      ),
    );
  }

  Widget _buildAppearanceContent(
    BuildContext context,
    AppSettingsService settingsService,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final t = MeshTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          // spacing: 14/10 rounded up to spacingMd/spacingSm (+2px)
          padding: EdgeInsets.fromLTRB(
            t.spacingMd,
            t.spacingMd,
            t.spacingMd,
            t.spacingSm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [_MotywSection(settingsService: settingsService)],
          ),
        ),
        const MeshDashedDivider(indent: 16),
        // Inline value stepper instead of the former picker sheet (user
        // spec 2026-08-23: same control as Appearance -> Button border).
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: t.spacingMd,
            vertical: t.spacingSm,
          ),
          child: Row(
            children: [
              Icon(
                Icons.language_outlined,
                size: 20,
                color: MeshTokens.of(context).primary,
              ),
              SizedBox(width: t.spacingSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.appSettings_language,
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.l10n.appSettings_language_subtitle,
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: t.spacingSm),
              SettingsValueStepper<String?>(
                key: const ValueKey('languageStepper'),
                values: const [null, 'en', 'pl'],
                value: settingsService.settings.languageOverride,
                labelOf: _languageLabel,
                buttonBorder:
                    settingsService.activeProfileOverrides.buttonBorder,
                onChanged: (v) => settingsService.setLanguageOverride(v),
              ),
            ],
          ),
        ),
        const MeshDashedDivider(indent: 16),
        // Card shadow toggle — relocated from the Custom Style editor's own
        // "Card style" section (2026-08-22): a style-wide visual switch
        // belongs alongside the rest of Appearance, not nested three levels
        // deep under Debug/Custom style.
        SwitchListTile(
          contentPadding: EdgeInsets.symmetric(
            horizontal: t.spacingMd,
            vertical: t.spacingXxs,
          ),
          secondary: Icon(
            Icons.layers_outlined,
            size: 20,
            color: MeshTokens.of(context).primary,
          ),
          title: Text(context.l10n.styleEditor_cardShadow_label),
          subtitle: Text(context.l10n.styleEditor_cardShadow_subtitle),
          value: settingsService.activeProfileOverrides.cardElevated ?? true,
          onChanged: (v) => settingsService.setCustomCardElevated(v),
        ),
        const MeshDashedDivider(indent: 16),
        // Inner shadow toggle (2026-09-02) — independent of "Card shadow"
        // above: that one now also gates dropdown menus' new outer
        // bottom+right shadow (matching MeshCard), so a user who wants the
        // "same shadow as cards" look on menus without the separate
        // "recessed panel" top/left cue needs its own switch.
        SwitchListTile(
          contentPadding: EdgeInsets.symmetric(
            horizontal: t.spacingMd,
            vertical: t.spacingXxs,
          ),
          secondary: Icon(
            Icons.filter_b_and_w_outlined,
            size: 20,
            color: MeshTokens.of(context).primary,
          ),
          title: Text(context.l10n.styleEditor_innerShadow_label),
          subtitle: Text(context.l10n.styleEditor_innerShadow_subtitle),
          value:
              settingsService.activeProfileOverrides.innerShadowEnabled ?? true,
          onChanged: (v) => settingsService.setCustomInnerShadowEnabled(v),
        ),
        const MeshDashedDivider(indent: 16),
        // Same control, same field as Custom Style editor's Buttons section
        // (2026-08-23 correction: this is `buttonBorder` — none/solid/
        // dotted — NOT the separate `borderOverride` field. Both this and
        // the editor's stepper read/write
        // `settingsService.activeProfileOverrides.buttonBorder` /
        // `setCustomButtonBorder`, so they always show the same value and
        // stay in sync — this is a second, more-discoverable entry point to
        // the identical setting, not a different one).
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: t.spacingMd,
            vertical: t.spacingXxs,
          ),
          child: Row(
            children: [
              Icon(
                Icons.border_style,
                size: 20,
                color: MeshTokens.of(context).primary,
              ),
              SizedBox(width: t.spacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.l10n.appSettings_borderOverride_label),
                    Text(
                      context.l10n.appSettings_borderOverride_subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: t.spacingMd),
              _BorderOverrideStepper(
                key: const ValueKey('borderOverrideStepper'),
                value: settingsService.activeProfileOverrides.buttonBorder,
                onChanged: (v) => settingsService.setCustomButtonBorder(
                  v == 'none' ? null : v,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationsContent(
    BuildContext context,
    AppSettingsService settingsService,
  ) {
    final notifEnabled = settingsService.settings.notificationsEnabled;
    final t = MeshTokens.of(context);
    return Column(
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.symmetric(
            horizontal: t.spacingMd,
            vertical: t.spacingXxs,
          ),
          secondary: Icon(
            Icons.notifications_outlined,
            size: 20,
            color: MeshTokens.of(context).primary,
          ),
          title: Text(context.l10n.appSettings_enableNotifications),
          subtitle: Text(context.l10n.appSettings_enableNotificationsSubtitle),
          value: settingsService.settings.notificationsEnabled,
          onChanged: (value) async {
            if (value) {
              final granted = await NotificationService().requestPermissions();
              if (!granted) {
                if (context.mounted) {
                  showDismissibleSnackBar(
                    context,
                    content: Text(
                      context.l10n.appSettings_notificationPermissionDenied,
                    ),
                    duration: const Duration(seconds: 2),
                  );
                }
                return;
              }
            }
            await settingsService.setNotificationsEnabled(value);
            if (context.mounted) {
              showDismissibleSnackBar(
                context,
                content: Text(
                  value
                      ? context.l10n.appSettings_notificationsEnabled
                      : context.l10n.appSettings_notificationsDisabled,
                ),
                duration: const Duration(seconds: 2),
              );
            }
          },
        ),
        const MeshDashedDivider(indent: 16),
        SwitchListTile(
          contentPadding: EdgeInsets.symmetric(
            horizontal: t.spacingMd,
            vertical: t.spacingXxs,
          ),
          secondary: Icon(
            Icons.message_outlined,
            size: 20,
            color: notifEnabled
                ? MeshTokens.of(context).primary
                : Theme.of(context).disabledColor,
          ),
          title: Text(
            context.l10n.appSettings_messageNotifications,
            style: TextStyle(
              color: notifEnabled ? null : Theme.of(context).disabledColor,
            ),
          ),
          subtitle: Text(
            context.l10n.appSettings_messageNotificationsSubtitle,
            style: TextStyle(
              color: notifEnabled ? null : Theme.of(context).disabledColor,
            ),
          ),
          value: settingsService.settings.notifyOnNewMessage,
          onChanged: notifEnabled
              ? (value) => settingsService.setNotifyOnNewMessage(value)
              : null,
        ),
        const MeshDashedDivider(indent: 16),
        SwitchListTile(
          contentPadding: EdgeInsets.symmetric(
            horizontal: t.spacingMd,
            vertical: t.spacingXxs,
          ),
          secondary: Icon(
            Icons.forum_outlined,
            size: 20,
            color: notifEnabled
                ? MeshTokens.of(context).primary
                : Theme.of(context).disabledColor,
          ),
          title: Text(
            context.l10n.appSettings_channelMessageNotifications,
            style: TextStyle(
              color: notifEnabled ? null : Theme.of(context).disabledColor,
            ),
          ),
          subtitle: Text(
            context.l10n.appSettings_channelMessageNotificationsSubtitle,
            style: TextStyle(
              color: notifEnabled ? null : Theme.of(context).disabledColor,
            ),
          ),
          value: settingsService.settings.notifyOnNewChannelMessage,
          onChanged: notifEnabled
              ? (value) => settingsService.setNotifyOnNewChannelMessage(value)
              : null,
        ),
        const MeshDashedDivider(indent: 16),
        SwitchListTile(
          contentPadding: EdgeInsets.symmetric(
            horizontal: t.spacingMd,
            vertical: t.spacingXxs,
          ),
          secondary: Icon(
            Icons.cell_tower,
            size: 20,
            color: notifEnabled
                ? MeshTokens.of(context).primary
                : Theme.of(context).disabledColor,
          ),
          title: Text(
            context.l10n.appSettings_advertisementNotifications,
            style: TextStyle(
              color: notifEnabled ? null : Theme.of(context).disabledColor,
            ),
          ),
          subtitle: Text(
            context.l10n.appSettings_advertisementNotificationsSubtitle,
            style: TextStyle(
              color: notifEnabled ? null : Theme.of(context).disabledColor,
            ),
          ),
          value: settingsService.settings.notifyOnNewAdvert,
          onChanged: notifEnabled
              ? (value) => settingsService.setNotifyOnNewAdvert(value)
              : null,
        ),
      ],
    );
  }

  Widget _buildMessagingContent(
    BuildContext context,
    AppSettingsService settingsService,
  ) {
    final t = MeshTokens.of(context);
    return Column(
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.symmetric(
            horizontal: t.spacingMd,
            vertical: t.spacingXxs,
          ),
          secondary: Icon(
            Icons.refresh_outlined,
            size: 20,
            color: MeshTokens.of(context).primary,
          ),
          title: Text(context.l10n.appSettings_clearPathOnMaxRetry),
          subtitle: Text(context.l10n.appSettings_clearPathOnMaxRetrySubtitle),
          value: settingsService.settings.clearPathOnMaxRetry,
          onChanged: (value) {
            settingsService.setClearPathOnMaxRetry(value);
            showDismissibleSnackBar(
              context,
              content: Text(
                value
                    ? context.l10n.appSettings_pathsWillBeCleared
                    : context.l10n.appSettings_pathsWillNotBeCleared,
              ),
              duration: const Duration(seconds: 2),
            );
          },
        ),
        const MeshDashedDivider(indent: 16),
        SwitchListTile(
          contentPadding: EdgeInsets.symmetric(
            horizontal: t.spacingMd,
            vertical: t.spacingXxs,
          ),
          secondary: Icon(
            Icons.vertical_align_top,
            size: 20,
            color: MeshTokens.of(context).primary,
          ),
          title: Text(context.l10n.appSettings_jumpToOldestUnread),
          subtitle: Text(context.l10n.appSettings_jumpToOldestUnreadSubtitle),
          value: settingsService.settings.jumpToOldestUnread,
          onChanged: settingsService.setJumpToOldestUnread,
        ),
        const MeshDashedDivider(indent: 16),
        // Navigation tile (redesign 2026-08-23): the enable switch and its
        // tuning rows moved to their own AutoRouteRotationScreen.
        SettingsTappableTile(
          icon: Icons.alt_route,
          title: context.l10n.appSettings_autoRouteRotation,
          subtitle: context.l10n.appSettings_autoRouteRotationSubtitle,
          onTap: () => pushAutoRouteRotationScreen(context),
        ),
        const MeshDashedDivider(indent: 16),
        SwitchListTile(
          contentPadding: EdgeInsets.symmetric(
            horizontal: t.spacingMd,
            vertical: t.spacingXxs,
          ),
          secondary: Icon(
            Icons.location_searching,
            size: 20,
            color: MeshTokens.of(context).primary,
          ),
          title: Text(context.l10n.appSettings_enableMessageTracing),
          subtitle: Text(context.l10n.appSettings_enableMessageTracingSubtitle),
          value: settingsService.settings.enableMessageTracing,
          onChanged: (value) {
            settingsService.setEnableMessageTracing(value);
          },
        ),
        const MeshDashedDivider(indent: 16),
        // Same row layout and stepper control as Appearance -> Button border
        // (user spec 2026-08-23): the picker sheet is gone, the value cycles
        // inline through 200/500/1000/Unlimited.
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: t.spacingMd,
            vertical: t.spacingXxs,
          ),
          child: Row(
            children: [
              Icon(
                Icons.history,
                size: 20,
                color: MeshTokens.of(context).primary,
              ),
              SizedBox(width: t.spacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.l10n.settings_messageHistoryLimit),
                    Text(
                      context.l10n.appSettings_messageHistoryLimit_subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: t.spacingMd),
              SettingsValueStepper<int>(
                key: const ValueKey('messageHistoryLimitStepper'),
                values: const [200, 500, 1000, 2000, 0],
                value: settingsService.settings.messageHistoryLimit,
                labelOf: (ctx, v) => v == 0
                    ? ctx.l10n.settings_messageHistoryLimitUnlimited
                    : '$v',
                buttonBorder:
                    settingsService.activeProfileOverrides.buttonBorder,
                onChanged: (v) => settingsService.setMessageHistoryLimit(v),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMapContent(
    BuildContext context,
    AppSettingsService settingsService,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final t = MeshTokens.of(context);
    final children = <Widget>[
      SwitchListTile(
        contentPadding: EdgeInsets.symmetric(
          horizontal: t.spacingMd,
          vertical: t.spacingXxs,
        ),
        secondary: Icon(
          Icons.router_outlined,
          size: 20,
          color: MeshTokens.of(context).primary,
        ),
        title: Text(context.l10n.appSettings_showRepeaters),
        subtitle: Text(context.l10n.appSettings_showRepeatersSubtitle),
        value: settingsService.settings.mapShowRepeaters,
        onChanged: (value) => settingsService.setMapShowRepeaters(value),
      ),
      const MeshDashedDivider(indent: 16),
      SwitchListTile(
        contentPadding: EdgeInsets.symmetric(
          horizontal: t.spacingMd,
          vertical: t.spacingXxs,
        ),
        secondary: Icon(
          Icons.chat_outlined,
          size: 20,
          color: MeshTokens.of(context).primary,
        ),
        title: Text(context.l10n.appSettings_showChatNodes),
        subtitle: Text(context.l10n.appSettings_showChatNodesSubtitle),
        value: settingsService.settings.mapShowChatNodes,
        onChanged: (value) => settingsService.setMapShowChatNodes(value),
      ),
      const MeshDashedDivider(indent: 16),
      SwitchListTile(
        contentPadding: EdgeInsets.symmetric(
          horizontal: t.spacingMd,
          vertical: t.spacingXxs,
        ),
        secondary: Icon(
          Icons.people_outline,
          size: 20,
          color: MeshTokens.of(context).primary,
        ),
        title: Text(context.l10n.appSettings_showOtherNodes),
        subtitle: Text(context.l10n.appSettings_showOtherNodesSubtitle),
        value: settingsService.settings.mapShowOtherNodes,
        onChanged: (value) => settingsService.setMapShowOtherNodes(value),
      ),
      const MeshDashedDivider(indent: 16),
      // Inline value stepper instead of the former picker sheet (user spec
      // 2026-08-23: same control as Appearance -> Button border).
      Padding(
        padding: EdgeInsets.symmetric(
          horizontal: t.spacingMd,
          vertical: t.spacingSm,
        ),
        child: Row(
          children: [
            Icon(
              Icons.timer_outlined,
              size: 20,
              color: MeshTokens.of(context).primary,
            ),
            SizedBox(width: t.spacingSm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.appSettings_timeFilter,
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    context.l10n.appSettings_showNodesDiscoveredWithin,
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: t.spacingSm),
            SettingsValueStepper<double>(
              key: const ValueKey('mapTimeFilterStepper'),
              values: const [0, 1, 6, 24, 168],
              value: settingsService.settings.mapTimeFilterHours,
              labelOf: (ctx, v) => switch (v) {
                1 => ctx.l10n.appSettings_lastHour,
                6 => ctx.l10n.appSettings_last6Hours,
                24 => ctx.l10n.appSettings_last24Hours,
                168 => ctx.l10n.appSettings_lastWeek,
                _ => ctx.l10n.appSettings_allTime,
              },
              buttonBorder: settingsService.activeProfileOverrides.buttonBorder,
              onChanged: (v) => settingsService.setMapTimeFilterHours(v),
            ),
          ],
        ),
      ),
      const MeshDashedDivider(indent: 16),
      // Inline value stepper instead of the former picker sheet (user spec
      // 2026-08-23: same control as Appearance -> Button border).
      Padding(
        padding: EdgeInsets.symmetric(
          horizontal: t.spacingMd,
          vertical: t.spacingSm,
        ),
        child: Row(
          children: [
            Icon(
              Icons.straighten,
              size: 20,
              color: MeshTokens.of(context).primary,
            ),
            SizedBox(width: t.spacingSm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.appSettings_unitsTitle,
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    context.l10n.appSettings_units_subtitle,
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: t.spacingSm),
            SettingsValueStepper<UnitSystem>(
              key: const ValueKey('unitsStepper'),
              values: const [UnitSystem.metric, UnitSystem.imperial],
              value: settingsService.settings.unitSystem,
              labelOf: (ctx, v) => v == UnitSystem.imperial
                  ? ctx.l10n.appSettings_unitsImperial
                  : ctx.l10n.appSettings_unitsMetric,
              buttonBorder: settingsService.activeProfileOverrides.buttonBorder,
              onChanged: (v) => settingsService.setUnitSystem(v),
            ),
          ],
        ),
      ),
      const MeshDashedDivider(indent: 16),
      InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const MapCacheScreen()),
          );
        },
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: t.spacingMd,
            vertical: t.spacingSm,
          ),
          child: Row(
            children: [
              Icon(
                Icons.download_outlined,
                size: 20,
                color: MeshTokens.of(context).primary,
              ),
              SizedBox(width: t.spacingSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.appSettings_offlineMapCache,
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      settingsService.settings.mapCacheBounds == null
                          ? context.l10n.appSettings_noAreaSelected
                          : context.l10n.appSettings_areaSelectedZoom(
                              settingsService.settings.mapCacheMinZoom,
                              settingsService.settings.mapCacheMaxZoom,
                            ),
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: scheme.onSurfaceVariant,
                size: 16,
              ),
            ],
          ),
        ),
      ),
      const MeshDashedDivider(indent: 16),
      InkWell(
        onTap: () => _showMapRasterSourceDialog(context, settingsService),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: t.spacingMd,
            vertical: t.spacingSm,
          ),
          child: Row(
            children: [
              Icon(
                Icons.layers_outlined,
                size: 20,
                color: MeshTokens.of(context).primary,
              ),
              SizedBox(width: t.spacingSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.appSettings_rasterTileSource,
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _mapRasterSourceSummary(settingsService.settings),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: scheme.onSurfaceVariant,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    ];

    if (_isStadiaSource(settingsService.settings)) {
      children.addAll([
        const MeshDashedDivider(indent: 16),
        InkWell(
          onTap: () => _showMapRasterEndpointDialog(context, settingsService),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: t.spacingMd,
              vertical: t.spacingSm,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.public_outlined,
                  size: 20,
                  color: MeshTokens.of(context).primary,
                ),
                SizedBox(width: t.spacingSm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.appSettings_stadiaEndpoint,
                        style: textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _mapRasterEndpointSummary(settingsService.settings),
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: scheme.onSurfaceVariant,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
        const MeshDashedDivider(indent: 16),
        InkWell(
          onTap: () => _showMapApiKeyDialog(context, settingsService),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: t.spacingMd,
              vertical: t.spacingSm,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.key_outlined,
                  size: 20,
                  color: MeshTokens.of(context).primary,
                ),
                SizedBox(width: t.spacingSm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.appSettings_stadiaApiKey,
                        style: textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _mapApiKeySummary(context, settingsService.settings),
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: scheme.onSurfaceVariant,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ]);
    }

    return Column(children: children);
  }

  String _mapRasterSourceSummary(AppSettings settings) {
    final source = MapRasterSourceCatalog.fromSettings(settings);
    return '${source.label} - ${source.description}';
  }

  bool _isStadiaSource(AppSettings settings) {
    return MapRasterSourceCatalog.fromSettings(settings).isStadia;
  }

  String _mapRasterEndpointSummary(AppSettings settings) {
    final endpoint = MapRasterEndpointCatalog.fromSettings(settings);
    return '${endpoint.label} - ${endpoint.description}';
  }

  String _mapApiKeySummary(BuildContext context, AppSettings settings) {
    return context.l10n.appSettings_stadiaApiKeyConfigured(
      _maskApiKey(settings.effectiveMapTileApiKey),
    );
  }

  String _maskApiKey(String value) {
    if (value.length <= 8) return '********';
    return '${value.substring(0, 4)}...${value.substring(value.length - 4)}';
  }

  void _showMapRasterSourceDialog(
    BuildContext context,
    AppSettingsService settingsService,
  ) {
    String selectedId = settingsService.settings.mapRasterSourceId;
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: Text(context.l10n.appSettings_rasterTileSource),
          content: SizedBox(
            width: 360,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(dialogContext).size.height * 0.6,
              ),
              child: SingleChildScrollView(
                child: RadioGroup<String>(
                  groupValue: selectedId,
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      selectedId = value;
                    });
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final preset in MapRasterSourcePreset.values)
                        Builder(
                          builder: (context) {
                            final option = MapRasterSourceCatalog.fromPreset(
                              preset,
                            );
                            return RadioListTile<String>(
                              value: preset.id,
                              title: Text(option.label),
                              subtitle: Text(option.description),
                            );
                          },
                        ),
                    ],
                  ),
                ),
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
                await settingsService.setMapRasterSourceId(selectedId);
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
              },
              child: Text(context.l10n.common_save),
            ),
          ],
        ),
      ),
    );
  }

  void _showMapRasterEndpointDialog(
    BuildContext context,
    AppSettingsService settingsService,
  ) {
    String selectedId = settingsService.settings.mapTileEndpointId;
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: Text(context.l10n.appSettings_stadiaEndpoint),
          content: SizedBox(
            width: 360,
            child: RadioGroup<String>(
              groupValue: selectedId,
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  selectedId = value;
                });
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final option in MapRasterEndpointCatalog.presets)
                    RadioListTile<String>(
                      value: option.id,
                      title: Text(option.label),
                      subtitle: Text(option.description),
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
                await settingsService.setMapTileEndpointId(selectedId);
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
              },
              child: Text(context.l10n.common_save),
            ),
          ],
        ),
      ),
    );
  }

  void _showMapApiKeyDialog(
    BuildContext context,
    AppSettingsService settingsService,
  ) {
    final currentApiKey = settingsService.settings.mapTileApiKey?.trim() ?? '';
    final maskedApiKey = _maskApiKey(
      currentApiKey.isEmpty ? AppSettings.stadiaDemo : currentApiKey,
    );
    final controller = TextEditingController(text: maskedApiKey);
    final t = MeshTokens.of(context);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.appSettings_stadiaApiKey),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.l10n.appSettings_stadiaApiKeyDialogDescription),
              SizedBox(height: t.spacingSm),
              TextField(
                controller: controller,
                autofocus: true,
                autocorrect: false,
                enableSuggestions: false,
                autofillHints: const [AutofillHints.password],
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: '4e1bf343-3d91-4d9c-a8e1-1234567890ab',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.l10n.common_cancel),
          ),
          TextButton(
            onPressed: () async {
              final apiKey = controller.text.trim();
              await settingsService.setMapTileApiKey(
                apiKey == maskedApiKey ? currentApiKey : apiKey,
              );
              if (!dialogContext.mounted) return;
              Navigator.pop(dialogContext);
            },
            child: Text(context.l10n.common_save),
          ),
        ],
      ),
    );
  }

  Widget _buildTranslationContent(
    BuildContext context,
    AppSettingsService settingsService,
    TranslationService translationService,
  ) {
    final settings = settingsService.settings;
    final translationEnabled = settings.translationEnabled;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final t = MeshTokens.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.symmetric(
            horizontal: t.spacingMd,
            vertical: t.spacingXxs,
          ),
          secondary: Icon(
            Icons.translate,
            size: 20,
            color: MeshTokens.of(context).primary,
          ),
          title: Text(context.l10n.translation_enableTitle),
          subtitle: Text(context.l10n.translation_enableSubtitle),
          value: settings.translationEnabled,
          onChanged: settingsService.setTranslationEnabled,
        ),
        const MeshDashedDivider(indent: 16),
        SwitchListTile(
          contentPadding: EdgeInsets.symmetric(
            horizontal: t.spacingMd,
            vertical: t.spacingXxs,
          ),
          secondary: Icon(
            Icons.auto_awesome_outlined,
            size: 20,
            color: translationEnabled
                ? MeshTokens.of(context).primary
                : Theme.of(context).disabledColor,
          ),
          title: Text(
            context.l10n.translation_autoIncomingTitle,
            style: TextStyle(
              color: translationEnabled
                  ? null
                  : Theme.of(context).disabledColor,
            ),
          ),
          subtitle: Text(
            context.l10n.translation_autoIncomingSubtitle,
            style: TextStyle(
              color: translationEnabled
                  ? null
                  : Theme.of(context).disabledColor,
            ),
          ),
          value: settings.autoTranslateIncomingMessages,
          onChanged: translationEnabled
              ? settingsService.setAutoTranslateIncomingMessages
              : null,
        ),
        const MeshDashedDivider(indent: 16),
        SwitchListTile(
          contentPadding: EdgeInsets.symmetric(
            horizontal: t.spacingMd,
            vertical: t.spacingXxs,
          ),
          secondary: Icon(
            Icons.outgoing_mail,
            size: 20,
            color: translationEnabled
                ? MeshTokens.of(context).primary
                : Theme.of(context).disabledColor,
          ),
          title: Text(
            context.l10n.translation_composerTitle,
            style: TextStyle(
              color: translationEnabled
                  ? null
                  : Theme.of(context).disabledColor,
            ),
          ),
          subtitle: Text(
            context.l10n.translation_composerSubtitle,
            style: TextStyle(
              color: translationEnabled
                  ? null
                  : Theme.of(context).disabledColor,
            ),
          ),
          value: settings.composerTranslationEnabled,
          onChanged: translationEnabled
              ? settingsService.setComposerTranslationEnabled
              : null,
        ),
        const MeshDashedDivider(indent: 16),
        InkWell(
          onTap: () => _showTranslationLanguageDialog(context, settingsService),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: t.spacingMd,
              vertical: t.spacingSm,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.language,
                  size: 20,
                  color: MeshTokens.of(context).primary,
                ),
                SizedBox(width: t.spacingSm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.translation_targetLanguage,
                        style: textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _translationLanguageLabel(
                          context,
                          settings.translationTargetLanguageCode,
                        ),
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: scheme.onSurfaceVariant,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
        const MeshDashedDivider(indent: 16),
        Padding(
          padding: EdgeInsets.fromLTRB(
            t.spacingMd,
            t.spacingSm,
            t.spacingMd,
            t.spacingXxs,
          ),
          child: DropdownButtonFormField<String>(
            initialValue: settings.translationSelectedModelId,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: context.l10n.translation_downloadedModelLabel,
              border: const OutlineInputBorder(),
            ),
            items: [
              for (final model in settings.translationDownloadedModels)
                DropdownMenuItem(
                  value: model.id,
                  child: Text(translationModelFriendlyName(model)),
                ),
            ],
            onChanged: settings.translationDownloadedModels.isEmpty
                ? null
                : (value) {
                    settingsService.setTranslationSelectedModelId(value);
                  },
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            t.spacingMd,
            t.spacingSm,
            t.spacingMd,
            t.spacingXxs,
          ),
          child: DropdownButtonFormField<String>(
            initialValue: null,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: context.l10n.translation_presetModelLabel,
              border: const OutlineInputBorder(),
            ),
            items: [
              for (final preset in translationPresetModels)
                DropdownMenuItem(
                  value: preset.sourceUrl,
                  child: Text(translationModelFriendlyName(preset)),
                ),
            ],
            onChanged: translationService.isBusy
                ? null
                : (value) async {
                    if (value == null) return;
                    final preset = translationPresetModels.firstWhere(
                      (entry) => entry.sourceUrl == value,
                    );
                    await _downloadTranslationModel(
                      context,
                      translationService,
                      settingsService,
                      sourceUrl: preset.sourceUrl,
                      fileName: preset.name,
                      id: preset.id,
                    );
                  },
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            t.spacingMd,
            t.spacingSm,
            t.spacingMd,
            t.spacingMd,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TranslationUrlField(
                initialValue: settings.translationModelSourceUrl ?? '',
                onChanged: settingsService.setTranslationModelSourceUrl,
                onDownload: translationService.isBusy
                    ? null
                    : (url) => _downloadTranslationModel(
                        context,
                        translationService,
                        settingsService,
                        sourceUrl: url,
                      ),
                downloadLabel: translationService.isDownloading
                    ? context.l10n.translation_downloading
                    : translationService.isBusy
                    ? context.l10n.translation_working
                    : context.l10n.translation_downloadModel,
                isDownloading: translationService.isDownloading,
                onCancel: translationService.cancelDownload,
                labelText: context.l10n.translation_manualUrlLabel,
                stopLabel: context.l10n.translation_stop,
              ),
              if (translationService.isDownloading) ...[
                SizedBox(height: t.spacingSm),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value:
                        translationService.downloadFileName ==
                            'Merging chunks...'
                        ? null
                        : translationService.downloadProgress,
                  ),
                ),
                SizedBox(height: t.spacingXs),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _downloadProgressLabel(context, translationService),
                    style: MeshTokens.of(
                      context,
                    ).monoCaption(color: scheme.onSurfaceVariant),
                  ),
                ),
              ],
              if (settings.translationDownloadedModels.isNotEmpty) ...[
                SizedBox(height: t.spacingMd),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    context.l10n.translation_downloadedModels,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                SizedBox(height: t.spacingXs),
                for (final model in settings.translationDownloadedModels)
                  Padding(
                    padding: EdgeInsets.only(bottom: t.spacingXs),
                    child: Row(
                      children: [
                        Icon(
                          model.id == settings.translationSelectedModelId
                              ? Icons.check_circle
                              : Icons.memory_outlined,
                          size: 20,
                          color: model.id == settings.translationSelectedModelId
                              ? scheme.primary
                              : scheme.onSurfaceVariant,
                        ),
                        SizedBox(width: t.spacingSm),
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(
                              MeshTokens.of(context).xs,
                            ),
                            onTap: () => settingsService
                                .setTranslationSelectedModelId(model.id),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  translationModelFriendlyName(model),
                                  style: textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  _downloadedModelLabel(model),
                                  style: MeshTokens.of(
                                    context,
                                  ).monoCaption(color: scheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: context.l10n.translation_deleteModel,
                          onPressed: translationService.isBusy
                              ? null
                              : () => _deleteTranslationModel(
                                  context,
                                  translationService,
                                  model,
                                ),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ),
              ],
              if (translationService.lastError != null) ...[
                SizedBox(height: t.spacingXs),
                Text(
                  translationService.lastError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCyr2LatContent(
    BuildContext context,
    AppSettingsService settingsService,
  ) {
    final selectedProfile = settingsService.getSelectedCyr2LatProfile();
    final t = MeshTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: t.spacingXs),
        // Header row: literal Cyrillic glyph as the leading icon (Material
        // Symbols has no Cyrillic icon), title, and a short what/why
        // description underneath (user-accepted copy 2026-08-23).
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 20,
              child: Text(
                '\u042F',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: MeshTokens.of(context).primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
            ),
            SizedBox(width: t.spacingSm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.channels_cyr2latSettingsSubheading,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    context.l10n.channels_cyr2latSettingsDescription,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: t.spacingSm),
        // Profile stepper on its own line (user layout 2026-08-23): fully
        // decoupled from the title, so neither can crush the other. The
        // pill is still capped so an over-long profile name ellipsizes
        // instead of overflowing the line.
        LayoutBuilder(
          builder: (context, constraints) {
            final pillMaxWidth =
                constraints.maxWidth - 2 * 36 - 2 * t.spacingXxs;
            return Align(
              alignment: Alignment.centerRight,
              child: SettingsValueStepper<String>(
                key: const ValueKey('cyr2latProfileStepper'),
                values: [
                  for (final profile
                      in settingsService.settings.cyr2latProfiles)
                    profile.id,
                ],
                value: settingsService.settings.selectedCyr2latProfileId,
                labelOf: (ctx, id) =>
                    settingsService.getCyr2LatProfileById(id)?.name ?? id,
                buttonBorder:
                    settingsService.activeProfileOverrides.buttonBorder,
                pillMaxWidth: pillMaxWidth,
                onChanged: (id) =>
                    settingsService.setSelectedCyr2LatProfile(id),
              ),
            );
          },
        ),
        SizedBox(height: t.spacingSm),
        // Icon-only circles, exactly the stepper's -/+ treatment (user spec
        // 2026-08-23): Add IS the stepper's plus circle, Edit/Delete reuse
        // the pencil/trash glyphs the text buttons already carried. Delete
        // keeps the alert accent (2026-08-21 decision: a destructive action
        // must not render identically to Add/Edit).
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _cyr2latCircleButton(
              context,
              settingsService,
              icon: Icons.add,
              tooltip: context.l10n.common_add,
              onPressed: () =>
                  _showAddCyr2LatProfileDialog(context, settingsService),
            ),
            SizedBox(width: t.spacingXs),
            _cyr2latCircleButton(
              context,
              settingsService,
              icon: Icons.edit,
              tooltip: context.l10n.common_edit,
              onPressed: () => _showEditCyr2LatProfileDialog(
                context,
                settingsService,
                selectedProfile,
              ),
            ),
            SizedBox(width: t.spacingXs),
            _cyr2latCircleButton(
              context,
              settingsService,
              icon: Icons.delete,
              tooltip: context.l10n.common_delete,
              accent: t.alert,
              onPressed: settingsService.settings.cyr2latProfiles.length > 1
                  ? () => _showDeleteCyr2LatProfileDialog(
                      context,
                      settingsService,
                      selectedProfile,
                    )
                  : null,
            ),
          ],
        ),
      ],
    );
  }

  /// 36x36 tinted circle identical to the SettingsValueStepper -/+ buttons
  /// (same size, fill, icon size and buttonBorder-driven shape); [accent]
  /// swaps the primary tint for another accent (alert for Delete).
  Widget _cyr2latCircleButton(
    BuildContext context,
    AppSettingsService settingsService, {
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
    Color? accent,
  }) {
    final color = accent ?? Theme.of(context).colorScheme.primary;
    final borderStyle =
        settingsService.activeProfileOverrides.buttonBorder ?? 'none';
    final side = borderStyle == 'none'
        ? BorderSide.none
        : BorderSide(color: color);
    final shape = borderStyle == 'dotted'
        ? DashedCircleBorder(side: side)
        : CircleBorder(side: side);
    return SizedBox(
      width: 36,
      height: 36,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          shape: shape,
          color: color.withValues(alpha: 0.2),
        ),
        child: IconButton(
          padding: EdgeInsets.zero,
          iconSize: 18,
          color: color,
          tooltip: tooltip,
          icon: Icon(icon),
          onPressed: onPressed,
        ),
      ),
    );
  }

  Widget _buildDebugContent(
    BuildContext context,
    AppSettingsService settingsService,
  ) {
    final t = MeshTokens.of(context);
    return Column(
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.symmetric(
            horizontal: t.spacingMd,
            vertical: t.spacingXxs,
          ),
          secondary: Icon(
            Icons.bug_report_outlined,
            size: 20,
            color: MeshTokens.of(context).primary,
          ),
          title: Text(context.l10n.appSettings_appDebugLogging),
          subtitle: Text(context.l10n.appSettings_appDebugLoggingSubtitle),
          value: settingsService.settings.appDebugLogEnabled,
          onChanged: (value) async {
            await settingsService.setAppDebugLogEnabled(value);
            if (!context.mounted) return;
            showDismissibleSnackBar(
              context,
              content: Text(
                value
                    ? context.l10n.appSettings_appDebugLoggingEnabled
                    : context.l10n.appSettings_appDebugLoggingDisabled,
              ),
              duration: const Duration(seconds: 2),
            );
          },
        ),
        const MeshDashedDivider(indent: 16),
        // Custom Style editor — relocated from Appearance (2026-08-22),
        // same CustomStyleEditorScreen push, just a different home; the
        // plain edit-icon IconButton is replaced with the standard
        // SettingsTappableTile nav-row pattern used everywhere else.
        SettingsTappableTile(
          icon: Icons.tune,
          title: context.l10n.styleEditor_title,
          subtitle: context.l10n.appSettings_customStyleSubtitle,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CustomStyleEditorScreen()),
          ),
        ),
      ],
    );
  }

  /// Locale-NEUTRAL labels on purpose (2026-08-23): picking a language
  /// re-resolves every l10n string instantly, so localized labels made the
  /// stepper pill's widest-label width jump on each switch. Endonyms plus
  /// the universally understood "System" render identically in every
  /// locale, keeping the pill width stable.
  String _languageLabel(BuildContext context, String? languageCode) {
    switch (languageCode) {
      case 'en':
        return 'English';
      case 'pl':
        return 'Polski';
      default:
        return 'System';
    }
  }

  void _showTranslationLanguageDialog(
    BuildContext context,
    AppSettingsService settingsService,
  ) {
    showDialog(
      context: context,
      builder: (context) => _TranslationLanguageDialogContent(
        currentLanguageCode:
            settingsService.settings.translationTargetLanguageCode,
        onLanguageSelected: (value) {
          settingsService.setTranslationTargetLanguageCode(value);
          Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _downloadTranslationModel(
    BuildContext context,
    TranslationService translationService,
    AppSettingsService settingsService, {
    required String sourceUrl,
    String? fileName,
    String? id,
  }) async {
    if (sourceUrl.isEmpty) {
      showDismissibleSnackBar(
        context,
        content: Text(context.l10n.translation_enterUrlFirst),
      );
      return;
    }
    try {
      await translationService.downloadModel(
        sourceUrl: sourceUrl,
        fileName: fileName,
        id: id,
      );
      if (!context.mounted) return;
      showDismissibleSnackBar(
        context,
        content: Text(context.l10n.translation_modelDownloaded),
      );
      await settingsService.setTranslationEnabled(true);
    } on TranslationDownloadCancelled {
      if (!context.mounted) return;
      showDismissibleSnackBar(
        context,
        content: Text(context.l10n.translation_downloadStopped),
      );
    } catch (error) {
      if (!context.mounted) return;
      showDismissibleSnackBar(
        context,
        content: Text(
          context.l10n.translation_downloadFailed(error.toString()),
        ),
      );
    }
  }

  String _translationLanguageLabel(BuildContext context, String? languageCode) {
    if (languageCode == null || languageCode.isEmpty) {
      return context.l10n.translation_useAppLanguage;
    }
    for (final option in supportedTranslationLanguages) {
      if (option.code == languageCode) {
        return option.label;
      }
    }
    return languageCode.toUpperCase();
  }

  String _downloadProgressLabel(
    BuildContext context,
    TranslationService translationService,
  ) {
    final fileName = translationService.downloadFileName ?? 'Model';
    if (fileName == 'Merging chunks...') {
      return context.l10n.translation_mergingChunks;
    }
    final currentMb = translationService.downloadedBytes / (1024 * 1024);
    final totalBytes = translationService.downloadTotalBytes;
    if (totalBytes == null || totalBytes <= 0) {
      return '$fileName: ${currentMb.toStringAsFixed(1)} MB';
    }
    final totalMb = totalBytes / (1024 * 1024);
    final percent = ((translationService.downloadProgress ?? 0) * 100)
        .toStringAsFixed(0);
    return '$fileName: ${currentMb.toStringAsFixed(1)} / ${totalMb.toStringAsFixed(1)} MB ($percent%)';
  }

  Future<void> _deleteTranslationModel(
    BuildContext context,
    TranslationService translationService,
    TranslationModelRecord model,
  ) async {
    try {
      await translationService.removeModel(model);
      if (!context.mounted) return;
      showDismissibleSnackBar(
        context,
        content: Text(
          context.l10n.appSettings_translationModelDeleted(
            translationModelFriendlyName(model),
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      showDismissibleSnackBar(
        context,
        content: Text(
          context.l10n.appSettings_translationModelDeleteFailed('$error'),
        ),
      );
    }
  }

  String _downloadedModelLabel(TranslationModelRecord model) {
    final sizeMb = model.fileSizeBytes / (1024 * 1024);
    final source = model.sourceUrl.isEmpty ? model.name : model.sourceUrl;
    return '${sizeMb.toStringAsFixed(1)} MB • $source';
  }

  void _showAddCyr2LatProfileDialog(
    BuildContext context,
    AppSettingsService settingsService,
  ) {
    final nameController = TextEditingController();
    final jsonController = TextEditingController(
      text: const JsonEncoder.withIndent('  ').convert(defaultCyr2LatCharMap),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.settings_cyr2latProfileAdd),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: context.l10n.settings_cyr2latProfileName,
                  border: const OutlineInputBorder(),
                ),
              ),
              SizedBox(height: MeshTokens.of(context).spacingMd),
              TextField(
                controller: jsonController,
                maxLines: 15,
                decoration: InputDecoration(
                  labelText: context.l10n.channels_cyr2latSettingsDialogHint,
                  border: const OutlineInputBorder(),
                  hintText: context.l10n.channels_cyr2latSettingsDscr,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.common_cancel),
          ),
          TextButton(
            onPressed: () async {
              if (nameController.text.isEmpty) {
                showDismissibleSnackBar(
                  context,
                  content: Text(context.l10n.settings_cyr2latProfileNameEmpty),
                );
                return;
              }
              try {
                final json =
                    jsonDecode(jsonController.text) as Map<String, dynamic>;
                final map = json.map(
                  (key, value) => MapEntry(key, value.toString()),
                );
                final profile = Cyr2LatProfile(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: nameController.text,
                  charMap: map,
                );
                await settingsService.addCyr2LatProfile(profile);
                if (!context.mounted) return;
                Navigator.pop(context);
                showDismissibleSnackBar(
                  context,
                  content: Text(context.l10n.settings_cyr2latProfileAdded),
                );
              } catch (e) {
                showDismissibleSnackBar(
                  context,
                  content: Text(
                    context.l10n.channels_cyr2latSettingsDialogWrongJSON(
                      e.toString(),
                    ),
                  ),
                );
              }
            },
            child: Text(context.l10n.common_save),
          ),
        ],
      ),
    );
  }

  void _showEditCyr2LatProfileDialog(
    BuildContext context,
    AppSettingsService settingsService,
    Cyr2LatProfile profile,
  ) {
    final nameController = TextEditingController(text: profile.name);
    final jsonController = TextEditingController(
      text: const JsonEncoder.withIndent('  ').convert(profile.charMap),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.settings_cyr2latProfileEdit),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: context.l10n.settings_cyr2latProfileName,
                  border: const OutlineInputBorder(),
                ),
              ),
              SizedBox(height: MeshTokens.of(context).spacingMd),
              TextField(
                controller: jsonController,
                maxLines: 15,
                decoration: InputDecoration(
                  labelText: context.l10n.channels_cyr2latSettingsDialogHint,
                  border: const OutlineInputBorder(),
                  hintText: context.l10n.channels_cyr2latSettingsDscr,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.common_cancel),
          ),
          TextButton(
            onPressed: () async {
              if (nameController.text.isEmpty) {
                showDismissibleSnackBar(
                  context,
                  content: Text(context.l10n.settings_cyr2latProfileNameEmpty),
                );
                return;
              }
              try {
                final json =
                    jsonDecode(jsonController.text) as Map<String, dynamic>;
                final map = json.map(
                  (key, value) => MapEntry(key, value.toString()),
                );
                final updatedProfile = profile.copyWith(
                  name: nameController.text,
                  charMap: map,
                );
                await settingsService.updateCyr2LatProfile(updatedProfile);
                if (!context.mounted) return;
                Navigator.pop(context);
                showDismissibleSnackBar(
                  context,
                  content: Text(context.l10n.settings_cyr2latProfileUpdated),
                );
              } catch (e) {
                showDismissibleSnackBar(
                  context,
                  content: Text(
                    context.l10n.channels_cyr2latSettingsDialogWrongJSON(
                      e.toString(),
                    ),
                  ),
                );
              }
            },
            child: Text(context.l10n.common_save),
          ),
        ],
      ),
    );
  }

  void _showDeleteCyr2LatProfileDialog(
    BuildContext context,
    AppSettingsService settingsService,
    Cyr2LatProfile profile,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.settings_cyr2latProfileDelete),
        content: Text(
          context.l10n.settings_cyr2latProfileDeleteDscr(profile.name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.common_cancel),
          ),
          TextButton(
            onPressed: () async {
              await settingsService.removeCyr2LatProfile(profile.id);
              if (!context.mounted) return;
              Navigator.pop(context);
              showDismissibleSnackBar(
                context,
                content: Text(context.l10n.settings_cyr2latProfileDeleted),
              );
            },
            child: Text(context.l10n.common_delete),
          ),
        ],
      ),
    );
  }
}

/// +/- stepper cycling through none/solid/dotted for `buttonBorder` — the
/// exact same field, values and labels as the Custom Style editor's
/// Buttons-section stepper (.mockups/repeater-cli-drawer-fixes.html
/// Variant B: circular tinted +/- buttons flanking a centered mono value
/// pill, stable-width via IntrinsicWidth over all possible labels). This is
/// a second entry point to that identical setting (2026-08-23 correction —
/// an earlier version wrongly wired this to the separate `borderOverride`
/// field with its own Auto/On/Off domain), kept as a separate widget here
/// rather than reaching into the editor screen's private one.
class _BorderOverrideStepper extends StatelessWidget {
  const _BorderOverrideStepper({
    super.key,
    required this.value,
    required this.onChanged,
  });

  /// null behaves like 'none' — matches CustomStyleOverrides.buttonBorder.
  final String? value;
  final ValueChanged<String?> onChanged;

  static const _values = ['none', 'solid', 'dotted'];

  String _label(BuildContext context, String? v) {
    final l10n = context.l10n;
    return switch (v) {
      'solid' => l10n.styleEditor_buttonBorder_solid,
      'dotted' => l10n.styleEditor_buttonBorder_dotted,
      _ => l10n.styleEditor_buttonBorder_none,
    };
  }

  void _step(int direction) {
    final index = _values.indexOf(value ?? 'none');
    final next = _values[(index + direction + _values.length) % _values.length];
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = MeshTokens.of(context);

    // Same buttonSide/buttonShape logic as applyChromeRadii in
    // custom_style.dart (the "real" button family) — these circular +/-
    // controls are visually part of that family and must show/hide/style
    // their own border exactly the same way 'new buttons' currently do,
    // live, as the value being edited changes (2026-08-23: first fixed
    // show/hide, then found the line STYLE was still always solid even for
    // 'dotted' — CircleBorder has no built-in dashed variant, hence
    // DashedCircleBorder).
    final effective = value ?? 'none';
    final circleBorderSide = effective == 'none'
        ? BorderSide.none
        : BorderSide(color: scheme.primary);
    final circleShape = effective == 'dotted'
        ? DashedCircleBorder(side: circleBorderSide)
        : CircleBorder(side: circleBorderSide);

    Widget circleButton(IconData icon, VoidCallback onPressed) {
      return SizedBox(
        width: 36,
        height: 36,
        child: DecoratedBox(
          decoration: ShapeDecoration(
            shape: circleShape,
            color: scheme.primary.withValues(alpha: 0.2),
          ),
          child: IconButton(
            padding: EdgeInsets.zero,
            iconSize: 18,
            color: scheme.primary,
            icon: Icon(icon),
            onPressed: onPressed,
          ),
        ),
      );
    }

    final valuePill = Container(
      padding: EdgeInsets.symmetric(
        horizontal: t.spacingSm,
        vertical: t.spacingSm,
      ),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(t.sm),
      ),
      child: IntrinsicWidth(
        child: Stack(
          alignment: Alignment.center,
          children: [
            for (final v in _values)
              // Compare against `effective`, not raw `value` — `value` is
              // null by default (== 'none'), which never equals any string
              // in `_values`, so every label stayed invisible and the pill
              // rendered blank until a non-null value was picked at least
              // once (2026-08-23 bug: "none" never showing at all).
              Visibility(
                visible: v == effective,
                maintainState: true,
                maintainAnimation: true,
                maintainSize: true,
                child: Text(
                  _label(context, v),
                  textAlign: TextAlign.center,
                  style: t.monoBody(color: scheme.onSurface),
                ),
              ),
          ],
        ),
      ),
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        circleButton(Icons.remove, () => _step(-1)),
        SizedBox(width: t.spacingXxs),
        valuePill,
        SizedBox(width: t.spacingXxs),
        circleButton(Icons.add, () => _step(1)),
      ],
    );
  }
}

/// The "Motyw" section: a layout-theme chip row (Default/Terminal/Omarchy)
/// and a color-profile chip row (Green/Blue, scoped to the active theme),
/// plus the entry point to the custom style editor. Selecting a `built:
/// false` theme (Terminal/Omarchy) shows visual selection via local
/// [_previewThemeId] state WITHOUT touching persisted settings or
/// re-theming the app — see ThemeChipRow's doc comment and the design spec
/// 2026-08-12 "Button set" section.
class _MotywSection extends StatefulWidget {
  const _MotywSection({required this.settingsService});

  final AppSettingsService settingsService;

  @override
  State<_MotywSection> createState() => _MotywSectionState();
}

class _MotywSectionState extends State<_MotywSection> {
  String? _previewThemeId;

  @override
  Widget build(BuildContext context) {
    final t = MeshTokens.of(context);
    final textTheme = Theme.of(context).textTheme;
    final settingsService = widget.settingsService;
    final activeThemeId =
        _previewThemeId ?? settingsService.settings.activeThemeId;
    final activeTheme = StyleRegistry.themeById(activeThemeId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.appSettings_theme,
          style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        SizedBox(height: t.spacingSm),
        ThemeChipRow(
          themes: StyleRegistry.themes,
          activeThemeId: activeThemeId,
          onThemeSelected: (themeId) {
            final theme = StyleRegistry.themeById(themeId);
            if (theme.built) {
              // A built theme becomes the real active theme — the preview
              // overlay must clear, or ProfileChipRow keeps rendering the
              // "no profile selected" preview branch forever.
              setState(() => _previewThemeId = null);
              settingsService.setActiveTheme(
                themeId,
                profileId: theme.profiles.first.id,
              );
            } else {
              setState(() => _previewThemeId = themeId);
            }
          },
        ),
        SizedBox(height: t.spacingMd),
        Text(
          context.l10n.appSettings_colorStyle,
          style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        SizedBox(height: t.spacingSm),
        ProfileChipRow(
          activeTheme: activeTheme,
          // While previewing an inert theme (Terminal/Omarchy), no profile
          // of THAT theme is truly active — pass a value matching none of
          // its profile ids so nothing shows selected (e.g. Terminal's own
          // 'green' id would otherwise coincidentally match Default's
          // active 'green' profile and look selected without applying).
          activeProfileId: _previewThemeId == null
              ? settingsService.settings.activeProfileId
              : '',
          // Selecting a profile only applies when the displayed theme IS
          // the actually active one — while previewing an inert theme this
          // row is display-only, otherwise tapping a profile chip would
          // silently persist an activeProfileId that doesn't belong to the
          // real activeThemeId (found in review 2026-08-13).
          onProfileSelected: _previewThemeId == null
              ? settingsService.setActiveProfile
              : (_) {},
        ),
      ],
    );
  }
}

/// Owns the [TextEditingController] for the manual model URL field so it
/// survives rebuilds of the parent [Consumer3].
class _TranslationUrlField extends StatefulWidget {
  const _TranslationUrlField({
    required this.initialValue,
    required this.onChanged,
    required this.onDownload,
    required this.downloadLabel,
    required this.isDownloading,
    required this.onCancel,
    required this.labelText,
    required this.stopLabel,
  });

  final String initialValue;
  final ValueChanged<String> onChanged;
  final void Function(String url)? onDownload;
  final String downloadLabel;
  final bool isDownloading;
  final VoidCallback onCancel;
  final String labelText;
  final String stopLabel;

  @override
  State<_TranslationUrlField> createState() => _TranslationUrlFieldState();
}

class _TranslationUrlFieldState extends State<_TranslationUrlField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = MeshTokens.of(context);
    return Column(
      children: [
        TextField(
          controller: _controller,
          decoration: InputDecoration(
            labelText: widget.labelText,
            border: const OutlineInputBorder(),
          ),
          onChanged: widget.onChanged,
        ),
        SizedBox(height: t.spacingXs),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                // Plain action button, not a switch-style control — never
                // renders the app-wide buttonBorder style (user spec
                // 2026-08-23). The local `side` wins over the themed
                // shape's embedded side at render time.
                style: const ButtonStyle(
                  side: WidgetStatePropertyAll(BorderSide.none),
                ),
                onPressed: widget.onDownload == null
                    ? null
                    : () => widget.onDownload!(_controller.text.trim()),
                icon: const Icon(Icons.download),
                label: Text(widget.downloadLabel),
              ),
            ),
            if (widget.isDownloading) ...[
              SizedBox(width: t.spacingXs),
              OutlinedButton.icon(
                onPressed: widget.onCancel,
                icon: const Icon(Icons.stop_circle_outlined),
                label: Text(widget.stopLabel),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// Dialog content for choosing the translation target language.
/// Owns the search [TextEditingController] so it is properly disposed.
class _TranslationLanguageDialogContent extends StatefulWidget {
  const _TranslationLanguageDialogContent({
    required this.currentLanguageCode,
    required this.onLanguageSelected,
  });

  final String? currentLanguageCode;
  final ValueChanged<String?> onLanguageSelected;

  @override
  State<_TranslationLanguageDialogContent> createState() =>
      _TranslationLanguageDialogContentState();
}

class _TranslationLanguageDialogContentState
    extends State<_TranslationLanguageDialogContent> {
  late final TextEditingController _searchController;
  List<TranslationLanguageOption> _filtered = supportedTranslationLanguages;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = MeshTokens.of(context);
    return AlertDialog(
      title: Text(context.l10n.translation_targetLanguage),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                final normalized = value.trim().toLowerCase();
                setState(() {
                  _filtered = supportedTranslationLanguages.where((option) {
                    return option.label.toLowerCase().contains(normalized) ||
                        option.code.toLowerCase().contains(normalized);
                  }).toList();
                });
              },
            ),
            SizedBox(height: t.spacingSm),
            Flexible(
              child: RadioGroup<String?>(
                groupValue: widget.currentLanguageCode,
                onChanged: (value) {
                  widget.onLanguageSelected(value);
                },
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    RadioListTile<String?>(
                      value: null,
                      title: Text(context.l10n.translation_useAppLanguage),
                    ),
                    for (final option in _filtered)
                      RadioListTile<String?>(
                        value: option.code,
                        title: Text(option.label),
                        subtitle: Text(option.code.toUpperCase()),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.common_close),
        ),
      ],
    );
  }
}
