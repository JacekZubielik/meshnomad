import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../connector/meshcore_connector.dart';
import '../l10n/l10n.dart';
import '../models/channel.dart';
import '../services/app_settings_service.dart';
import '../storage/channel_message_store.dart';
import '../theme/mesh_tokens.dart';
import '../widgets/mesh_ui.dart';
import '../widgets/winda_message.dart';
import 'keys.dart';

/// Channel-level actions shared by the Channels card's long-press winda and
/// the channel chat's ⋮ menu (2026-09-04) — one edit sheet and one delete
/// confirmation, so both entry points behave and look identical.
///
/// [pushToast] is the caller's winda toast queue (`WindaToastQueue.pushToast`
/// or the Channels card's own `_pushToast`) — the result lands on whichever
/// screen the user is actually looking at.

/// Edit sheet (winda template): name, PSK, Smaz / cyr2lat toggles.
void showEditChannelSheet(
  BuildContext context, {
  required MeshCoreConnector connector,
  required Channel channel,
  required void Function(WindaMessage) pushToast,
}) {
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
              title: sheetContext.l10n.channels_editChannelTitle(channel.index),
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
                    title: Text(sheetContext.l10n.channels_cyr2latCompression),
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
                        items: appSettingsService.settings.cyr2latProfiles.map((
                          profile,
                        ) {
                          return DropdownMenuItem(
                            value: profile.id,
                            child: Text(profile.name),
                          );
                        }).toList(),
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
                          pushToast(
                            WindaMessage(
                              text: sheetContext.l10n.channels_pskMustBe32Hex,
                              tone: WindaMessageTone.warning,
                            ),
                          );
                          return;
                        }

                        Navigator.pop(sheetContext);
                        try {
                          await connector.setChannel(channel.index, name, psk);
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
                          pushToast(
                            WindaMessage(
                              text: context.l10n.channels_channelUpdated(name),
                              tone: WindaMessageTone.success,
                            ),
                          );
                        } catch (e, st) {
                          debugPrint(st.toString());
                          if (!context.mounted) return;
                          pushToast(
                            WindaMessage(
                              text: context.l10n.channels_channelUpdateFailed(
                                '$e',
                              ),
                              tone: WindaMessageTone.error,
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

/// Asks for confirmation, then deletes the channel on the device and clears
/// its stored messages. Returns `true` only when the channel was actually
/// deleted. Only the failure toast is pushed here — the success toast is the
/// caller's, because the channel chat leaves the (now gone) conversation on
/// success and a toast pushed on a popped screen never shows
/// (`MeshScreenScaffold` unregisters from the winda host on dispose).
Future<bool> confirmDeleteChannel(
  BuildContext context, {
  required MeshCoreConnector connector,
  required ChannelMessageStore channelMessageStore,
  required Channel channel,
  required void Function(WindaMessage) pushToast,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(dialogContext.l10n.channels_deleteChannel),
      content: Text(
        dialogContext.l10n.channels_deleteChannelConfirm(channel.name),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(dialogContext.l10n.common_cancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(
            dialogContext.l10n.common_delete,
            style: TextStyle(color: Theme.of(dialogContext).colorScheme.error),
          ),
        ),
      ],
    ),
  );
  if (confirmed != true) return false;

  try {
    await connector.deleteChannel(channel.index);
    await channelMessageStore.clearChannelMessages(channel.index);
    return true;
  } catch (e, st) {
    debugPrint('Failed to delete channel: $e\n$st');
    if (!context.mounted) return false;
    pushToast(
      WindaMessage(
        text: context.l10n.channels_channelDeleteFailed(channel.name),
        tone: WindaMessageTone.error,
      ),
    );
    return false;
  }
}
