import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/features/protocol/delivery_state.dart';

/// I9.14.a — the contract is only worth having if every word it can
/// say is backed by a fact. This pins the mapping in both directions,
/// including the direction doubt travels: an unknown status reads as
/// queued, never as delivered.
void main() {
  DeliveryState stateOf(
    String status, {
    bool transmitting = false,
    int attempts = 0,
  }) =>
      deliveryStateOf(
        status: status,
        transmitting: transmitting,
        retryAttempts: attempts,
      );

  group('I9.14.a delivery state contract', () {
    test('the settled row statuses speak for themselves', () {
      expect(stateOf('expired'), DeliveryState.expired);
      expect(stateOf('failed'), DeliveryState.failed);
      expect(stateOf('read'), DeliveryState.read);
      expect(stateOf('delivered'), DeliveryState.delivered);
    });

    test('sent means handed off, not arrived', () {
      expect(stateOf('sent'), DeliveryState.relayed);
    });

    test('queued reads as transmitting while an attempt is on the wire',
        () {
      expect(
        stateOf('queued', transmitting: true),
        DeliveryState.transmitting,
      );
    });

    test('queued reads as retrying once an attempt has failed', () {
      expect(stateOf('queued', attempts: 1), DeliveryState.retrying);
    });

    test('a live attempt outranks a scheduled retry', () {
      expect(
        stateOf('queued', transmitting: true, attempts: 3),
        DeliveryState.transmitting,
      );
    });

    test('a settled status is not talked out of itself by the radio',
        () {
      // The wire cannot be mid-attempt for a row the receipts already
      // retired; facts about attempts only colour the queued state.
      expect(
        stateOf('delivered', transmitting: true, attempts: 5),
        DeliveryState.delivered,
      );
    });

    test('a fresh queued row has not been tried at all', () {
      expect(stateOf('queued'), DeliveryState.queued);
    });

    test('an unknown status reads as queued, never as delivered', () {
      expect(stateOf('received'), DeliveryState.queued);
      expect(stateOf('sending'), DeliveryState.queued);
      expect(stateOf(''), DeliveryState.queued);
    });
  });

  group('I9.14.a labels', () {
    test('the checks need no words', () {
      expect(deliveryLabelOf(DeliveryState.relayed), isNull);
      expect(deliveryLabelOf(DeliveryState.delivered), isNull);
      expect(deliveryLabelOf(DeliveryState.read), isNull);
    });

    test('every state that could mislead says what it means', () {
      expect(deliveryLabelOf(DeliveryState.queued), 'Queued');
      expect(deliveryLabelOf(DeliveryState.transmitting), 'Sending…');
      expect(deliveryLabelOf(DeliveryState.retrying), 'Retrying');
      expect(
        deliveryLabelOf(DeliveryState.expired),
        'Expired — never reached recipient',
      );
      expect(deliveryLabelOf(DeliveryState.failed), 'Failed');
    });
  });
}
