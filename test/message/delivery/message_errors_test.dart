import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/features/message/delivery/message_errors.dart';

void main() {
  group('MessageError hierarchy', () {
    test('InvalidMessageError has message and code', () {
      const err = InvalidMessageError('bad data', code: 'BAD');
      expect(err.message, equals('bad data'));
      expect(err.code, equals('BAD'));
      expect(err, isA<MessageError>());
    });

    test('InvalidDestinationError has code', () {
      const err = InvalidDestinationError('no dest');
      expect(err.code, equals('INVALID_DESTINATION'));
      expect(err, isA<MessageError>());
    });

    test('InvalidSourceError has code', () {
      const err = InvalidSourceError('no source');
      expect(err.code, equals('INVALID_SOURCE'));
      expect(err, isA<MessageError>());
    });

    test('NoRouteError has code', () {
      const err = NoRouteError('no route');
      expect(err.code, equals('NO_ROUTE'));
      expect(err, isA<MessageError>());
    });

    test('UnsupportedVersionError has code', () {
      const err = UnsupportedVersionError('old version');
      expect(err.code, equals('UNSUPPORTED_VERSION'));
      expect(err, isA<MessageError>());
    });

    test('MessageTooLargeError has code', () {
      const err = MessageTooLargeError('too big');
      expect(err.code, equals('MESSAGE_TOO_LARGE'));
      expect(err, isA<MessageError>());
    });

    test('SecurityRejectedError has code', () {
      const err = SecurityRejectedError('denied');
      expect(err.code, equals('SECURITY_REJECTED'));
      expect(err, isA<MessageError>());
    });

    test('toString includes error message', () {
      const err = MessageError('test error');
      expect(err.toString(), equals('MessageError(test error)'));
    });
  });
}
