import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/core/errors/failure.dart';
import 'package:onebit/core/result/result.dart';
import 'package:onebit/features/packet/data/packet_repository_impl.dart';
import 'package:onebit/features/packet/domain/packet.dart';
import 'package:onebit/features/packet/domain/packet_payload.dart';
import 'package:onebit/features/packet/engine/packet_engine.dart';
import 'package:onebit/features/packet/fragmentation/packet_fragmenter.dart';
import 'package:onebit/features/packet/reassembly/reassembly_engine.dart';
import 'package:onebit/features/packet/serialization/packet_serializer.dart';
import 'package:onebit/features/packet/validation/packet_validator.dart';

void main() {
  PacketEngine newEngine() {
    const serializer = PacketSerializer();
    return PacketEngine(
      source: 'node-1',
      serializer: serializer,
      validator: const PacketValidator(),
      fragmenter: PacketFragmenter(serializer: serializer),
      reassembly: ReassemblyEngine(),
    );
  }

  group('PacketRepositoryImpl', () {
    test('send() emits one frame per budget and returns Ok', () async {
      final inbound = StreamController<List<int>>();
      final sent = <int>[];
      final repository = PacketRepositoryImpl(
        engine: newEngine(),
        sendFrame: (destination, bytes, ttl) async {
          sent.add(bytes.length);
          return const Ok(null);
        },
        inbound: inbound.stream,
      );
      final result = await repository.send(
        destination: 'node-2',
        payload: 'hello'.codeUnits,
      );
      expect(result, isA<Ok<void>>());
      expect(sent, hasLength(1));
      await inbound.close();
      repository.dispose();
    });

    test('send() fragments a large payload within the mtu budget', () async {
      final inbound = StreamController<List<int>>();
      final frames = <int>[];
      final repository = PacketRepositoryImpl(
        engine: newEngine(),
        sendFrame: (destination, bytes, ttl) async {
          frames.add(bytes.length);
          return const Ok(null);
        },
        inbound: inbound.stream,
        mtu: 185,
      );
      final result = await repository.send(
        destination: 'node-2',
        payload: List<int>.generate(1500, (i) => i % 128),
      );
      expect(result, isA<Ok<void>>());
      expect(frames.length, greaterThan(2));
      for (final size in frames) {
        expect(size, lessThanOrEqualTo(185));
      }
      await inbound.close();
      repository.dispose();
    });

    test(
      'send() aborts on a transport failure and surfaces the error',
      () async {
        final inbound = StreamController<List<int>>();
        var forwarded = 0;
        final repository = PacketRepositoryImpl(
          engine: newEngine(),
          sendFrame: (destination, bytes, ttl) async {
            forwarded++;
            if (forwarded == 2) {
              return const Err(
                PacketValidationFailure(
                  rule: 'transport',
                  message: 'radio went away',
                ),
              );
            }
            return const Ok(null);
          },
          inbound: inbound.stream,
          mtu: 100,
        );
        final result = await repository.send(
          destination: 'node-2',
          payload: List<int>.generate(1500, (i) => i % 256),
        );
        expect(result.isErr, isTrue);
        expect(forwarded, 2);
        await inbound.close();
        repository.dispose();
      },
    );

    test(
      'inbound frames decode into delivered packets on the stream',
      () async {
        final inbound = StreamController<List<int>>();
        final engine = newEngine();
        final repository = PacketRepositoryImpl(
          engine: engine,
          sendFrame: (destination, bytes, ttl) async => const Ok(null),
          inbound: inbound.stream,
        );
        final delivered = <Packet>[];
        final subscription = repository.observeDeliveredPackets().listen((
          result,
        ) {
          if (result.isOk) delivered.add(result.value!);
        });

        final packet = engine.createMessage(
          destination: 'node-2',
          payload: PacketPayload.utf8('ping'),
        );
        inbound.add(engine.serializer.encode(packet).value!);
        await Future<void>.delayed(Duration.zero);
        expect(delivered, hasLength(1));
        expect(delivered.single.payload.bytes, 'ping'.codeUnits);

        await subscription.cancel();
        await inbound.close();
        repository.dispose();
      },
    );

    test('inbound fragments reassemble before delivery', () async {
      final inbound = StreamController<List<int>>();
      final engine = newEngine();
      final repository = PacketRepositoryImpl(
        engine: engine,
        sendFrame: (destination, bytes, ttl) async => const Ok(null),
        inbound: inbound.stream,
      );
      final delivered = <Packet>[];
      final subscription = repository.observeDeliveredPackets().listen((
        result,
      ) {
        if (result.isOk) delivered.add(result.value!);
      });

      final packet = engine.createMessage(
        destination: 'node-2',
        payload: PacketPayload.binary(List<int>.generate(900, (i) => i % 7)),
      );
      final frames = engine.framesFor(packet, mtu: 185).value!.frames;
      for (final frame in frames.reversed) {
        inbound.add(frame.bytes);
      }
      await Future<void>.delayed(Duration.zero);
      expect(delivered, hasLength(1));
      expect(delivered.single.payload.bytes.length, 900);
      expect(delivered.single.payload.utf8Text, isNull);

      await subscription.cancel();
      await inbound.close();
      repository.dispose();
    });
  });
}
