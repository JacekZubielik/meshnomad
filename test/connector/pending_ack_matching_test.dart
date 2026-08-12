// Regression tests for the pending generic-ack queue (spike 01):
// firmware OK/ERR frames have no correlation id and arrive strictly in
// command-send order. `_pendingGenericAckQueue` used to remove entries on
// timeout, which shifted every later response by one slot as soon as a
// single command timed out. These tests drive the same private handlers
// production code uses (via a small @visibleForTesting surface on
// MeshCoreConnector) to prove responses stay matched to the right command
// even when an earlier one timed out or its write failed.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:meshcore_open/connector/meshcore_connector.dart';
import 'package:meshcore_open/connector/meshcore_protocol.dart';

void main() {
  group('pending generic-ack queue matching', () {
    test('two commands in flight: ERR then OK resolve in send order', () async {
      final connector = MeshCoreConnector();
      final completer1 = Completer<void>();
      final completer2 = Completer<void>();

      connector.debugQueueGenericAck(
        commandCode: cmdSendChannelTxtMsg,
        completer: completer1,
      );
      connector.debugQueueGenericAck(
        commandCode: cmdAddUpdateContact,
        completer: completer2,
      );
      expect(connector.debugPendingGenericAckQueueLength, 2);

      connector.debugHandleErrorFrame(errCodeIllegalArg);
      expect(connector.debugPendingGenericAckQueueLength, 1);
      expect(completer1.isCompleted, isTrue);
      await expectLater(
        completer1.future,
        throwsA(
          predicate<Object>(
            (e) =>
                e.toString().contains('cmdSendChannelTxtMsg') &&
                e.toString().contains('ILLEGAL_ARG'),
          ),
        ),
      );
      expect(completer2.isCompleted, isFalse);

      connector.debugHandleOkFrame();
      expect(connector.debugPendingGenericAckQueueLength, 0);
      expect(completer2.isCompleted, isTrue);
      await completer2.future; // does not throw
    });

    test('timeout on first of two commands: late OK is consumed by the '
        'tombstone instead of completing the second command', () async {
      final connector = MeshCoreConnector();
      final completer1 = Completer<void>();
      final completer2 = Completer<void>();

      connector.debugQueueGenericAck(
        commandCode: cmdSendChannelTxtMsg,
        completer: completer1,
      );
      connector.debugQueueGenericAck(
        commandCode: cmdAddUpdateContact,
        completer: completer2,
      );

      // Local timeout on the first command: it must NOT be removed from
      // the queue (that would desync the FIFO order for command #2).
      connector.debugExpireOldestPendingGenericAck();
      expect(completer1.isCompleted, isTrue);
      await expectLater(completer1.future, throwsA(isA<TimeoutException>()));
      expect(connector.debugPendingGenericAckQueueLength, 2);

      // The late OK for command #1 arrives after the local timeout. It
      // must be swallowed by the tombstone, not misattributed to #2.
      connector.debugHandleOkFrame();
      expect(connector.debugPendingGenericAckQueueLength, 1);
      expect(completer2.isCompleted, isFalse);

      // The real response for command #2 now correctly completes it.
      connector.debugHandleOkFrame();
      expect(connector.debugPendingGenericAckQueueLength, 0);
      expect(completer2.isCompleted, isTrue);
      await completer2.future; // does not throw
    });

    test('ERR on a queue with a tombstone at the head consumes the tombstone '
        'and reports the error against the correct command', () async {
      final connector = MeshCoreConnector();
      final completer1 = Completer<void>();
      final completer2 = Completer<void>();

      connector.debugQueueGenericAck(
        commandCode: cmdSendChannelTxtMsg,
        completer: completer1,
      );
      connector.debugExpireOldestPendingGenericAck();
      connector.debugQueueGenericAck(
        commandCode: cmdAddUpdateContact,
        completer: completer2,
      );
      expect(connector.debugPendingGenericAckQueueLength, 2);

      // Late ERR for the timed-out command #1: consumed by the tombstone.
      connector.debugHandleErrorFrame(errCodeNotFound);
      expect(connector.debugPendingGenericAckQueueLength, 1);
      expect(completer2.isCompleted, isFalse);

      // Real ERR for command #2 lands on the right completer.
      connector.debugHandleErrorFrame(errCodeBadState);
      expect(connector.debugPendingGenericAckQueueLength, 0);
      await expectLater(
        completer2.future,
        throwsA(
          predicate<Object>(
            (e) =>
                e.toString().contains('cmdAddUpdateContact') &&
                e.toString().contains('BAD_STATE'),
          ),
        ),
      );
    });

    test(
      'disconnect fails every unfinished completer and empties the queue',
      () async {
        final connector = MeshCoreConnector();
        final completer1 = Completer<void>();
        final completer2 = Completer<void>();

        connector.debugQueueGenericAck(
          commandCode: cmdSendChannelTxtMsg,
          completer: completer1,
        );
        connector.debugQueueGenericAck(
          commandCode: cmdAddUpdateContact,
          completer: completer2,
        );

        connector.debugFailPendingGenericAckQueue('Disconnected');

        expect(connector.debugPendingGenericAckQueueLength, 0);
        expect(completer1.isCompleted, isTrue);
        expect(completer2.isCompleted, isTrue);
        await expectLater(completer1.future, throwsA(isA<StateError>()));
        await expectLater(completer2.future, throwsA(isA<StateError>()));
      },
    );
  });

  group('errorCodeName', () {
    test('maps firmware codes 1-6 to their documented names', () {
      expect(errorCodeName(errCodeUnsupportedCmd), 'UNSUPPORTED_CMD');
      expect(errorCodeName(errCodeNotFound), 'NOT_FOUND');
      expect(errorCodeName(errCodeTableFull), 'TABLE_FULL');
      expect(errorCodeName(errCodeBadState), 'BAD_STATE');
      expect(errorCodeName(errCodeFileIoError), 'FILE_IO_ERROR');
      expect(errorCodeName(errCodeIllegalArg), 'ILLEGAL_ARG');
    });

    test('falls back to a readable label for unknown codes', () {
      expect(errorCodeName(7), contains('7'));
      expect(errorCodeName(7), isNot(equals('ILLEGAL_ARG')));
    });
  });

  group('commandCodeName', () {
    test('names the commands tracked in the generic-ack queue', () {
      expect(commandCodeName(cmdSendChannelTxtMsg), 'cmdSendChannelTxtMsg');
      expect(commandCodeName(cmdAddUpdateContact), 'cmdAddUpdateContact');
    });

    test('falls back to cmd#<n> for unknown codes', () {
      expect(commandCodeName(250), 'cmd#250');
    });
  });
}
