import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/core/errors/failure.dart';
import 'package:onebit/core/result/result.dart';
import 'package:onebit/features/packet/domain/packet.dart';
import 'package:onebit/features/packet/domain/packet_flag.dart';
import 'package:onebit/features/packet/domain/packet_header.dart';
import 'package:onebit/features/packet/domain/packet_payload.dart';
import 'package:onebit/features/packet/domain/packet_type.dart';
import 'package:onebit/features/packet/validation/packet_validator.dart';

Packet _packet({
  PacketType type = PacketType.message,
  Set<PacketFlag> flags = const {},
  int fragmentIndex = 0,
  int fragmentCount = 1,
  List<int> signature = const [],
  PacketPayload payload = const PacketPayload(
    type: PacketPayloadType.binary,
    bytes: <int>[1, 2, 3],
  ),
}) {
  return Packet(
    header: PacketHeader(
      sequence: 1,
      source: 'a',
      destination: type == PacketType.broadcast ? '' : 'b',
      type: type,
      flags: flags,
      fragmentIndex: fragmentIndex,
      fragmentCount: fragmentCount,
    ),
    payload: payload,
    signature: signature,
  );
}

void main() {
  const validator = PacketValidator();

  group('PacketValidator', () {
    test('accepts a well-formed message', () {
      expect(validator.validate(_packet()), isA<Ok<Packet>>());
    });

    test('broadcast requires matching type/flag/destination', () {
      final broadcast = _packet(
        type: PacketType.broadcast,
        flags: const {PacketFlag.broadcastFlag},
        signature: const [],
      );
      expect(validator.validate(broadcast), isA<Ok<Packet>>());
    });

    test(
      'broadcast with a non-broadcast flag is rejected (flagsConsistent)',
      () {
        final bad = _packet(flags: const {PacketFlag.broadcastFlag});
        expect(validator.validate(bad), isErrWithRule('flagsConsistent'));
      },
    );

    test('broadcast type requires the flag (flagsConsistent)', () {
      final bad = _packet(type: PacketType.broadcast);
      expect(validator.validate(bad), isErrWithRule('flagsConsistent'));
    });

    test('unfragmented frame must declare count 1 (fragmentIndexCovered)', () {
      final bad = _packet(fragmentIndex: 0, fragmentCount: 3);
      expect(validator.validate(bad), isErrWithRule('fragmentIndexCovered'));
    });

    test('fragmented frame keeps count within maxFragments '
        '(fragmentCountAllowed)', () {
      final ok = _packet(
        flags: const {PacketFlag.fragmented},
        fragmentIndex: 0,
        fragmentCount: 200,
      );
      expect(validator.validate(ok), isA<Ok<Packet>>());
      final tooMany = _packet(
        flags: const {PacketFlag.fragmented},
        fragmentIndex: 0,
        fragmentCount: 257,
      );
      expect(
        validator.validate(tooMany),
        isErrWithRule('fragmentCountAllowed'),
      );
    });

    test('signature only on fragment 0 (signaturePresent)', () {
      final midFragment = _packet(
        flags: const {PacketFlag.fragmented},
        fragmentIndex: 2,
        fragmentCount: 5,
        signature: const [0xDE, 0xAD],
      );
      expect(
        validator.validate(midFragment),
        isErrWithRule('signaturePresent'),
      );
    });

    test('encrypted payload requires the flag and vice versa '
        '(flagsConsistent)', () {
      final shouldHaveFlag = _packet(
        payload: const PacketPayload(
          type: PacketPayloadType.encrypted,
          bytes: <int>[9, 9],
        ),
      );
      expect(
        validator.validate(shouldHaveFlag),
        isErrWithRule('flagsConsistent'),
      );
      final flaggedButPlain = _packet(
        flags: const {PacketFlag.encrypted},
        payload: const PacketPayload(
          type: PacketPayloadType.binary,
          bytes: <int>[1],
        ),
      );
      expect(
        validator.validate(flaggedButPlain),
        isErrWithRule('flagsConsistent'),
      );
    });

    test('compressed flag without compressed type is rejected '
        '(flagsConsistent)', () {
      final bad = _packet(flags: const {PacketFlag.compressed});
      expect(validator.validate(bad), isErrWithRule('flagsConsistent'));
    });
  });
}

Matcher isErrWithRule(String rule) => predicate(
  (value) =>
      value is Err<Packet> &&
      value.failure is PacketValidationFailure &&
      (value.failure! as dynamic).rule == rule,
  'Err with rule $rule',
);
