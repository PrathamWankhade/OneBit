import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/features/message/application/message_controller.dart';
import 'package:onebit/features/message/application/outbound_message_store.dart';
import 'package:onebit/features/message/models/message_envelope.dart';
import 'package:onebit/features/message/models/message_state.dart';

void main() {
  const localPeerId =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const remotePeerId =
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

  MessageController createController({String? localPeerIdParam}) {
    return MessageController(
      store: OutboundMessageStore(),
      localPeerId: localPeerIdParam ?? localPeerId,
    );
  }

  group('MessageController', () {
    test('localPeerId is accessible', () {
      final controller = createController();
      expect(controller.localPeerId, equals(localPeerId));
    });

    test('createMessage succeeds with valid input', () {
      final controller = createController();
      final result = controller.createMessage(
        destinationPeerId: remotePeerId,
        content: 'Hello, world!',
      );

      expect(result, isA<MessageCreationSuccess>());
      final success = result as MessageCreationSuccess;
      expect(success.outbound.text, equals('Hello, world!'));
      expect(success.outbound.sourcePeerId, equals(localPeerId));
      expect(success.outbound.destinationPeerId, equals(remotePeerId));
      expect(success.outbound.id.value.length, equals(36));
    });

    test('createMessage fails with empty destination', () {
      final controller = createController();
      final result = controller.createMessage(
        destinationPeerId: '',
        content: 'Hello',
      );

      expect(result, isA<MessageCreationFailure>());
      final failure = result as MessageCreationFailure;
      expect(failure.error, contains('Empty destination'));
    });

    test('createMessage fails with invalid destination length', () {
      final controller = createController();
      final result = controller.createMessage(
        destinationPeerId: 'abc123',
        content: 'Hello',
      );

      expect(result, isA<MessageCreationFailure>());
      final failure = result as MessageCreationFailure;
      expect(failure.error, contains('Invalid destination PeerId'));
    });

    test('createMessage fails with empty content', () {
      final controller = createController();
      final result = controller.createMessage(
        destinationPeerId: remotePeerId,
        content: '',
      );

      expect(result, isA<MessageCreationFailure>());
      final failure = result as MessageCreationFailure;
      expect(failure.error, contains('cannot be empty'));
    });

    test('createMessage fails with whitespace-only content', () {
      final controller = createController();
      final result = controller.createMessage(
        destinationPeerId: remotePeerId,
        content: '   ',
      );

      expect(result, isA<MessageCreationFailure>());
      final failure = result as MessageCreationFailure;
      expect(failure.error, contains('cannot be empty'));
    });

    test('createMessage fails with oversized content', () {
      final controller = createController();
      final bigContent = 'x' * (maxMessagePayloadSize + 1);
      final result = controller.createMessage(
        destinationPeerId: remotePeerId,
        content: bigContent,
      );

      expect(result, isA<MessageCreationFailure>());
      final failure = result as MessageCreationFailure;
      expect(failure.error, contains('too large'));
    });

    test('createMessage stores message in store', () {
      final controller = createController();
      controller.createMessage(
        destinationPeerId: remotePeerId,
        content: 'Hello',
      );

      expect(
        controller.getMessagesForDestination(remotePeerId).length,
        equals(1),
      );
    });

    test('createMessage trims content', () {
      final controller = createController();
      final result = controller.createMessage(
        destinationPeerId: remotePeerId,
        content: '  Hello  ',
      );

      final success = result as MessageCreationSuccess;
      expect(success.outbound.text, equals('Hello'));
    });

    test('createMessage generates unique IDs', () {
      final controller = createController();
      final result1 = controller.createMessage(
        destinationPeerId: remotePeerId,
        content: 'Message 1',
      );
      final result2 = controller.createMessage(
        destinationPeerId: remotePeerId,
        content: 'Message 2',
      );

      final s1 = result1 as MessageCreationSuccess;
      final s2 = result2 as MessageCreationSuccess;
      expect(s1.outbound.id, isNot(equals(s2.outbound.id)));
    });

    test('createMessage sets createdAt to UTC', () {
      final controller = createController();
      final result = controller.createMessage(
        destinationPeerId: remotePeerId,
        content: 'Hello',
      );

      final success = result as MessageCreationSuccess;
      expect(success.outbound.createdAt.isUtc, isTrue);
    });

    test('getMessagesForDestination returns empty for unknown peer', () {
      final controller = createController();
      expect(controller.getMessagesForDestination('cc' * 32), isEmpty);
    });

    test('message payloadSizeBytes matches content length', () {
      final controller = createController();
      final result = controller.createMessage(
        destinationPeerId: remotePeerId,
        content: 'Hello',
      );

      final success = result as MessageCreationSuccess;
      expect(success.outbound.message.payloadSizeBytes, equals(5));
    });

    test('createMessage without transmission service stays in created state',
        () {
      final controller = createController();
      final result = controller.createMessage(
        destinationPeerId: remotePeerId,
        content: 'Hello',
      );

      final success = result as MessageCreationSuccess;
      expect(success.outbound.message.state, equals(MessageState.created));
    });

    test('createMessage adds to store', () {
      final store = OutboundMessageStore();
      final controller = MessageController(
        store: store,
        localPeerId: localPeerId,
      );

      controller.createMessage(
        destinationPeerId: remotePeerId,
        content: 'Hello',
      );

      expect(store.length, equals(1));
    });

    test('outbound envelope matches created message', () {
      final controller = createController();
      final result = controller.createMessage(
        destinationPeerId: remotePeerId,
        content: 'Hello',
      );

      final success = result as MessageCreationSuccess;
      final envelope = success.outbound.envelope;
      expect(envelope.sourcePeerId, equals(localPeerId));
      expect(envelope.destinationPeerId, equals(remotePeerId));
      expect(envelope.messageId, equals(success.outbound.id));
      expect(
        String.fromCharCodes(envelope.payload),
        equals('Hello'),
      );
    });
  });
}
