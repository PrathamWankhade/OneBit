import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/features/message/delivery/message_delivery_result.dart';
import 'package:onebit/features/message/models/message_id.dart';

void main() {
  late MessageId testId;

  setUp(() {
    testId = MessageId();
  });

  group('MessageDeliveryResult', () {
    test('accepted result has correct status', () {
      final result = MessageDeliveryResult.accepted(testId);

      expect(result.status, equals(DeliveryStatus.accepted));
      expect(result.messageId, equals(testId));
      expect(result.isAccepted, isTrue);
      expect(result.isRetryable, isFalse);
      expect(result.failureReason, isNull);
    });

    test('noRoute result has correct status', () {
      final result = MessageDeliveryResult.noRoute(testId);

      expect(result.status, equals(DeliveryStatus.noRoute));
      expect(result.isAccepted, isFalse);
      expect(result.isRetryable, isTrue);
      expect(result.failureReason, isNull);
    });

    test('invalid result has failure reason', () {
      final result = MessageDeliveryResult.invalid(testId, 'Bad format');

      expect(result.status, equals(DeliveryStatus.invalid));
      expect(result.failureReason, equals('Bad format'));
      expect(result.isRetryable, isFalse);
    });

    test('rejected result has failure reason', () {
      final result = MessageDeliveryResult.rejected(testId, 'Not trusted');

      expect(result.status, equals(DeliveryStatus.rejected));
      expect(result.failureReason, equals('Not trusted'));
      expect(result.isRetryable, isFalse);
    });

    test('tooLarge result has correct status', () {
      final result = MessageDeliveryResult.tooLarge(testId);

      expect(result.status, equals(DeliveryStatus.tooLarge));
      expect(result.isRetryable, isFalse);
    });

    test('expired result has correct status', () {
      final result = MessageDeliveryResult.expired(testId);

      expect(result.status, equals(DeliveryStatus.expired));
      expect(result.isRetryable, isFalse);
    });

    test('unavailable result has correct status', () {
      final result = MessageDeliveryResult.unavailable(testId);

      expect(result.status, equals(DeliveryStatus.unavailable));
      expect(result.isRetryable, isTrue);
    });

    test('toString includes message ID prefix', () {
      final result = MessageDeliveryResult.accepted(testId);
      final str = result.toString();

      expect(str, startsWith('MessageDeliveryResult('));
      expect(str, contains('status=accepted'));
    });
  });
}
