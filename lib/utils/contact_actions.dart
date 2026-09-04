import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../connector/meshcore_connector.dart';
import '../connector/meshcore_protocol.dart';
import '../l10n/l10n.dart';
import '../models/contact.dart';
import '../screens/path_trace_map.dart';
import '../widgets/winda_message.dart';

/// Contact-level actions shared by the Contacts card's long-press winda and
/// the direct chat's ⋮ menu (2026-09-04), so both entry points behave the
/// same. [pushToast] is the caller's winda toast queue.

/// Path trace to the contact over the path the radio currently knows
/// (the winda's "Path trace route" row — only offered when a path exists).
void showContactPathTrace(
  BuildContext context, {
  required MeshCoreConnector connector,
  required Contact contact,
}) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => PathTraceMapScreen(
        title: context.l10n.contacts_pathTraceTo(contact.name),
        path: contact.pathBytesForDisplay,
        flipPathAround: true,
        targetContact: contact,
        pathHashByteWidth: connector.pathHashByteWidth,
      ),
    ),
  );
}

/// Asks the firmware for the contact's cached advert path and opens it on
/// the trace map; toasts when nothing is cached.
Future<void> showContactAdvertPath(
  BuildContext context, {
  required MeshCoreConnector connector,
  required Contact contact,
  required void Function(WindaMessage) pushToast,
}) async {
  final result = await connector.getAdvertPath(contact);
  if (!context.mounted) return;
  if (result == null) {
    pushToast(
      WindaMessage(
        text: context.l10n.contacts_advertPathNotFound,
        tone: WindaMessageTone.warning,
        duration: const Duration(seconds: 2),
      ),
    );
    return;
  }
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => PathTraceMapScreen(
        title: context.l10n.contacts_advertPathTraceTo(contact.name),
        path: result.pathHash,
        flipPathAround: true,
        targetContact: contact,
        pathHashByteWidth: connector.pathHashByteWidth,
      ),
    ),
  );
}

/// How long to wait for the RESP_CODE_EXPORT_CONTACT payload after the
/// command was acknowledged. The firmware sends the payload before the OK,
/// so this only ever runs out when something is genuinely wrong.
const _exportPayloadTimeout = Duration(seconds: 5);

/// "Copy contact to Clipboard": CMD_EXPORT_CONTACT. The advert payload comes
/// back as its own RESP_CODE_EXPORT_CONTACT frame ahead of the generic OK —
/// the Contacts card consumes it in its screen-lifetime frame listener; here
/// a one-shot subscription does the same for a single command.
Future<void> copyContactToClipboard(
  BuildContext context, {
  required MeshCoreConnector connector,
  required Uint8List pubKey,
  required void Function(WindaMessage) pushToast,
}) async {
  final payload = Completer<Uint8List>();
  final subscription = connector.receivedFrames.listen((frame) {
    if (frame.isEmpty || frame[0] != respCodeExportContact) return;
    if (!payload.isCompleted) {
      payload.complete(BufferReader(frame).readRemainingBytes());
    }
  });
  // Consumed below; attach a handler so an early timeout is never unhandled.
  unawaited(payload.future.catchError((_) => Uint8List(0)));
  try {
    await connector.sendFrame(
      buildExportContactFrame(pubKey),
      waitForGenericAck: true,
    );
    final advertPacket = await payload.future.timeout(_exportPayloadTimeout);
    if (!context.mounted) return;
    // Protocol minimum for an advert packet (same check as Contacts).
    if (advertPacket.length < 98) {
      pushToast(
        WindaMessage(
          text: context.l10n.contacts_invalidAdvertFormat,
          tone: WindaMessageTone.error,
        ),
      );
      return;
    }
    await Clipboard.setData(
      ClipboardData(text: 'meshcore://${pubKeyToHex(advertPacket)}'),
    );
    if (!context.mounted) return;
    pushToast(
      WindaMessage(
        text: context.l10n.contacts_contactAdvertCopied,
        tone: WindaMessageTone.success,
      ),
    );
  } catch (_) {
    if (!context.mounted) return;
    pushToast(
      WindaMessage(
        text: context.l10n.contacts_contactAdvertCopyFailed,
        tone: WindaMessageTone.error,
      ),
    );
  } finally {
    await subscription.cancel();
  }
}

/// "Share contact by advert": CMD_SHARE_CONTACT (zero-hop advert of the
/// contact from this radio). Success/failure follows the generic OK/ERR.
Future<void> shareContactZeroHop(
  BuildContext context, {
  required MeshCoreConnector connector,
  required Uint8List pubKey,
  required void Function(WindaMessage) pushToast,
}) async {
  try {
    await connector.sendFrame(
      buildZeroHopContact(pubKey),
      waitForGenericAck: true,
    );
    if (!context.mounted) return;
    pushToast(
      WindaMessage(
        text: context.l10n.contacts_zeroHopContactAdvertSent,
        tone: WindaMessageTone.success,
      ),
    );
  } catch (_) {
    if (!context.mounted) return;
    pushToast(
      WindaMessage(
        text: context.l10n.contacts_zeroHopContactAdvertFailed,
        tone: WindaMessageTone.error,
      ),
    );
  }
}

/// Asks for confirmation, then removes the contact from the radio and the
/// app. Returns `true` only when it was removed — the direct chat uses that
/// to leave a conversation that no longer exists.
Future<bool> confirmDeleteContact(
  BuildContext context, {
  required MeshCoreConnector connector,
  required Contact contact,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(dialogContext.l10n.contacts_deleteContact),
      content: Text(dialogContext.l10n.contacts_removeConfirm(contact.name)),
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
  await connector.removeContact(contact);
  return true;
}
