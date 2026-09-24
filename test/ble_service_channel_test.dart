import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:onebit/features/ble/ble_service.dart';
import 'package:onebit/features/ble/ble_state.dart';
import 'package:onebit/features/ble/ble_uuids.dart';
import 'package:onebit/features/reliable/ble_service_channel.dart';

import 'ble_service_channel_test.mocks.dart';

@GenerateMocks([BleService])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BleServiceChannel', () {
    late MockBleService mockService;
    late BleServiceChannel channel;

    setUp(() {
      mockService = MockBleService();
      when(mockService.current).thenReturn(const BleState());
      when(mockService.characteristicChanged)
          .thenAnswer((_) => const Stream.empty());

      channel = BleServiceChannel(
        service: mockService,
        deviceId: 'AA:BB:CC:DD',
      );
    });

    tearDown(() {
      if (!channel.isDisposed) {
        channel.dispose();
      }
    });

    group('startListening', () {
      test('subscribes to characteristicChanged stream', () {
        when(mockService.characteristicChanged)
            .thenAnswer((_) => const Stream.empty());

        channel.startListening();

        verify(mockService.characteristicChanged).called(1);
      });

      test('enables BLE notifications on the device', () {
        when(mockService.characteristicChanged)
            .thenAnswer((_) => const Stream.empty());
        when(mockService.setNotify(any, any, any, any))
            .thenAnswer((_) async {});

        channel.startListening();

        verify(mockService.setNotify(
          'AA:BB:CC:DD',
          BleUuids.oneBitService,
          BleUuids.communicationCharacteristic,
          true,
        )).called(1);
      });

      test('cancels previous subscription on second call', () {
        final controller1 = StreamController<BleCharacteristicValue>();
        final controller2 = StreamController<BleCharacteristicValue>();

        // First call returns controller1's stream, second returns controller2's
        var callCount = 0;
        when(mockService.characteristicChanged).thenAnswer((_) {
          callCount++;
          return callCount == 1 ? controller1.stream : controller2.stream;
        });

        channel.startListening();
        channel.startListening(); // second call should cancel first

        verify(mockService.characteristicChanged).called(2);

        controller1.close();
        controller2.close();
      });

      test('notification setup failure is caught and logged', () async {
        when(mockService.characteristicChanged)
            .thenAnswer((_) => const Stream.empty());
        when(mockService.setNotify(any, any, any, any))
            .thenAnswer((_) => Future.error(Exception('BLE error')));

        // Should not throw
        channel.startListening();
        // Wait for microtask to complete
        await Future<void>.delayed(Duration.zero);
      });
    });

    group('stopListening', () {
      test('cancels subscription', () {
        final controller = StreamController<BleCharacteristicValue>();
        when(mockService.characteristicChanged)
            .thenAnswer((_) => controller.stream);

        channel.startListening();
        channel.stopListening();

        // After stop, events should not be forwarded
        controller.close();
      });

      test('can be called multiple times safely', () {
        channel.startListening();
        channel.stopListening();
        channel.stopListening();
      });
    });

    group('send', () {
      test('delegates to BleService.writeCharacteristic', () async {
        when(mockService.current).thenReturn(
          const BleState(connections: {
            'AA:BB:CC:DD': BleConnectionInfo(
              deviceId: 'AA:BB:CC:DD',
              state: BleConnectionState.connected,
              servicesDiscovered: true,
            ),
          }),
        );
        when(mockService.writeCharacteristic(any, any, any, any))
            .thenAnswer((_) async {});

        await channel.send([1, 2, 3]);

        verify(mockService.writeCharacteristic(
          'AA:BB:CC:DD',
          BleUuids.oneBitService,
          BleUuids.communicationCharacteristic,
          [1, 2, 3],
        )).called(1);
      });

      test('throws StateError after dispose', () async {
        channel.dispose();

        expect(
          () => channel.send([1, 2, 3]),
          throwsA(isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('disposed'),
          )),
        );
      });
    });

    group('isConnected', () {
      test('returns true when connected with services discovered', () {
        when(mockService.current).thenReturn(
          const BleState(connections: {
            'AA:BB:CC:DD': BleConnectionInfo(
              deviceId: 'AA:BB:CC:DD',
              state: BleConnectionState.connected,
              servicesDiscovered: true,
            ),
          }),
        );

        expect(channel.isConnected, true);
      });

      test('returns false when connected but services not discovered', () {
        when(mockService.current).thenReturn(
          const BleState(connections: {
            'AA:BB:CC:DD': BleConnectionInfo(
              deviceId: 'AA:BB:CC:DD',
              state: BleConnectionState.connected,
              servicesDiscovered: false,
            ),
          }),
        );

        expect(channel.isConnected, false);
      });

      test('returns false when disconnected', () {
        when(mockService.current).thenReturn(
          const BleState(connections: {
            'AA:BB:CC:DD': BleConnectionInfo(
              deviceId: 'AA:BB:CC:DD',
              state: BleConnectionState.disconnected,
            ),
          }),
        );

        expect(channel.isConnected, false);
      });

      test('returns false when no connection info', () {
        when(mockService.current).thenReturn(const BleState());

        expect(channel.isConnected, false);
      });
    });

    group('incoming', () {
      test('forwards matching characteristic values', () async {
        final controller = StreamController<BleCharacteristicValue>();
        when(mockService.characteristicChanged)
            .thenAnswer((_) => controller.stream);

        final received = <List<int>>[];
        channel.startListening();
        channel.incoming.listen(received.add);

        controller.add(const BleCharacteristicValue(
          deviceId: 'AA:BB:CC:DD',
          serviceUuid: BleUuids.oneBitService,
          characteristicUuid: BleUuids.communicationCharacteristic,
          value: [4, 5, 6],
        ));

        await Future<void>.delayed(Duration.zero);
        expect(received, equals([[4, 5, 6]]));

        controller.close();
      });

      test('ignores values from different device', () async {
        final controller = StreamController<BleCharacteristicValue>();
        when(mockService.characteristicChanged)
            .thenAnswer((_) => controller.stream);

        final received = <List<int>>[];
        channel.startListening();
        channel.incoming.listen(received.add);

        controller.add(const BleCharacteristicValue(
          deviceId: 'EE:FF:00:11',
          serviceUuid: BleUuids.oneBitService,
          characteristicUuid: BleUuids.communicationCharacteristic,
          value: [7, 8, 9],
        ));

        await Future<void>.delayed(Duration.zero);
        expect(received, isEmpty);

        controller.close();
      });

      test('ignores values with wrong characteristic', () async {
        final controller = StreamController<BleCharacteristicValue>();
        when(mockService.characteristicChanged)
            .thenAnswer((_) => controller.stream);

        final received = <List<int>>[];
        channel.startListening();
        channel.incoming.listen(received.add);

        controller.add(const BleCharacteristicValue(
          deviceId: 'AA:BB:CC:DD',
          serviceUuid: BleUuids.oneBitService,
          characteristicUuid: '00001234-0000-1000-8000-00805f9b34fb',
          value: [10, 11, 12],
        ));

        await Future<void>.delayed(Duration.zero);
        expect(received, isEmpty);

        controller.close();
      });
    });

    group('dispose', () {
      test('cancels subscription and closes controller', () {
        final controller = StreamController<BleCharacteristicValue>();
        when(mockService.characteristicChanged)
            .thenAnswer((_) => controller.stream);

        channel.startListening();
        channel.dispose();

        expect(channel.isDisposed, true);
        controller.close();
      });

      test('disables native BLE notifications on dispose when connected', () async {
        when(mockService.current).thenReturn(
          const BleState(connections: {
            'AA:BB:CC:DD': BleConnectionInfo(
              deviceId: 'AA:BB:CC:DD',
              state: BleConnectionState.connected,
              servicesDiscovered: true,
            ),
          }),
        );
        when(mockService.setNotify(any, any, any, any))
            .thenAnswer((_) async {});

        channel.startListening();
        channel.dispose();

        verify(mockService.setNotify(
          'AA:BB:CC:DD',
          BleUuids.oneBitService,
          BleUuids.communicationCharacteristic,
          false,
        )).called(1);
      });

      test('does not disable notifications when device already disconnected', () {
        when(mockService.current).thenReturn(
          const BleState(connections: {
            'AA:BB:CC:DD': BleConnectionInfo(
              deviceId: 'AA:BB:CC:DD',
              state: BleConnectionState.disconnected,
            ),
          }),
        );

        channel.dispose();

        verifyNever(mockService.setNotify(any, any, any, any));
      });

      test('does not throw if called multiple times', () {
        channel.dispose();
        channel.dispose();
      });

      test('dispose failure on setNotify is caught', () async {
        when(mockService.current).thenReturn(
          const BleState(connections: {
            'AA:BB:CC:DD': BleConnectionInfo(
              deviceId: 'AA:BB:CC:DD',
              state: BleConnectionState.connected,
              servicesDiscovered: true,
            ),
          }),
        );
        when(mockService.setNotify(any, any, any, any))
            .thenAnswer((_) => Future.error(Exception('BLE error')));

        // Should not throw
        channel.dispose();
        await Future<void>.delayed(Duration.zero);
      });
    });

    group('isDisposed', () {
      test('starts as false', () {
        expect(channel.isDisposed, false);
      });

      test('becomes true after dispose', () {
        channel.dispose();
        expect(channel.isDisposed, true);
      });
    });
  });
}
