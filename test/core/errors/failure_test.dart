import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/core/constants/app_error_codes.dart';
import 'package:onebit/core/errors/exception_mapper.dart';
import 'package:onebit/core/errors/failure.dart';

void main() {
  group('ExceptionMapper', () {
    test('maps FormatException to SerializationFailure', () {
      final failure = ExceptionMapper.map(const FormatException('nope'));
      expect(failure, isA<SerializationFailure>());
      expect(failure.kind, AppErrorCode.serialization);
    });

    test('maps ArgumentError to ConfigurationFailure', () {
      final failure = ExceptionMapper.map(ArgumentError('bad arg'));
      expect(failure, isA<ConfigurationFailure>());
      expect(failure.kind, AppErrorCode.configuration);
    });

    test('maps UnsupportedError to UnsupportedOperationFailure', () {
      final failure = ExceptionMapper.map(UnsupportedError('not yet'));
      expect(failure, isA<UnsupportedOperationFailure>());
      expect(failure.isUnsupported, isTrue);
    });

    test('maps UnimplementedError as unsupported (subclass coverage)', () {
      final failure = ExceptionMapper.map(UnimplementedError());
      expect(failure, isA<UnsupportedOperationFailure>());
    });

    test('maps RangeError through ArgumentError coverage', () {
      final failure = ExceptionMapper.map(RangeError('out of range'));
      expect(failure, isA<ConfigurationFailure>());
    });

    test('falls back to UnexpectedFailure for unknown errors', () {
      final failure = ExceptionMapper.map(Exception('weird'));
      expect(failure, isA<UnexpectedFailure>());
      expect(failure.kind, AppErrorCode.unexpected);
      expect(failure.cause, isA<Exception>());
    });

    test('preserves the caller-supplied stack trace', () {
      final trace = StackTrace.current;
      final failure = ExceptionMapper.map(Exception('x'), trace);
      expect(failure.stackTrace, trace);
    });
  });

  group('ObjectX.asFailure', () {
    test('converts with the mapping extension', () {
      final failure = const FormatException('x').asFailure();
      expect(failure, isA<SerializationFailure>());
    });
  });

  group('Failure hierarchy', () {
    test('each failure keeps a stable error code', () {
      expect(const StorageFailure().kind.code, 'OB-ST-0002');
      expect(const PlatformFailure().kind.code, 'OB-PL-0003');
      expect(const CancelledFailure().kind.code, 'OB-CN-0007');
    });

    test('toString includes the code and message', () {
      const failure = StorageFailure(message: 'disk full');
      final text = failure.toString();
      expect(text, contains('OB-ST-0002'));
      expect(text, contains('disk full'));
    });

    test('UnsupportedOperationFailure reports the feature', () {
      const failure = UnsupportedOperationFailure(feature: 'bluetooth');
      expect(failure.isUnsupported, isTrue);
      expect(failure.feature, 'bluetooth');
    });
  });
}
