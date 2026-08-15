import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/features/bluetooth/domain/bluetooth_device.dart';
import 'package:onebit/features/bluetooth/domain/bluetooth_events.dart';
import 'package:onebit/features/bluetooth/domain/bluetooth_state.dart';
import 'package:onebit/features/bluetooth/domain/bluetooth_state_machine.dart';

void main() {
  group('BluetoothStateMachine', () {
    test('starts at bluetoothOff', () {
      final machine = BluetoothStateMachine();
      expect(machine.state, BluetoothState.bluetoothOff);
    });

    test('adapter on then initialized reaches ready', () {
      final machine = BluetoothStateMachine();
      machine.handle(const AdapterOnEvent());
      expect(machine.state, BluetoothState.initializing);
      machine.handle(const InitializedEvent());
      expect(machine.state, BluetoothState.ready);
    });

    test('init failure lands on bluetoothUnavailable', () {
      final machine = BluetoothStateMachine();
      machine.handle(const AdapterOnEvent());
      machine.handle(const InitializeFailedEvent());
      expect(machine.state, BluetoothState.bluetoothUnavailable);
    });

    test('adapter off resets from any state', () {
      final machine = BluetoothStateMachine();
      machine.handle(const AdapterOnEvent());
      machine.handle(const InitializedEvent());
      machine.handle(const ScanStartedEvent());
      expect(machine.state, BluetoothState.scanning);
      machine.handle(const AdapterOffEvent());
      expect(machine.state, BluetoothState.bluetoothOff);
      expect(machine.deviceId, isNull);
    });

    test('full happy path: scan, find, connect, mtu, discovery, ready', () {
      final machine = BluetoothStateMachine();
      machine.handle(const AdapterOnEvent());
      machine.handle(const InitializedEvent());
      machine.handle(const ScanStartedEvent());
      expect(machine.state, BluetoothState.scanning);

      machine.handle(const DeviceFoundEvent(BluetoothDevice(id: 'peer-1')));
      expect(machine.state, BluetoothState.deviceFound);

      machine.handle(const ConnectRequestedEvent('peer-1'));
      expect(machine.state, BluetoothState.connecting);
      expect(machine.deviceId, 'peer-1');

      machine.handle(const ConnectedEvent('peer-1'));
      expect(machine.state, BluetoothState.connected);

      machine.handle(const MtuStartedEvent('peer-1'));
      expect(machine.state, BluetoothState.mtuNegotiation);

      machine.handle(const MtuNegotiatedEvent('peer-1', 512));
      expect(machine.state, BluetoothState.serviceDiscovery);
      expect(machine.negotiatedMtu, 512);
      expect(machine.mtuReady, isTrue);

      machine.handle(const ServicesDiscoveredEvent('peer-1'));
      expect(machine.state, BluetoothState.linkReady);
      expect(machine.gattReady, isTrue);
    });

    test('mtu failure falls back to default mtu and continues', () {
      final machine = BluetoothStateMachine();
      machine.handle(const AdapterOnEvent());
      machine.handle(const InitializedEvent());
      machine.handle(const ConnectRequestedEvent('peer-1'));
      machine.handle(const ConnectedEvent('peer-1'));
      machine.handle(const MtuStartedEvent('peer-1'));
      machine.handle(const MtuFailedEvent('peer-1'));
      expect(machine.state, BluetoothState.serviceDiscovery);
      expect(machine.negotiatedMtu, 23);
      machine.handle(const ServicesDiscoveredEvent('peer-1'));
      expect(machine.state, BluetoothState.linkReady);
    });

    test('services discovered before mtu is rejected', () {
      final machine = BluetoothStateMachine();
      machine.handle(const AdapterOnEvent());
      machine.handle(const InitializedEvent());
      machine.handle(const ConnectRequestedEvent('peer-1'));
      machine.handle(const ConnectedEvent('peer-1'));
      machine.handle(const ServicesDiscoveredEvent('peer-1'));
      expect(machine.state, BluetoothState.connected);
      expect(machine.lastError, isNotNull);
    });

    test('mtu below 23 is rejected', () {
      final machine = BluetoothStateMachine();
      machine.handle(const AdapterOnEvent());
      machine.handle(const InitializedEvent());
      machine.handle(const ConnectRequestedEvent('peer-1'));
      machine.handle(const ConnectedEvent('peer-1'));
      machine.handle(const MtuStartedEvent('peer-1'));
      machine.handle(const MtuNegotiatedEvent('peer-1', 17));
      expect(machine.state, BluetoothState.mtuNegotiation);
    });

    test('explicit disconnect cycles through disconnecting', () {
      final machine = BluetoothStateMachine();
      _toLinkReady(machine);
      machine.handle(const DisconnectRequestedEvent('peer-1'));
      expect(machine.state, BluetoothState.disconnecting);
      machine.handle(const DisconnectedEvent('peer-1'));
      expect(machine.state, BluetoothState.disconnected);
      expect(machine.deviceId, isNull);
    });

    test('link loss schedules reconnect within budget, then gives up', () {
      final machine = BluetoothStateMachine(maxReconnectAttempts: 2);
      _toLinkReady(machine);
      machine.handle(const LinkLostEvent('peer-1'));
      expect(machine.state, BluetoothState.reconnecting);
      expect(machine.reconnectAttempts, 1);

      machine.handle(const LinkLostEvent('peer-1'));
      expect(machine.state, BluetoothState.reconnecting);
      expect(machine.reconnectAttempts, 2);

      machine.handle(const LinkLostEvent('peer-1'));
      expect(machine.state, BluetoothState.disconnected);
    });

    test('reconnect from disconnected re-enters connecting', () {
      final machine = BluetoothStateMachine();
      _toLinkReady(machine);
      machine.handle(const DisconnectRequestedEvent('peer-1'));
      machine.handle(const DisconnectedEvent('peer-1'));
      machine.handle(const ReconnectRequestedEvent('peer-1'));
      expect(machine.state, BluetoothState.reconnecting);
      machine.handle(const ConnectRequestedEvent('peer-1'));
      expect(machine.state, BluetoothState.connecting);
    });

    test('illegal transitions leave the machine unchanged', () {
      final machine = BluetoothStateMachine();
      expect(
        machine.handle(const InitializedEvent()),
        BluetoothState.bluetoothOff,
      );
      expect(
        machine.handle(const ConnectRequestedEvent('x')),
        BluetoothState.bluetoothOff,
      );
      expect(
        machine.handle(const MtuNegotiatedEvent('x', 512)),
        BluetoothState.bluetoothOff,
      );
    });

    test('fatal adapter error lands on error from any state', () {
      final machine = BluetoothStateMachine();
      _toLinkReady(machine);
      machine.handle(const FatalAdapterErrorEvent());
      expect(machine.state, BluetoothState.error);
      machine.handle(const AdapterOnEvent());
      expect(machine.state, BluetoothState.initializing);
    });

    test('states stream replays current and emits on change', () async {
      final machine = BluetoothStateMachine();
      final seen = <BluetoothState>[];
      final sub = machine.states.listen(seen.add);
      machine.handle(const AdapterOnEvent());
      machine.handle(const InitializedEvent());
      machine.handle(const ScanStartedEvent());
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      expect(seen, [
        BluetoothState.initializing,
        BluetoothState.ready,
        BluetoothState.scanning,
      ]);
    });

    test('rejected events do not emit', () async {
      final machine = BluetoothStateMachine();
      var emissions = 0;
      final sub = machine.states.listen((_) => emissions++);
      machine.handle(const InitializedEvent());
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      expect(emissions, 0);
    });
  });
}

void _toLinkReady(BluetoothStateMachine machine) {
  machine.handle(const AdapterOnEvent());
  machine.handle(const InitializedEvent());
  machine.handle(const ConnectRequestedEvent('peer-1'));
  machine.handle(const ConnectedEvent('peer-1'));
  machine.handle(const MtuStartedEvent('peer-1'));
  machine.handle(const MtuNegotiatedEvent('peer-1', 512));
  machine.handle(const ServicesDiscoveredEvent('peer-1'));
  expect(machine.state, BluetoothState.linkReady);
}
