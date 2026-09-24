import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/features/message/models/message_id.dart';
import 'package:onebit/features/message/models/message_state.dart';
import 'package:onebit/features/message/models/onebit_message.dart';

void main() {
  late MessageId testId;
  late String testSource;
  late String testDestination;

  setUpAll(() {
    // Generate a valid 64-char hex peer ID.
    testSource = 'a' * 64;
    testDestination = 'b' * 64;
  });

  setUp(() {
    testId = MessageId();
  });

  group('OneBitMessage', () {
    test('creates with required fields and defaults', () {
      final msg = OneBitMessage(
        id: testId,
        sourcePeerId: testSource,
        destinationPeerId: testDestination,
        createdAt: DateTime.utc(2026, 1, 1),
      );

      expect(msg.id, equals(testId));
      expect(msg.sourcePeerId, equals(testSource));
      expect(msg.destinationPeerId, equals(testDestination));
      expect(msg.state, equals(MessageState.created));
      expect(msg.expiresAt, isNull);
      expect(msg.payloadSizeBytes, isNull);
    });

    test('defaults to MessageState.created', () {
      final msg = OneBitMessage(
        id: testId,
        sourcePeerId: testSource,
        destinationPeerId: testDestination,
        createdAt: DateTime.utc(2026, 1, 1),
      );

      expect(msg.state, equals(MessageState.created));
    });

    test('isLocalTo returns true when destination matches', () {
      final msg = OneBitMessage(
        id: testId,
        sourcePeerId: testSource,
        destinationPeerId: testDestination,
        createdAt: DateTime.utc(2026, 1, 1),
      );

      expect(msg.isLocalTo(testDestination), isTrue);
    });

    test('isLocalTo returns false when destination differs', () {
      final msg = OneBitMessage(
        id: testId,
        sourcePeerId: testSource,
        destinationPeerId: testDestination,
        createdAt: DateTime.utc(2026, 1, 1),
      );

      expect(msg.isLocalTo(testSource), isFalse);
    });

    test('isExpired returns false when no expiry set', () {
      final msg = OneBitMessage(
        id: testId,
        sourcePeerId: testSource,
        destinationPeerId: testDestination,
        createdAt: DateTime.utc(2026, 1, 1),
      );

      expect(msg.isExpired(), isFalse);
    });

    test('isExpired returns true when expiry in the past', () {
      final msg = OneBitMessage(
        id: testId,
        sourcePeerId: testSource,
        destinationPeerId: testDestination,
        createdAt: DateTime.utc(2026, 1, 1),
        expiresAt: DateTime.utc(2026, 1, 2),
      );

      // Current time is well after 2026-01-02.
      expect(msg.isExpired(), isTrue);
    });

    test('isExpired returns false when expiry in the future', () {
      final msg = OneBitMessage(
        id: testId,
        sourcePeerId: testSource,
        destinationPeerId: testDestination,
        createdAt: DateTime.utc(2026, 1, 1),
        expiresAt: DateTime.utc(2099, 12, 31),
      );

      expect(msg.isExpired(), isFalse);
    });

    test('isExpired respects explicit now parameter', () {
      final msg = OneBitMessage(
        id: testId,
        sourcePeerId: testSource,
        destinationPeerId: testDestination,
        createdAt: DateTime.utc(2026, 1, 1),
        expiresAt: DateTime.utc(2026, 6, 1),
      );

      // Before expiry.
      expect(
        msg.isExpired(now: DateTime.utc(2026, 3, 1)),
        isFalse,
      );
      // After expiry.
      expect(
        msg.isExpired(now: DateTime.utc(2026, 12, 1)),
        isTrue,
      );
    });

    group('isTerminal', () {
      test('created is not terminal', () {
        final msg = OneBitMessage(
          id: testId,
          sourcePeerId: testSource,
          destinationPeerId: testDestination,
          createdAt: DateTime.utc(2026, 1, 1),
        );
        expect(msg.isTerminal, isFalse);
      });

      test('delivered is terminal', () {
        final msg = OneBitMessage(
          id: testId,
          sourcePeerId: testSource,
          destinationPeerId: testDestination,
          createdAt: DateTime.utc(2026, 1, 1),
          state: MessageState.delivered,
        );
        expect(msg.isTerminal, isTrue);
      });

      test('failed is terminal', () {
        final msg = OneBitMessage(
          id: testId,
          sourcePeerId: testSource,
          destinationPeerId: testDestination,
          createdAt: DateTime.utc(2026, 1, 1),
          state: MessageState.failed,
        );
        expect(msg.isTerminal, isTrue);
      });

      test('expired is terminal', () {
        final msg = OneBitMessage(
          id: testId,
          sourcePeerId: testSource,
          destinationPeerId: testDestination,
          createdAt: DateTime.utc(2026, 1, 1),
          state: MessageState.expired,
        );
        expect(msg.isTerminal, isTrue);
      });

      test('rejected is terminal', () {
        final msg = OneBitMessage(
          id: testId,
          sourcePeerId: testSource,
          destinationPeerId: testDestination,
          createdAt: DateTime.utc(2026, 1, 1),
          state: MessageState.rejected,
        );
        expect(msg.isTerminal, isTrue);
      });
    });

    group('isActive', () {
      test('created is active', () {
        final msg = OneBitMessage(
          id: testId,
          sourcePeerId: testSource,
          destinationPeerId: testDestination,
          createdAt: DateTime.utc(2026, 1, 1),
        );
        expect(msg.isActive, isTrue);
      });

      test('ready is active', () {
        final msg = OneBitMessage(
          id: testId,
          sourcePeerId: testSource,
          destinationPeerId: testDestination,
          createdAt: DateTime.utc(2026, 1, 1),
          state: MessageState.ready,
        );
        expect(msg.isActive, isTrue);
      });

      test('relaying is active', () {
        final msg = OneBitMessage(
          id: testId,
          sourcePeerId: testSource,
          destinationPeerId: testDestination,
          createdAt: DateTime.utc(2026, 1, 1),
          state: MessageState.relaying,
        );
        expect(msg.isActive, isTrue);
      });
    });

    test('copyWith produces new instance preserving identity', () {
      final original = OneBitMessage(
        id: testId,
        sourcePeerId: testSource,
        destinationPeerId: testDestination,
        createdAt: DateTime.utc(2026, 1, 1),
      );

      final updated = original.copyWith(state: MessageState.queued);

      expect(updated.id, equals(original.id));
      expect(updated.sourcePeerId, equals(original.sourcePeerId));
      expect(updated.destinationPeerId, equals(original.destinationPeerId));
      expect(updated.createdAt, equals(original.createdAt));
      expect(updated.state, equals(MessageState.queued));
    });

    test('copyWith preserves expiresAt when not specified', () {
      final original = OneBitMessage(
        id: testId,
        sourcePeerId: testSource,
        destinationPeerId: testDestination,
        createdAt: DateTime.utc(2026, 1, 1),
        expiresAt: DateTime.utc(2026, 12, 31),
      );

      final updated = original.copyWith(state: MessageState.ready);

      expect(updated.expiresAt, equals(DateTime.utc(2026, 12, 31)));
    });

    test('equality based on MessageId only', () {
      final msg1 = OneBitMessage(
        id: testId,
        sourcePeerId: testSource,
        destinationPeerId: 'c' * 64,
        createdAt: DateTime.utc(2026, 1, 1),
      );
      final msg2 = OneBitMessage(
        id: testId,
        sourcePeerId: 'd' * 64,
        destinationPeerId: 'e' * 64,
        createdAt: DateTime.utc(2099, 1, 1),
        state: MessageState.delivered,
      );

      expect(msg1, equals(msg2));
      expect(msg1.hashCode, equals(msg2.hashCode));
    });

    test('inequality for different IDs', () {
      final msg1 = OneBitMessage(
        id: MessageId(),
        sourcePeerId: testSource,
        destinationPeerId: testDestination,
        createdAt: DateTime.utc(2026, 1, 1),
      );
      final msg2 = OneBitMessage(
        id: MessageId(),
        sourcePeerId: testSource,
        destinationPeerId: testDestination,
        createdAt: DateTime.utc(2026, 1, 1),
      );

      expect(msg1 == msg2, isFalse);
    });

    test('toString includes truncated peer IDs', () {
      final msg = OneBitMessage(
        id: testId,
        sourcePeerId: testSource,
        destinationPeerId: testDestination,
        createdAt: DateTime.utc(2026, 1, 1),
      );

      final str = msg.toString();
      expect(str, contains('OneBitMessage('));
      expect(str, contains('state=created'));
    });
  });
}
