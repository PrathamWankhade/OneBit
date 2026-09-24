import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/features/message/delivery/message_delivery_result.dart';
import 'package:onebit/features/message/delivery/message_delivery_service.dart';
import 'package:onebit/features/message/models/message_id.dart';
import 'package:onebit/features/message/models/message_state.dart';
import 'package:onebit/features/message/models/onebit_message.dart';
import 'package:onebit/features/routing/route.dart';

void main() {
  late String localPeerId;
  late String remotePeerId;

  setUpAll(() {
    localPeerId = 'a' * 64;
    remotePeerId = 'b' * 64;
  });

  OneBitMessage makeMessage({
    String? destination,
    MessageState state = MessageState.created,
    DateTime? expiresAt,
  }) {
    return OneBitMessage(
      id: MessageId(),
      sourcePeerId: localPeerId,
      destinationPeerId: destination ?? remotePeerId,
      createdAt: DateTime.utc(2026, 1, 1),
      state: state,
      expiresAt: expiresAt,
    );
  }

  Route makeRoute() => Route(
        destinationPeerId: 'b' * 64,
        nextHopPeerId: 'c' * 64,
        metric: 3,
        state: RouteState.active,
        source: RouteSource.advertised,
        createdAt: DateTime.utc(2026, 1, 1),
        lastValidatedAt: DateTime.utc(2026, 1, 1),
      );

  group('MessageDeliveryService', () {
    group('acceptMessage', () {
      test('accepts valid message with route', () {
        final service = MessageDeliveryService(
          localPeerId: localPeerId,
          routeLookup: (_) => makeRoute(),
        );

        final msg = makeMessage();
        final result = service.acceptMessage(msg);

        expect(result.isAccepted, isTrue);
        expect(result.status, equals(DeliveryStatus.accepted));

        final tracked = service.getMessage(msg.id);
        expect(tracked, isNotNull);
        expect(tracked!.state, equals(MessageState.ready));

        service.dispose();
      });

      test('rejects message with empty destination', () {
        final service = MessageDeliveryService(
          localPeerId: localPeerId,
          routeLookup: (_) => makeRoute(),
        );

        final msg = makeMessage(destination: '');
        final result = service.acceptMessage(msg);

        expect(result.isAccepted, isFalse);
        expect(result.status, equals(DeliveryStatus.invalid));

        service.dispose();
      });

      test('rejects message with empty source', () {
        final service = MessageDeliveryService(
          localPeerId: localPeerId,
          routeLookup: (_) => makeRoute(),
        );

        final msg = OneBitMessage(
          id: MessageId(),
          sourcePeerId: '',
          destinationPeerId: remotePeerId,
          createdAt: DateTime.utc(2026, 1, 1),
        );
        final result = service.acceptMessage(msg);

        expect(result.isAccepted, isFalse);
        expect(result.status, equals(DeliveryStatus.invalid));

        service.dispose();
      });

      test('returns noRoute when route lookup returns null', () {
        final service = MessageDeliveryService(
          localPeerId: localPeerId,
          routeLookup: (_) => null,
        );

        final msg = makeMessage();
        final result = service.acceptMessage(msg);

        expect(result.isAccepted, isFalse);
        expect(result.status, equals(DeliveryStatus.noRoute));

        final tracked = service.getMessage(msg.id);
        expect(tracked!.state, equals(MessageState.noRoute));

        service.dispose();
      });

      test('returns expired for expired message', () {
        final service = MessageDeliveryService(
          localPeerId: localPeerId,
          routeLookup: (_) => makeRoute(),
        );

        final msg = makeMessage(
          expiresAt: DateTime.utc(2020, 1, 1),
        );
        final result = service.acceptMessage(msg);

        expect(result.isAccepted, isFalse);
        expect(result.status, equals(DeliveryStatus.expired));

        service.dispose();
      });

      test('rejects message already in terminal state', () {
        final service = MessageDeliveryService(
          localPeerId: localPeerId,
          routeLookup: (_) => makeRoute(),
        );

        final msg = makeMessage(state: MessageState.delivered);
        final result = service.acceptMessage(msg);

        expect(result.isAccepted, isFalse);
        expect(result.status, equals(DeliveryStatus.invalid));

        service.dispose();
      });

      test('returns unavailable when disposed', () {
        final service = MessageDeliveryService(
          localPeerId: localPeerId,
          routeLookup: (_) => makeRoute(),
        );
        service.dispose();

        final msg = makeMessage();
        final result = service.acceptMessage(msg);

        expect(result.isAccepted, isFalse);
        expect(result.status, equals(DeliveryStatus.unavailable));
      });
    });

    group('message tracking', () {
      test('tracks multiple messages', () {
        final service = MessageDeliveryService(
          localPeerId: localPeerId,
          routeLookup: (_) => makeRoute(),
        );

        final msg1 = makeMessage();
        final msg2 = makeMessage();

        service.acceptMessage(msg1);
        service.acceptMessage(msg2);

        expect(service.messageCount, equals(2));
        expect(service.allMessages.length, equals(2));

        service.dispose();
      });

      test('messagesInState filters correctly', () {
        final routeLookupMap = <String, Route?>{
          remotePeerId: makeRoute(),
          'c' * 64: null,
        };
        final service = MessageDeliveryService(
          localPeerId: localPeerId,
          routeLookup: (dest) => routeLookupMap[dest],
        );

        service.acceptMessage(makeMessage(destination: remotePeerId));
        service.acceptMessage(makeMessage(destination: 'c' * 64));

        final readyMessages = service.messagesInState(MessageState.ready);
        final noRouteMessages = service.messagesInState(MessageState.noRoute);

        expect(readyMessages.length, equals(1));
        expect(noRouteMessages.length, equals(1));

        service.dispose();
      });

      test('getMessage returns null for unknown ID', () {
        final service = MessageDeliveryService(
          localPeerId: localPeerId,
          routeLookup: (_) => makeRoute(),
        );

        final unknown = service.getMessage(MessageId());
        expect(unknown, isNull);

        service.dispose();
      });
    });

    group('dispose', () {
      test('clears all tracked messages', () {
        final service = MessageDeliveryService(
          localPeerId: localPeerId,
          routeLookup: (_) => makeRoute(),
        );

        service.acceptMessage(makeMessage());
        expect(service.messageCount, equals(1));

        service.dispose();
        expect(service.messageCount, equals(0));
        expect(service.isDisposed, isTrue);
      });

      test('double dispose is safe', () {
        final service = MessageDeliveryService(
          localPeerId: localPeerId,
          routeLookup: (_) => makeRoute(),
        );

        service.dispose();
        service.dispose(); // Should not throw.
        expect(service.isDisposed, isTrue);
      });
    });
  });
}
