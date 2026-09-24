import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/features/reliable/reliable_transfer_manager.dart';
import 'package:onebit/features/reliable/transfer.dart';

import 'fake_reliable_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TransferId', () {
    test('starts at 0', () {
      final id = TransferId();
      expect(id.value, 0);
    });

    test('next increments and returns', () {
      final id = TransferId();
      expect(id.next(), 1);
      expect(id.value, 1);
    });

    test('wraps at 255', () {
      final id = TransferId(255);
      expect(id.next(), 0);
      expect(id.value, 0);
    });

    test('equality', () {
      final a = TransferId(42);
      final b = TransferId(42);
      expect(a, equals(b));
    });
  });

  group('TransferEnvelope', () {
    test('encode DATA envelope', () {
      const env = TransferEnvelope(
        type: TransferEnvelope.dataType,
        transferId: 7,
        payload: [10, 20, 30],
      );
      expect(env.encode(), [0x01, 0x07, 10, 20, 30]);
    });

    test('encode ACK envelope', () {
      const env = TransferEnvelope(
        type: TransferEnvelope.ackType,
        transferId: 7,
      );
      expect(env.encode(), [0x02, 0x07]);
    });

    test('decode DATA', () {
      final env = TransferEnvelope.decode([0x01, 0x05, 100, 200]);
      expect(env, isNotNull);
      expect(env!.isData, true);
      expect(env.transferId, 5);
      expect(env.payload, [100, 200]);
    });

    test('decode ACK', () {
      final env = TransferEnvelope.decode([0x02, 0x03]);
      expect(env, isNotNull);
      expect(env!.isAck, true);
      expect(env.transferId, 3);
    });

    test('decode too short returns null', () {
      expect(TransferEnvelope.decode([0x01]), isNull);
    });

    test('decode unknown type returns null', () {
      expect(TransferEnvelope.decode([0xFF, 0x01]), isNull);
    });
  });

  group('ReliableTransferManager — basic delivery', () {
    test('send and receive ACK delivers', () async {
      final channel = FakeReliableChannel();
      final sentCompleter = Completer<List<int>>();
      channel.onSend = (bytes) {
        if (!sentCompleter.isCompleted) sentCompleter.complete(bytes);
      };

      final manager = ReliableTransferManager(channel: channel);

      // Start the send in background.
      final sendFuture = manager.sendReliable([1, 2, 3]);

      // Wait for the DATA to be sent.
      final sentBytes = await sentCompleter.future;
      final env = TransferEnvelope.decode(sentBytes);
      expect(env, isNotNull);
      expect(env!.isData, true);

      // Send ACK back.
      final ack = TransferEnvelope(
        type: TransferEnvelope.ackType,
        transferId: env.transferId,
      );
      channel.receive(ack.encode());

      final result = await sendFuture;
      expect(result, TransferResult.delivered);

      manager.dispose();
      channel.dispose();
    });

    test('two sequential transfers work independently', () async {
      final channel = FakeReliableChannel();
      final sentIds = <int>[];

      final manager = ReliableTransferManager(channel: channel);

      Future<TransferResult> doTransfer(List<int> payload) async {
        final completer = Completer<List<int>>();
        channel.onSend = (bytes) {
          if (!completer.isCompleted) completer.complete(bytes);
        };

        final future = manager.sendReliable(payload);
        final sentBytes = await completer.future;
        final env = TransferEnvelope.decode(sentBytes)!;

        final ack = TransferEnvelope(
          type: TransferEnvelope.ackType,
          transferId: env.transferId,
        );
        channel.receive(ack.encode());
        sentIds.add(env.transferId);
        return future;
      }

      final r1 = await doTransfer([10]);
      expect(r1, TransferResult.delivered);

      final r2 = await doTransfer([20]);
      expect(r2, TransferResult.delivered);

      expect(sentIds.length, 2);
      expect(sentIds[0], isNot(equals(sentIds[1])));

      manager.dispose();
      channel.dispose();
    });
  });

  group('ReliableTransferManager — timeout and retry', () {
    test('timeout retries then fails after max attempts', () async {
      final channel = FakeReliableChannel();
      final sendCount = <int>[];
      channel.onSend = (_) => sendCount.add(1);

      final manager = ReliableTransferManager(
        channel: channel,
        config: const ReliableTransferConfig(
          ackTimeoutMs: 50,
          maxAttempts: 2,
        ),
      );

      final result = await manager.sendReliable([1, 2, 3]);

      expect(result, TransferResult.failed);
      expect(sendCount.length, 2); // 1 initial + 1 retry

      manager.dispose();
      channel.dispose();
    });

    test('retries up to maxAttempts', () async {
      final channel = FakeReliableChannel();
      final sendCount = <int>[];
      channel.onSend = (_) => sendCount.add(1);

      final manager = ReliableTransferManager(
        channel: channel,
        config: const ReliableTransferConfig(
          ackTimeoutMs: 30,
          maxAttempts: 4,
        ),
      );

      final result = await manager.sendReliable([1]);

      expect(result, TransferResult.failed);
      expect(sendCount.length, 4);

      manager.dispose();
      channel.dispose();
    });
  });

  group('ReliableTransferManager — late ACK', () {
    test('late ACK after retry still delivers', () async {
      final channel = FakeReliableChannel();
      final sentCompleter = Completer<List<int>>();
      channel.onSend = (bytes) {
        if (!sentCompleter.isCompleted) sentCompleter.complete(bytes);
      };

      final manager = ReliableTransferManager(
        channel: channel,
        config: const ReliableTransferConfig(
          ackTimeoutMs: 30,
          maxAttempts: 3,
        ),
      );

      final sendFuture = manager.sendReliable([42]);

      // Wait for first DATA to be sent.
      final sentBytes = await sentCompleter.future;
      final env = TransferEnvelope.decode(sentBytes)!;

      // Wait for first timeout + retry.
      await Future<void>.delayed(const Duration(milliseconds: 60));

      // Send ACK for the original transfer ID (late ACK).
      final ack = TransferEnvelope(
        type: TransferEnvelope.ackType,
        transferId: env.transferId,
      );
      channel.receive(ack.encode());

      final result = await sendFuture;
      expect(result, TransferResult.delivered);

      manager.dispose();
      channel.dispose();
    });
  });

  group('ReliableTransferManager — receiver duplicate detection', () {
    test('duplicate DATA is not delivered twice', () async {
      final received = <List<int>>[];

      final receiver = FakeReliableChannel();
      final manager = ReliableTransferManager(
        channel: receiver,
        onDataReceived: (payload, _) => received.add(payload),
      );

      // Simulate receiving the same DATA twice.
      const data = TransferEnvelope(
        type: TransferEnvelope.dataType,
        transferId: 5,
        payload: [10, 20],
      );
      final bytes = data.encode();

      manager.handleIncoming(bytes);
      manager.handleIncoming(bytes); // duplicate

      expect(received.length, 1);
      expect(received[0], [10, 20]);

      manager.dispose();
      receiver.dispose();
    });

    test('duplicate DATA still sends ACK', () async {
      final acks = <int>[];

      final receiver = FakeReliableChannel();
      receiver.onSend = (bytes) {
        final env = TransferEnvelope.decode(bytes);
        if (env != null && env.isAck) acks.add(env.transferId);
      };

      final manager = ReliableTransferManager(
        channel: receiver,
        onDataReceived: (_, _) {},
      );

      const data = TransferEnvelope(
        type: TransferEnvelope.dataType,
        transferId: 7,
        payload: [1],
      );

      manager.handleIncoming(data.encode());
      manager.handleIncoming(data.encode());

      expect(acks.length, 2);
      expect(acks[0], 7);
      expect(acks[1], 7);

      manager.dispose();
      receiver.dispose();
    });

    test('different transfer IDs are delivered', () async {
      final received = <int>[];

      final receiver = FakeReliableChannel();
      final manager = ReliableTransferManager(
        channel: receiver,
        onDataReceived: (_, id) => received.add(id),
      );

      manager.handleIncoming([TransferEnvelope.dataType, 1, 10]);
      manager.handleIncoming([TransferEnvelope.dataType, 2, 20]);
      manager.handleIncoming([TransferEnvelope.dataType, 3, 30]);

      expect(received, [1, 2, 3]);

      manager.dispose();
      receiver.dispose();
    });
  });

  group('ReliableTransferManager — duplicate ACK', () {
    test('duplicate ACK is harmless', () async {
      final channel = FakeReliableChannel();
      final sentCompleter = Completer<List<int>>();
      channel.onSend = (bytes) {
        if (!sentCompleter.isCompleted) sentCompleter.complete(bytes);
      };

      final manager = ReliableTransferManager(channel: channel);

      final sendFuture = manager.sendReliable([1, 2, 3]);

      final sentBytes = await sentCompleter.future;
      final env = TransferEnvelope.decode(sentBytes)!;
      final ack = TransferEnvelope(
        type: TransferEnvelope.ackType,
        transferId: env.transferId,
      );

      // First ACK — should complete the transfer.
      channel.receive(ack.encode());
      final result = await sendFuture;
      expect(result, TransferResult.delivered);

      // Second ACK — should be harmless (no crash).
      channel.receive(ack.encode());
      await Future<void>.delayed(Duration.zero);

      manager.dispose();
      channel.dispose();
    });
  });

  group('ReliableTransferManager — unknown ACK', () {
    test('unknown ACK is ignored safely', () async {
      final channel = FakeReliableChannel();
      final manager = ReliableTransferManager(channel: channel);

      // Send an ACK for a transfer we never sent.
      channel.receive([TransferEnvelope.ackType, 99]);
      await Future<void>.delayed(Duration.zero);

      // No crash. Manager should be in idle state.
      expect(manager.hasPendingTransfer, false);

      manager.dispose();
      channel.dispose();
    });
  });

  group('ReliableTransferManager — disconnect', () {
    test('disconnect fails active transfer', () async {
      final channel = FakeReliableChannel();
      channel.onSend = (_) {};

      final manager = ReliableTransferManager(channel: channel);

      final sendFuture = manager.sendReliable([1, 2, 3]);
      await Future<void>.delayed(Duration.zero);

      // Simulate disconnect before ACK.
      manager.onDisconnect();

      final result = await sendFuture;
      expect(result, TransferResult.failed);

      manager.dispose();
      channel.dispose();
    });

    test('disconnect after ACK is harmless', () async {
      final channel = FakeReliableChannel();
      final sentCompleter = Completer<List<int>>();
      channel.onSend = (bytes) {
        if (!sentCompleter.isCompleted) sentCompleter.complete(bytes);
      };

      final manager = ReliableTransferManager(channel: channel);

      final sendFuture = manager.sendReliable([1, 2, 3]);

      final sentBytes = await sentCompleter.future;
      final env = TransferEnvelope.decode(sentBytes)!;
      final ack = TransferEnvelope(
        type: TransferEnvelope.ackType,
        transferId: env.transferId,
      );
      channel.receive(ack.encode());

      final result = await sendFuture;
      expect(result, TransferResult.delivered);

      // Disconnect after delivery should be harmless.
      manager.onDisconnect();

      manager.dispose();
      channel.dispose();
    });
  });

  group('ReliableTransferManager — cancellation', () {
    test('cancelAll cancels active transfer', () async {
      final channel = FakeReliableChannel();
      channel.onSend = (_) {};

      final manager = ReliableTransferManager(channel: channel);

      final sendFuture = manager.sendReliable([1, 2, 3]);
      await Future<void>.delayed(Duration.zero);

      manager.cancelAll();

      final result = await sendFuture;
      expect(result, TransferResult.cancelled);

      manager.dispose();
      channel.dispose();
    });
  });

  group('ReliableTransferManager — disposal', () {
    test('dispose cleans up without hanging', () async {
      final channel = FakeReliableChannel();
      channel.onSend = (_) {};

      final manager = ReliableTransferManager(channel: channel);

      // Start a transfer but don't await it.
      manager.sendReliable([1, 2, 3]);
      await Future<void>.delayed(Duration.zero);

      // Dispose immediately — should not leave timers or listeners.
      manager.dispose();
      channel.dispose();

      // Verify no error on next tick.
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });

    test('dispose after delivery is harmless', () async {
      final channel = FakeReliableChannel();
      final sentCompleter = Completer<List<int>>();
      channel.onSend = (bytes) {
        if (!sentCompleter.isCompleted) sentCompleter.complete(bytes);
      };

      final manager = ReliableTransferManager(channel: channel);

      final sendFuture = manager.sendReliable([1, 2, 3]);

      final sentBytes = await sentCompleter.future;
      final env = TransferEnvelope.decode(sentBytes)!;
      final ack = TransferEnvelope(
        type: TransferEnvelope.ackType,
        transferId: env.transferId,
      );
      channel.receive(ack.encode());

      await sendFuture;
      manager.dispose();
      channel.dispose();
    });
  });

  group('ReliableTransferManager — failed then recover', () {
    test('failed transfer does not block next transfer', () async {
      final channel = FakeReliableChannel();

      final manager = ReliableTransferManager(
        channel: channel,
        config: const ReliableTransferConfig(
          ackTimeoutMs: 30,
          maxAttempts: 2,
        ),
      );

      // First transfer fails (no ACK).
      final r1 = await manager.sendReliable([1]);
      expect(r1, TransferResult.failed);

      // Second transfer succeeds with ACK.
      final sentCompleter = Completer<List<int>>();
      channel.onSend = (bytes) {
        if (!sentCompleter.isCompleted) sentCompleter.complete(bytes);
      };

      final sendFuture = manager.sendReliable([2]);

      final sentBytes = await sentCompleter.future;
      final env = TransferEnvelope.decode(sentBytes)!;
      final ack = TransferEnvelope(
        type: TransferEnvelope.ackType,
        transferId: env.transferId,
      );
      channel.receive(ack.encode());

      final r2 = await sendFuture;
      expect(r2, TransferResult.delivered);

      manager.dispose();
      channel.dispose();
    });
  });

  group('ReliableTransferManager — channel not connected', () {
    test('sendReliable fails when channel disconnected', () async {
      final channel = FakeReliableChannel();
      channel.simulateDisconnect();

      final manager = ReliableTransferManager(channel: channel);

      final result = await manager.sendReliable([1, 2, 3]);
      expect(result, TransferResult.failed);

      manager.dispose();
      channel.dispose();
    });
  });

  group('ReliableTransferManager — write failure', () {
    test('write error fails transfer immediately', () async {
      final channel = FakeReliableChannel();
      channel.onSend = (_) => throw Exception('write failed');

      final manager = ReliableTransferManager(channel: channel);

      final result = await manager.sendReliable([1, 2, 3]);
      expect(result, TransferResult.failed);

      manager.dispose();
      channel.dispose();
    });
  });

  group('ReliableTransferManager — state stream', () {
    test('emits waitingForAck then delivered', () async {
      final channel = FakeReliableChannel();
      final sentCompleter = Completer<List<int>>();
      channel.onSend = (bytes) {
        if (!sentCompleter.isCompleted) sentCompleter.complete(bytes);
      };

      final manager = ReliableTransferManager(channel: channel);

      final states = <TransferState>[];
      manager.stateStream.listen(states.add);

      final sendFuture = manager.sendReliable([1]);

      final sentBytes = await sentCompleter.future;
      final env = TransferEnvelope.decode(sentBytes)!;
      final ack = TransferEnvelope(
        type: TransferEnvelope.ackType,
        transferId: env.transferId,
      );
      channel.receive(ack.encode());

      await sendFuture;
      await Future<void>.delayed(Duration.zero);

      expect(states, contains(TransferState.waitingForAck));
      expect(states, contains(TransferState.delivered));

      manager.dispose();
      channel.dispose();
    });

    test('emits retrying on timeout', () async {
      final channel = FakeReliableChannel();
      channel.onSend = (_) {};

      final manager = ReliableTransferManager(
        channel: channel,
        config: const ReliableTransferConfig(
          ackTimeoutMs: 30,
          maxAttempts: 3,
        ),
      );

      final states = <TransferState>[];
      manager.stateStream.listen(states.add);

      final sendFuture = manager.sendReliable([1]);
      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(states, contains(TransferState.retrying));

      await sendFuture;
      manager.dispose();
      channel.dispose();
    });
  });

  group('ReliableTransferManager — empty payload', () {
    test('empty payload is allowed', () async {
      final channel = FakeReliableChannel();
      final sentCompleter = Completer<List<int>>();
      channel.onSend = (bytes) {
        if (!sentCompleter.isCompleted) sentCompleter.complete(bytes);
      };

      final manager = ReliableTransferManager(channel: channel);

      final sendFuture = manager.sendReliable([]);

      final sentBytes = await sentCompleter.future;
      final env = TransferEnvelope.decode(sentBytes);
      expect(env!.payload, isEmpty);

      final ack = TransferEnvelope(
        type: TransferEnvelope.ackType,
        transferId: env.transferId,
      );
      channel.receive(ack.encode());

      final result = await sendFuture;
      expect(result, TransferResult.delivered);

      manager.dispose();
      channel.dispose();
    });
  });

  group('ReliableTransferManager — concurrent send prevention', () {
    test('second send while pending returns failed', () async {
      final channel = FakeReliableChannel();
      List<int>? firstBytes;
      final firstSent = Completer<void>();
      channel.onSend = (bytes) {
        if (!firstSent.isCompleted) {
          firstBytes = bytes;
          firstSent.complete();
        }
      };

      final manager = ReliableTransferManager(channel: channel);

      final r1Future = manager.sendReliable([1]);
      await firstSent.future;

      final r2 = await manager.sendReliable([2]);
      expect(r2, TransferResult.failed);

      // Complete the first transfer.
      final env = TransferEnvelope.decode(firstBytes!);
      final ack = TransferEnvelope(
        type: TransferEnvelope.ackType,
        transferId: env!.transferId,
      );
      channel.receive(ack.encode());

      final r1 = await r1Future;
      expect(r1, TransferResult.delivered);

      manager.dispose();
      channel.dispose();
    });
  });
}
