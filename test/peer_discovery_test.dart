import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/features/ble/discovered_device.dart';
import 'package:onebit/features/identity/identity_association_resolver.dart';
import 'package:onebit/features/identity/identity_models.dart';
import 'package:onebit/features/peer_registry/discovered_peer.dart';
import 'package:onebit/features/peer_registry/peer_discovery_manager.dart';
import 'package:onebit/features/trust/identity_change.dart';

// ── Helpers ────────────────────────────────────────────────────

const _keyA = 'aabbccdd11223344aabbccdd11223344aabbccdd11223344aabbccdd11223344';
const _keyB = '1122334455667788112233445566778811223344556677881122334455667788';

List<int> _hexToBytes(String hex) {
  final bytes = <int>[];
  for (var i = 0; i < hex.length; i += 2) {
    bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
  }
  return bytes;
}

DiscoveredOneBitDevice _discovery({
  required String deviceId,
  required String identityHex,
  String? name,
  int rssi = -50,
  int timestamp = 1000,
}) {
  return DiscoveredOneBitDevice(
    deviceId: deviceId,
    rssi: rssi,
    timestamp: timestamp,
    name: name,
    identityPublicKeyBytes: _hexToBytes(identityHex),
  );
}

DiscoveredOneBitDevice _discoveryNoIdentity({
  required String deviceId,
  String? name,
  int rssi = -50,
  int timestamp = 1000,
}) {
  return DiscoveredOneBitDevice(
    deviceId: deviceId,
    rssi: rssi,
    timestamp: timestamp,
    name: name,
  );
}

PeerInfo _peer({
  required int id,
  required String identityId,
  String displayName = 'Peer',
}) {
  return PeerInfo(
    id: id,
    identityId: identityId,
    displayName: displayName,
    createdAt: DateTime(2025),
  );
}

// ── Tests ──────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ── DiscoveredPeer Model ─────────────────────────────────────

  group('DiscoveredPeer', () {
    test('construction holds all fields', () {
      final now = DateTime(2025);
      final peer = DiscoveredPeer(
        identityId: _keyA,
        displayName: 'Alice',
        status: BlePeerStatus.knownPeer,
        firstSeenAt: now,
        lastSeenAt: now,
        devices: const [],
        rssi: -50,
      );

      expect(peer.identityId, _keyA);
      expect(peer.displayName, 'Alice');
      expect(peer.status, BlePeerStatus.knownPeer);
      expect(peer.firstSeenAt, now);
      expect(peer.lastSeenAt, now);
      expect(peer.devices, isEmpty);
      expect(peer.rssi, -50);
      expect(peer.isKnownPeer, isTrue);
      expect(peer.hasIdentity, isTrue);
      expect(peer.deviceCount, 0);
      expect(peer.primaryDevice, isNull);
      expect(peer.primaryDeviceId, isNull);
    });

    test('equality based on identityId, status, rssi, lastSeenAt', () {
      final now = DateTime(2025);
      final a = DiscoveredPeer(
        identityId: _keyA,
        displayName: 'Alice',
        status: BlePeerStatus.knownPeer,
        firstSeenAt: now,
        lastSeenAt: now,
        devices: const [],
      );
      final b = DiscoveredPeer(
        identityId: _keyA,
        displayName: 'Alice',
        status: BlePeerStatus.knownPeer,
        firstSeenAt: now,
        lastSeenAt: now,
        devices: const [],
      );
      final c = DiscoveredPeer(
        identityId: _keyA,
        displayName: 'Alice',
        status: BlePeerStatus.knownPeer,
        firstSeenAt: now,
        lastSeenAt: now.add(const Duration(seconds: 1)),
        devices: const [],
      );

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('primaryDevice returns first device', () {
      final device = DiscoveredBleDevice(
        deviceId: 'AA:BB:CC',
        rssi: -50,
        lastSeenAt: DateTime(2025),
      );
      final peer = DiscoveredPeer(
        identityId: _keyA,
        displayName: 'Alice',
        status: BlePeerStatus.knownPeer,
        firstSeenAt: DateTime(2025),
        lastSeenAt: DateTime(2025),
        devices: [device],
      );

      expect(peer.primaryDevice, equals(device));
      expect(peer.primaryDeviceId, 'AA:BB:CC');
    });

    test('status noIdentity makes hasIdentity false', () {
      final peer = DiscoveredPeer(
        identityId: 'no-identity-AA:BB:CC',
        displayName: 'OneBit device',
        status: BlePeerStatus.noIdentity,
        firstSeenAt: DateTime(2025),
        lastSeenAt: DateTime(2025),
        devices: const [],
      );

      expect(peer.hasIdentity, isFalse);
      expect(peer.isKnownPeer, isFalse);
    });

    test('toString includes truncated identity', () {
      final peer = DiscoveredPeer(
        identityId: _keyA,
        displayName: 'Alice',
        status: BlePeerStatus.knownPeer,
        firstSeenAt: DateTime(2025),
        lastSeenAt: DateTime(2025),
        devices: const [],
      );

      expect(peer.toString(), contains(_keyA.substring(0, 8)));
      expect(peer.toString(), contains('knownPeer'));
    });
  });

  // ── DiscoveredBleDevice Model ────────────────────────────────

  group('DiscoveredBleDevice', () {
    test('construction holds all fields', () {
      final now = DateTime(2025);
      final device = DiscoveredBleDevice(
        deviceId: 'AA:BB:CC',
        rssi: -50,
        lastSeenAt: now,
        firstSeenAt: now,
        name: 'TestDevice',
        rssiHistory: [-50, -55, -60],
      );

      expect(device.deviceId, 'AA:BB:CC');
      expect(device.rssi, -50);
      expect(device.lastSeenAt, now);
      expect(device.firstSeenAt, now);
      expect(device.name, 'TestDevice');
      expect(device.rssiHistory, [-50, -55, -60]);
      expect(device.averageRssi, -55);
    });

    test('averageRssi returns rssi when history empty', () {
      final device = DiscoveredBleDevice(
        deviceId: 'AA:BB:CC',
        rssi: -50,
        lastSeenAt: DateTime(2025),
      );

      expect(device.averageRssi, -50);
    });

    test('equality based on deviceId, rssi, lastSeenAt', () {
      final now = DateTime(2025);
      final a = DiscoveredBleDevice(deviceId: 'AA:BB:CC', rssi: -50, lastSeenAt: now);
      final b = DiscoveredBleDevice(deviceId: 'AA:BB:CC', rssi: -50, lastSeenAt: now);
      final c = DiscoveredBleDevice(deviceId: 'AA:BB:CC', rssi: -55, lastSeenAt: now);

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });

  // ── DiscoveryEvent Model ─────────────────────────────────────

  group('DiscoveryEvent', () {
    test('construction holds all fields', () {
      final peer = DiscoveredPeer(
        identityId: _keyA,
        displayName: 'Alice',
        status: BlePeerStatus.knownPeer,
        firstSeenAt: DateTime(2025),
        lastSeenAt: DateTime(2025),
        devices: const [],
      );
      final event = DiscoveryEvent(
        type: DiscoveryEventType.appeared,
        peer: peer,
      );

      expect(event.type, DiscoveryEventType.appeared);
      expect(event.peer, equals(peer));
    });

    test('toString includes type and truncated identity', () {
      final peer = DiscoveredPeer(
        identityId: _keyA,
        displayName: 'Alice',
        status: BlePeerStatus.knownPeer,
        firstSeenAt: DateTime(2025),
        lastSeenAt: DateTime(2025),
        devices: const [],
      );
      final event = DiscoveryEvent(
        type: DiscoveryEventType.updated,
        peer: peer,
      );

      expect(event.toString(), contains('updated'));
      expect(event.toString(), contains(_keyA.substring(0, 8)));
    });
  });

  // ── PeerDiscoveryManager ─────────────────────────────────────

  group('PeerDiscoveryManager', () {
    late StreamController<ResolvedBleDevice> resolvedController;
    late PeerDiscoveryManager manager;

    setUp(() {
      resolvedController = StreamController<ResolvedBleDevice>.broadcast();
      manager = PeerDiscoveryManager(
        resolvedStream: resolvedController.stream,
        staleTimeoutMs: 1000,
        maxRssiHistory: 5,
        maxDevicesPerPeer: 3,
      );
    });

    tearDown(() {
      manager.dispose();
      resolvedController.close();
    });

    test('initial state has no peers', () {
      expect(manager.peerCount, 0);
      expect(manager.deviceCount, 0);
      expect(manager.peers, isEmpty);
    });

    test('new peer discovered with identity', () async {
      final events = <DiscoveryEvent>[];
      manager.eventStream.listen(events.add);

      final peers = <List<DiscoveredPeer>>[];
      manager.peersStream.listen(peers.add);

      resolvedController.add(ResolvedBleDevice(
        device: _discovery(deviceId: 'AA:BB:CC', identityHex: _keyA),
        status: BlePeerStatus.unknownIdentity,
      ));

      await Future.delayed(const Duration(milliseconds: 50));

      expect(manager.peerCount, 1);
      expect(manager.deviceCount, 1);

      final peer = manager.peerById(_keyA);
      expect(peer, isNotNull);
      expect(peer!.identityId, _keyA);
      expect(peer.status, BlePeerStatus.unknownIdentity);
      expect(peer.deviceCount, 1);
      expect(peer.devices.first.deviceId, 'AA:BB:CC');

      expect(events, hasLength(1));
      expect(events.first.type, DiscoveryEventType.appeared);

      expect(peers, hasLength(1));
      expect(peers.first, hasLength(1));
    });

    test('new peer discovered without identity creates placeholder', () async {
      final events = <DiscoveryEvent>[];
      manager.eventStream.listen(events.add);

      resolvedController.add(ResolvedBleDevice(
        device: _discoveryNoIdentity(deviceId: 'AA:BB:CC'),
        status: BlePeerStatus.noIdentity,
      ));

      await Future.delayed(const Duration(milliseconds: 50));

      expect(manager.peerCount, 1);

      final peer = manager.peerByDevice('AA:BB:CC');
      expect(peer, isNotNull);
      expect(peer!.status, BlePeerStatus.noIdentity);
      expect(peer.identityId, 'no-identity-AA:BB:CC');

      expect(events, hasLength(1));
      expect(events.first.type, DiscoveryEventType.appeared);
    });

    test('repeated advertisement of same device updates RSSI', () async {
      final events = <DiscoveryEvent>[];
      manager.eventStream.listen(events.add);

      // First discovery.
      resolvedController.add(ResolvedBleDevice(
        device: _discovery(deviceId: 'AA:BB:CC', identityHex: _keyA, rssi: -50, timestamp: 1000),
        status: BlePeerStatus.unknownIdentity,
      ));
      await Future.delayed(const Duration(milliseconds: 50));

      // Same device, different RSSI.
      resolvedController.add(ResolvedBleDevice(
        device: _discovery(deviceId: 'AA:BB:CC', identityHex: _keyA, rssi: -60, timestamp: 2000),
        status: BlePeerStatus.unknownIdentity,
      ));
      await Future.delayed(const Duration(milliseconds: 50));

      expect(manager.peerCount, 1);

      final peer = manager.peerById(_keyA);
      expect(peer!.deviceCount, 1);
      expect(peer.rssi, -60);
      expect(peer.devices.first.rssi, -60);
      expect(peer.devices.first.rssiHistory, [-60, -50]);

      // Should be appeared + updated.
      expect(events, hasLength(2));
      expect(events[0].type, DiscoveryEventType.appeared);
      expect(events[1].type, DiscoveryEventType.updated);
    });

    test('multiple BLE devices for same identity are aggregated', () async {
      final events = <DiscoveryEvent>[];
      manager.eventStream.listen(events.add);

      // First device.
      resolvedController.add(ResolvedBleDevice(
        device: _discovery(deviceId: 'AA:BB:CC', identityHex: _keyA, rssi: -50, timestamp: 1000),
        status: BlePeerStatus.unknownIdentity,
      ));
      await Future.delayed(const Duration(milliseconds: 50));

      // Second device, same identity.
      resolvedController.add(ResolvedBleDevice(
        device: _discovery(deviceId: 'DD:EE:FF', identityHex: _keyA, rssi: -60, timestamp: 2000),
        status: BlePeerStatus.unknownIdentity,
      ));
      await Future.delayed(const Duration(milliseconds: 50));

      expect(manager.peerCount, 1);

      final peer = manager.peerById(_keyA);
      expect(peer!.deviceCount, 2);
      expect(peer.devices.map((d) => d.deviceId).toSet(), {'AA:BB:CC', 'DD:EE:FF'});
      // Best RSSI should be -50.
      expect(peer.rssi, -50);

      // Both devices tracked.
      expect(manager.deviceCount, 2);

      expect(events, hasLength(2));
      expect(events[0].type, DiscoveryEventType.appeared);
      expect(events[1].type, DiscoveryEventType.updated);
    });

    test('known peer gets knownPeer status', () async {
      resolvedController.add(ResolvedBleDevice(
        device: _discovery(deviceId: 'AA:BB:CC', identityHex: _keyA),
        peer: _peer(id: 1, identityId: _keyA, displayName: 'Alice'),
        status: BlePeerStatus.knownPeer,
      ));
      await Future.delayed(const Duration(milliseconds: 50));

      final peer = manager.peerById(_keyA);
      expect(peer, isNotNull);
      expect(peer!.isKnownPeer, isTrue);
      expect(peer.displayName, 'Alice');
      expect(peer.peer, isNotNull);
    });

    test('identity change emits identityChanged event', () async {
      final events = <DiscoveryEvent>[];
      manager.eventStream.listen(events.add);

      const identityChange = PeerIdentityChange(
        bleAddress: 'AA:BB:CC',
        previousIdentityId: _keyB,
        currentIdentityId: _keyA,
        status: IdentityChangeStatus.changed,
      );

      resolvedController.add(ResolvedBleDevice(
        device: _discovery(deviceId: 'AA:BB:CC', identityHex: _keyA),
        status: BlePeerStatus.identityChanged,
        identityChange: identityChange,
      ));
      await Future.delayed(const Duration(milliseconds: 50));

      expect(events, hasLength(1));
      expect(events.first.type, DiscoveryEventType.identityChanged);
      expect(events.first.peer.identityChange, equals(identityChange));
    });

    test('RSSI history is capped at maxRssiHistory', () async {
      // Create manager with small history cap.
      final mgr = PeerDiscoveryManager(
        resolvedStream: resolvedController.stream,
        maxRssiHistory: 3,
      );

      // Send 5 updates for the same device.
      for (var i = 0; i < 5; i++) {
        resolvedController.add(ResolvedBleDevice(
          device: _discovery(
            deviceId: 'AA:BB:CC',
            identityHex: _keyA,
            rssi: -(40 + i * 10),
            timestamp: 1000 + i * 1000,
          ),
          status: BlePeerStatus.unknownIdentity,
        ));
        await Future.delayed(const Duration(milliseconds: 50));
      }

      final peer = mgr.peerById(_keyA);
      expect(peer!.devices.first.rssiHistory.length, 3);
      // Most recent first: -80, -70, -60.
      expect(peer.devices.first.rssiHistory, [-80, -70, -60]);

      mgr.dispose();
    });

    test('maxDevicesPerPeer limits tracked devices', () async {
      final events = <DiscoveryEvent>[];
      manager.eventStream.listen(events.add);

      // Add 5 different devices for the same identity.
      for (var i = 0; i < 5; i++) {
        final deviceId = 'Device:$i';
        resolvedController.add(ResolvedBleDevice(
          device: _discovery(
            deviceId: deviceId,
            identityHex: _keyA,
            rssi: -(40 + i * 10),
            timestamp: 1000 + i * 1000,
          ),
          status: BlePeerStatus.unknownIdentity,
        ));
        await Future.delayed(const Duration(milliseconds: 50));
      }

      final peer = manager.peerById(_keyA);
      expect(peer!.deviceCount, 3); // maxDevicesPerPeer = 3
    });

    test('evictStale removes old peers', () async {
      resolvedController.add(ResolvedBleDevice(
        device: _discovery(deviceId: 'AA:BB:CC', identityHex: _keyA, timestamp: 1000),
        status: BlePeerStatus.unknownIdentity,
      ));
      await Future.delayed(const Duration(milliseconds: 50));

      expect(manager.peerCount, 1);

      // Wait for stale timeout (1000ms).
      await Future.delayed(const Duration(milliseconds: 1100));

      final evicted = manager.evictStale();
      expect(evicted, hasLength(1));
      expect(evicted.first.identityId, _keyA);
      expect(manager.peerCount, 0);
      expect(manager.deviceCount, 0);
    });

    test('evictStale does not remove recent peers', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      resolvedController.add(ResolvedBleDevice(
        device: _discovery(deviceId: 'AA:BB:CC', identityHex: _keyA, timestamp: now),
        status: BlePeerStatus.unknownIdentity,
      ));
      await Future.delayed(const Duration(milliseconds: 50));

      // Immediately evict — peer is still fresh.
      final evicted = manager.evictStale();
      expect(evicted, isEmpty);
      expect(manager.peerCount, 1);
    });

    test('recent update refreshes stale timeout', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      resolvedController.add(ResolvedBleDevice(
        device: _discovery(deviceId: 'AA:BB:CC', identityHex: _keyA, timestamp: now),
        status: BlePeerStatus.unknownIdentity,
      ));
      await Future.delayed(const Duration(milliseconds: 50));

      // Wait 800ms (less than 1000ms timeout).
      await Future.delayed(const Duration(milliseconds: 800));

      // Update the peer with fresh timestamp.
      final updateNow = DateTime.now().millisecondsSinceEpoch;
      resolvedController.add(ResolvedBleDevice(
        device: _discovery(deviceId: 'AA:BB:CC', identityHex: _keyA, rssi: -60, timestamp: updateNow),
        status: BlePeerStatus.unknownIdentity,
      ));
      await Future.delayed(const Duration(milliseconds: 50));

      // Wait another 800ms (total 1650ms since first, but only 850ms since update).
      await Future.delayed(const Duration(milliseconds: 800));

      final evicted = manager.evictStale();
      expect(evicted, isEmpty);
      expect(manager.peerCount, 1);
    });

    test('removePeer removes a specific peer', () async {
      resolvedController.add(ResolvedBleDevice(
        device: _discovery(deviceId: 'AA:BB:CC', identityHex: _keyA),
        status: BlePeerStatus.unknownIdentity,
      ));
      resolvedController.add(ResolvedBleDevice(
        device: _discovery(deviceId: 'DD:EE:FF', identityHex: _keyB),
        status: BlePeerStatus.unknownIdentity,
      ));
      await Future.delayed(const Duration(milliseconds: 50));

      expect(manager.peerCount, 2);

      final removed = manager.removePeer(_keyA);
      expect(removed, isTrue);
      expect(manager.peerCount, 1);
      expect(manager.peerById(_keyA), isNull);
      expect(manager.peerById(_keyB), isNotNull);

      // Device mapping cleaned up.
      expect(manager.deviceCount, 1);
    });

    test('removePeer returns false for unknown peer', () {
      expect(manager.removePeer(_keyA), isFalse);
    });

    test('clear removes all peers and device mappings', () async {
      resolvedController.add(ResolvedBleDevice(
        device: _discovery(deviceId: 'AA:BB:CC', identityHex: _keyA),
        status: BlePeerStatus.unknownIdentity,
      ));
      resolvedController.add(ResolvedBleDevice(
        device: _discovery(deviceId: 'DD:EE:FF', identityHex: _keyB),
        status: BlePeerStatus.unknownIdentity,
      ));
      await Future.delayed(const Duration(milliseconds: 50));

      expect(manager.peerCount, 2);
      expect(manager.deviceCount, 2);

      manager.clear();

      expect(manager.peerCount, 0);
      expect(manager.deviceCount, 0);
    });

    test('peerByDevice looks up peer by BLE device ID', () async {
      resolvedController.add(ResolvedBleDevice(
        device: _discovery(deviceId: 'AA:BB:CC', identityHex: _keyA),
        status: BlePeerStatus.unknownIdentity,
      ));
      await Future.delayed(const Duration(milliseconds: 50));

      final peer = manager.peerByDevice('AA:BB:CC');
      expect(peer, isNotNull);
      expect(peer!.identityId, _keyA);

      expect(manager.peerByDevice('unknown'), isNull);
    });

    test('peerById returns null for unknown identity', () {
      expect(manager.peerById(_keyA), isNull);
    });

    test('disappeared event emitted during eviction', () async {
      final events = <DiscoveryEvent>[];
      manager.eventStream.listen(events.add);

      final now = DateTime.now().millisecondsSinceEpoch;
      resolvedController.add(ResolvedBleDevice(
        device: _discovery(deviceId: 'AA:BB:CC', identityHex: _keyA, timestamp: now),
        status: BlePeerStatus.unknownIdentity,
      ));
      await Future.delayed(const Duration(milliseconds: 50));

      expect(events, hasLength(1));
      expect(events[0].type, DiscoveryEventType.appeared);

      // Wait for stale timeout.
      await Future.delayed(const Duration(milliseconds: 1100));

      final evicted = manager.evictStale();
      expect(evicted, hasLength(1));

      // Allow stream to deliver the event.
      await Future.delayed(const Duration(milliseconds: 50));

      // Should have appeared + disappeared events.
      expect(events, hasLength(2));
      expect(events[1].type, DiscoveryEventType.disappeared);
    });

    test('devices sorted by most recently seen', () async {
      // Add two devices with different timestamps.
      resolvedController.add(ResolvedBleDevice(
        device: _discovery(deviceId: 'AA:BB:CC', identityHex: _keyA, timestamp: 1000),
        status: BlePeerStatus.unknownIdentity,
      ));
      await Future.delayed(const Duration(milliseconds: 50));

      resolvedController.add(ResolvedBleDevice(
        device: _discovery(deviceId: 'DD:EE:FF', identityHex: _keyA, timestamp: 2000),
        status: BlePeerStatus.unknownIdentity,
      ));
      await Future.delayed(const Duration(milliseconds: 50));

      final peer = manager.peerById(_keyA);
      // Most recently seen should be first.
      expect(peer!.devices.first.deviceId, 'DD:EE:FF');
      expect(peer.devices.last.deviceId, 'AA:BB:CC');
    });

    test('RssiHistory tracks multiple readings per device', () async {
      resolvedController.add(ResolvedBleDevice(
        device: _discovery(deviceId: 'AA:BB:CC', identityHex: _keyA, rssi: -50, timestamp: 1000),
        status: BlePeerStatus.unknownIdentity,
      ));
      await Future.delayed(const Duration(milliseconds: 50));

      resolvedController.add(ResolvedBleDevice(
        device: _discovery(deviceId: 'AA:BB:CC', identityHex: _keyA, rssi: -55, timestamp: 2000),
        status: BlePeerStatus.unknownIdentity,
      ));
      await Future.delayed(const Duration(milliseconds: 50));

      resolvedController.add(ResolvedBleDevice(
        device: _discovery(deviceId: 'AA:BB:CC', identityHex: _keyA, rssi: -60, timestamp: 3000),
        status: BlePeerStatus.unknownIdentity,
      ));
      await Future.delayed(const Duration(milliseconds: 50));

      final peer = manager.peerById(_keyA);
      final device = peer!.devices.first;
      expect(device.rssiHistory, [-60, -55, -50]);
      expect(device.averageRssi, -55);
    });
  });

  // ── Edge Cases ───────────────────────────────────────────────

  group('Edge Cases', () {
    late StreamController<ResolvedBleDevice> resolvedController;
    late PeerDiscoveryManager manager;

    setUp(() {
      resolvedController = StreamController<ResolvedBleDevice>.broadcast();
      manager = PeerDiscoveryManager(
        resolvedStream: resolvedController.stream,
        staleTimeoutMs: 1000,
      );
    });

    tearDown(() {
      manager.dispose();
      resolvedController.close();
    });

    test('concurrent discoveries of different identities', () async {
      final events = <DiscoveryEvent>[];
      manager.eventStream.listen(events.add);

      // Send multiple discoveries rapidly.
      for (var i = 0; i < 10; i++) {
        final key = 'aabbccdd11223344aabbccdd11223344aabbccdd11223344aabbccdd${i.toRadixString(16).padLeft(4, '0')}';
        resolvedController.add(ResolvedBleDevice(
          device: _discovery(deviceId: 'Device:$i', identityHex: key, timestamp: 1000 + i),
          status: BlePeerStatus.unknownIdentity,
        ));
      }
      await Future.delayed(const Duration(milliseconds: 100));

      expect(manager.peerCount, 10);
      expect(manager.deviceCount, 10);
      expect(events, hasLength(10));
      expect(events.every((e) => e.type == DiscoveryEventType.appeared), isTrue);
    });

    test('same BLE device changes identity', () async {
      final events = <DiscoveryEvent>[];
      manager.eventStream.listen(events.add);

      // First identity.
      resolvedController.add(ResolvedBleDevice(
        device: _discovery(deviceId: 'AA:BB:CC', identityHex: _keyA, timestamp: 1000),
        status: BlePeerStatus.unknownIdentity,
      ));
      await Future.delayed(const Duration(milliseconds: 50));

      // Same BLE device, different identity.
      resolvedController.add(ResolvedBleDevice(
        device: _discovery(deviceId: 'AA:BB:CC', identityHex: _keyB, timestamp: 2000),
        status: BlePeerStatus.unknownIdentity,
      ));
      await Future.delayed(const Duration(milliseconds: 50));

      // Should have two peers.
      expect(manager.peerCount, 2);
      expect(manager.peerById(_keyA), isNotNull);
      expect(manager.peerById(_keyB), isNotNull);

      // Device mapping updated to new identity.
      expect(manager.peerByDevice('AA:BB:CC')!.identityId, _keyB);

      expect(events, hasLength(2));
      expect(events[0].type, DiscoveryEventType.appeared);
      expect(events[1].type, DiscoveryEventType.appeared);
    });

    test('dispose closes streams', () async {
      final mgr = PeerDiscoveryManager(
        resolvedStream: resolvedController.stream,
      );

      final events = <DiscoveryEvent>[];
      mgr.eventStream.listen(events.add);

      mgr.dispose();

      // Events should not throw after dispose.
      expect(() => events.add, returnsNormally);
    });

    test('evictStale handles empty peer list', () {
      final evicted = manager.evictStale();
      expect(evicted, isEmpty);
    });

    test('displayName uses peer name when available', () async {
      resolvedController.add(ResolvedBleDevice(
        device: _discovery(deviceId: 'AA:BB:CC', identityHex: _keyA, name: 'BLE Name'),
        peer: _peer(id: 1, identityId: _keyA, displayName: 'Alice'),
        status: BlePeerStatus.knownPeer,
      ));
      await Future.delayed(const Duration(milliseconds: 50));

      final peer = manager.peerById(_keyA);
      expect(peer!.displayName, 'Alice');
    });

    test('displayName falls back to BLE name', () async {
      resolvedController.add(ResolvedBleDevice(
        device: _discovery(deviceId: 'AA:BB:CC', identityHex: _keyA, name: 'BLE Name'),
        status: BlePeerStatus.unknownIdentity,
      ));
      await Future.delayed(const Duration(milliseconds: 50));

      final peer = manager.peerById(_keyA);
      expect(peer!.displayName, 'BLE Name');
    });

    test('displayName falls back to "OneBit device"', () async {
      resolvedController.add(ResolvedBleDevice(
        device: _discoveryNoIdentity(deviceId: 'AA:BB:CC'),
        status: BlePeerStatus.noIdentity,
      ));
      await Future.delayed(const Duration(milliseconds: 50));

      final peer = manager.peerByDevice('AA:BB:CC');
      expect(peer!.displayName, 'OneBit device');
    });

    test('no-identity device not duplicated on re-advertisement', () async {
      resolvedController.add(ResolvedBleDevice(
        device: _discoveryNoIdentity(deviceId: 'AA:BB:CC', rssi: -50, timestamp: 1000),
        status: BlePeerStatus.noIdentity,
      ));
      await Future.delayed(const Duration(milliseconds: 50));

      // Same device again.
      resolvedController.add(ResolvedBleDevice(
        device: _discoveryNoIdentity(deviceId: 'AA:BB:CC', rssi: -60, timestamp: 2000),
        status: BlePeerStatus.noIdentity,
      ));
      await Future.delayed(const Duration(milliseconds: 50));

      expect(manager.peerCount, 1);
      expect(manager.deviceCount, 1);
    });

    test('RSSI history tracks changes over time', () async {
      for (var i = 0; i < 5; i++) {
        resolvedController.add(ResolvedBleDevice(
          device: _discovery(
            deviceId: 'AA:BB:CC',
            identityHex: _keyA,
            rssi: -(40 + i * 10),
            timestamp: 1000 + i * 1000,
          ),
          status: BlePeerStatus.unknownIdentity,
        ));
        await Future.delayed(const Duration(milliseconds: 50));
      }

      final peer = manager.peerById(_keyA);
      final device = peer!.devices.first;
      // History: newest first.
      expect(device.rssiHistory, [-80, -70, -60, -50, -40]);
      expect(device.averageRssi, -60);
    });
  });
}
