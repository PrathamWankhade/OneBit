import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/core/errors/failure.dart';
import 'package:onebit/core/result/result.dart';

void main() {
  group('Result', () {
    test('Ok carries a value and reports success', () {
      const Result<int> result = Ok(42);

      expect(result.isOk, isTrue);
      expect(result.isErr, isFalse);
      expect(result.value, 42);
      expect(result.unwrapOr(-1), 42);
    });

    test('Err carries a failure and reports failure', () {
      const failure = StorageFailure(message: 'disk full');
      const Result<int> result = Err(failure);

      expect(result.isOk, isFalse);
      expect(result.isErr, isTrue);
      expect(result.failure, failure);
      expect(result.unwrapOr(-1), -1);
    });

    test('fold routes to the success branch', () {
      const Result<int> result = Ok(7);
      final label = result.fold((v) => 'value:$v', (f) => 'failed');
      expect(label, 'value:7');
    });

    test('fold routes to the failure branch', () {
      const Result<int> result = Err(UnexpectedFailure());
      final label = result.fold((v) => 'value:$v', (f) => 'failed');
      expect(label, 'failed');
    });

    test('map transforms only successful values', () {
      const Result<int> ok = Ok(3);
      const Result<int> err = Err(StorageFailure());
      expect(ok.map((v) => v * 2).value, 6);
      expect(err.map((v) => v * 2).isErr, isTrue);
    });

    test('capture turns a throwing computation into Err', () {
      final result = Result.capture<int>(() => throw StateError('boom'));
      expect(result.isErr, isTrue);
      expect(result.failure, isA<UnexpectedFailure>());
    });

    test('capture keeps successful computations', () {
      final result = Result.capture<int>(() => 5);
      expect(result.value, 5);
    });
  });

  group('Future.toResult', () {
    test('resolves to Ok', () async {
      final result = await Future<int>.value(1).toResult();
      expect(result.isOk, isTrue);
    });

    test('resolves to Err without throwing', () async {
      final result = await Future<int>.error(
        const FormatException('bad'),
      ).toResult();
      expect(result.isErr, isTrue);
      expect(result.failure, isA<SerializationFailure>());
    });
  });
}
