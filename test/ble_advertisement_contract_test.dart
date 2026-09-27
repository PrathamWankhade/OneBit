import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/features/ble/ble_service.dart';
import 'package:onebit/features/ble/ble_state.dart';
import 'package:onebit/features/ble/ble_uuids.dart';
import 'package:onebit/features/ble/discovered_device.dart';

/// The wire contract between Kotlin and Dart for advertising, scanning and
/// connecting.
///
/// Two categories of defect are pinned here:
///
///  * payloads that arrive through `StandardMessageCodec` and therefore
///    carry `Map<Object?, Object?>` rather than `Map<String, dynamic>`;
///  * events named or spelled differently on each side of the channel.
///
/// Both failures are silent by construction: the native scan keeps
/// reporting, the UI keeps waiting, and the Nearby list simply stays empty.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const methodChannel = MethodChannel('dev.onebit.onebit/ble');
  const eventChannel = EventChannel('dev.onebit.onebit/ble_events');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  const sampleKey = <int>[
    1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, //
    17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32,
  ];
  const sampleFingerprint = <int>[
    1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16,
  ];

  /// Start a service wired to mocked platform channels.
  Future<BleService> startService({String permission = 'granted'}) async {
    messenger.setMockMethodCallHandler(methodChannel, (call) async {
      switch (call.method) {
        case 'getState':
          return <String, dynamic>{
            'state': 'ready',
            'permission': permission,
            'batterySaver': false,
            'recoveryRequired': false,
          };
        case 'startScan':
          return <String, dynamic>{'id': 'scan-1'};
        case 'stopScan':
          return <String, dynamic>{};
        case 'startAdvertising':
          return <String, dynamic>{'id': 'adv-1'};
        case 'stopAdvertising':
          return <String, dynamic>{};
        case 'connect':
          return <String, dynamic>{'status': 'connecting'};
        case 'disconnect':
          return <String, dynamic>{};
        default:
          return null;
      }
    });

    final service = BleService(
      methodChannel: methodChannel,
      eventChannel: eventChannel,
    );
    await service.initialize();
    return service;
  }

  /// Deliver a platform event exactly as Kotlin does: encoded through
  /// `StandardMethodCodec`, which is what makes every nested map arrive as
  /// `Map<Object?, Object?>`.
  void emitEvent(Map<String, dynamic> payload) {
    messenger.handlePlatformMessage(
      eventChannel.name,
      const StandardMethodCodec().encodeSuccessEnvelope(payload),
      (ByteData? data) {},
    );
  }

  Map<String, dynamic> scanResult({
    String deviceId = 'AA:BB:CC:DD:EE:FF',
    int rssi = -55,
    String? localName = 'OneBit-001',
    List<String> serviceUuids = const <String>[],
    Object? manufacturerData,
  }) {
    return <String, dynamic>{
      'event': 'scanResult',
      'device': <String, dynamic>{
        'id': deviceId,
        'addressType': 'public',
      },
      'rssiDb': rssi,
      'timestamp': 1700000000000,
      'connectable': true,
      'advertisement': <String, dynamic>{
        'localName': ?localName,
        'serviceUuids': serviceUuids,
        'manufacturerData': ?manufacturerData,
      },
    };
  }

  Map<String, dynamic> v2Manufacturer(Object key) => <String, dynamic>{
        '$key': <int>[BleIdentityProtocol.advertVersion, ...sampleFingerprint],
      };

  group('advertisement wire format', () {
    test('v2 payload fits a legacy advertising packet', () {
      final payload = BleIdentityProtocol.buildAdvertPayload(sampleKey)!;

      expect(payload, hasLength(BleIdentityProtocol.advertPayloadLength));

      // What the stack actually puts on the air: the flags AD it
      // prepends, the manufacturer AD header (length, type, 2-byte company
      // id), then our bytes. 31 is the legacy maximum.
      const flagsAd = 3;
      const manufacturerAdHeader = 4;
      final onAir = flagsAd + manufacturerAdHeader + payload.length;

      expect(onAir, lessThanOrEqualTo(31));
      expect(
        payload.length,
        lessThanOrEqualTo(BleIdentityProtocol.maxAdvertPayloadLength),
      );
    });

    test('the superseded v1 payload could never have fit', () {
      // This is the reason the format changed rather than the docs being
      // wrong about sizing: 33 usable bytes would need a 40-byte packet.
      final payload = BleIdentityProtocol.buildPayload(sampleKey)!;

      expect(payload, hasLength(BleIdentityProtocol.payloadLength));
      expect(3 + 4 + payload.length, greaterThan(31));
    });

    test('advert payload round-trips', () {
      final payload = BleIdentityProtocol.buildAdvertPayload(sampleKey)!;
      expect(BleIdentityProtocol.parseAdvertPayload(payload),
          BleIdentityProtocol.fingerprintBytes(sampleKey));

      expect(BleIdentityProtocol.parseAdvertPayload(sampleKey), isNull);
      expect(BleIdentityProtocol.parseAdvertPayload(<int>[2]), isNull);
      expect(
        BleIdentityProtocol.parseAdvertPayload(<int>[1, ...sampleFingerprint]),
        isNull,
      );
      expect(
        BleIdentityProtocol.parseAdvertPayload(
          <int>[BleIdentityProtocol.advertVersion, ...List<int>.filled(16, 0)],
        ),
        isNull,
        reason: 'an all-zero fingerprint identifies nobody',
      );
    });

    test('fingerprint is stable, key-derived and truncated', () {
      final fingerprint = BleIdentityProtocol.fingerprintBytes(sampleKey);

      expect(fingerprint, hasLength(BleIdentityProtocol.fingerprintLength));
      expect(BleIdentityProtocol.fingerprintBytes(sampleKey), fingerprint);
      expect(
        BleIdentityProtocol.fingerprintBytes(List<int>.filled(32, 7)),
        isNot(equals(fingerprint)),
      );
      expect(BleIdentityProtocol.buildAdvertPayload(sampleKey),
          hasLength(BleIdentityProtocol.advertPayloadLength));
    });

    test('v1 payload still parses for a peer that has not upgraded', () {
      final payload = BleIdentityProtocol.buildPayload(sampleKey)!;
      expect(BleIdentityProtocol.parsePayload(payload), sampleKey);
      expect(BleIdentityProtocol.parsePayload(payload.sublist(1, 20)), isNull);
    });
  });

  group('scanResult decoding', () {
    test('survives StandardMessageCodec decoding and keeps emitting',
        () async {
      final service = await startService();
      final discovered = <DiscoveredOneBitDevice>[];
      final sub = service.discoveryStream.listen(discovered.add);
      await service.startScan(const BleScanConfig());

      emitEvent(scanResult(
        manufacturerData: v2Manufacturer('65535'),
      ));
      await Future<void>.delayed(Duration.zero);

      expect(discovered, hasLength(1));
      final device = discovered.single;
      expect(device.deviceId, 'AA:BB:CC:DD:EE:FF');
      expect(device.name, 'OneBit-001');
      expect(device.isOneBit, isTrue);
      expect(device.identityFingerprint, sampleFingerprint);
      // v2 broadcasts a lookup handle; the key arrives over GATT.
      expect(device.identityIdHex, isNull);
      expect(device.identityFingerprintHex, hasLength(32));

      // A second sighting must still arrive — the defect this guards
      // against killed the listener on the very first event.
      emitEvent(scanResult(
        rssi: -70,
        manufacturerData: v2Manufacturer('65535'),
      ));
      await Future<void>.delayed(Duration.zero);

      expect(discovered, hasLength(2));

      await sub.cancel();
      await service.dispose();
    });

    test('accepts every manufacturer key spelling', () {
      for (final key in <Object>['65535', '0xffff', '0xFFFF', 'ffff', 65535]) {
        final device = DiscoveredOneBitDevice.fromScanResult(
          <String, dynamic>{
            'device': <String, dynamic>{'id': 'AA:BB'},
            'rssiDb': -50,
            'timestamp': 1,
            'advertisement': <String, dynamic>{
              'manufacturerData': {key: <int>[2, ...sampleFingerprint]},
            },
          },
        );

        expect(device.isOneBit, isTrue, reason: 'key $key');
        expect(device.identityFingerprint, sampleFingerprint,
            reason: 'key $key');
      }
    });

    test('a v1 peer still resolves to its full key', () {
      final device = DiscoveredOneBitDevice.fromScanResult(
        <String, dynamic>{
          'device': <String, dynamic>{'id': 'AA:BB'},
          'rssiDb': -50,
          'timestamp': 1,
          'advertisement': <String, dynamic>{
            'manufacturerData': <String, dynamic>{
              '65535': BleIdentityProtocol.buildPayload(sampleKey)!,
            },
          },
        },
      );

      expect(device.identityPublicKeyBytes, sampleKey);
      expect(device.identityIdHex, hasLength(64));
      expect(
        device.identityFingerprint,
        BleIdentityProtocol.fingerprintBytes(sampleKey),
      );
    });

    test('OneBit traffic with a malformed payload is kept, not dropped',
        () {
      final device = DiscoveredOneBitDevice.fromScanResult(
        <String, dynamic>{
          'device': <String, dynamic>{'id': 'AA:BB'},
          'rssiDb': -50,
          'timestamp': 1,
          'advertisement': <String, dynamic>{
            'manufacturerData': <String, dynamic>{'65535': <int>[9, 9, 9]},
          },
        },
      );

      expect(device.isOneBit, isTrue);
      expect(device.hasIdentity, isFalse);
      expect(device.identityIdHex, isNull);
      expect(device.identityFingerprintHex, isNull);
    });

    test('foreign manufacturer data is not OneBit', () {
      final device = DiscoveredOneBitDevice.fromScanResult(
        <String, dynamic>{
          'device': <String, dynamic>{'id': 'AA:BB'},
          'rssiDb': -50,
          'timestamp': 1,
          'advertisement': <String, dynamic>{
            'manufacturerData': <String, dynamic>{'123': <int>[1, 2, 3]},
            'serviceUuids': <String>['180F'],
          },
        },
      );

      expect(device.isOneBit, isFalse);
      expect(device.hasIdentity, isFalse);
    });

    test('a peer still advertising the service UUID counts as OneBit', () {
      final device = DiscoveredOneBitDevice.fromScanResult(
        <String, dynamic>{
          'device': <String, dynamic>{'id': 'AA:BB'},
          'rssiDb': -50,
          'timestamp': 1,
          'advertisement': <String, dynamic>{
            'serviceUuids': <String>[BleUuids.oneBitService],
          },
        },
      );

      expect(device.isOneBit, isTrue);
      expect(device.hasIdentity, isFalse);
    });

    test('a missing or hostile payload never throws', () {
      expect(
        () => DiscoveredOneBitDevice.fromScanResult(
          const <String, dynamic>{},
        ),
        returnsNormally,
      );

      final device = DiscoveredOneBitDevice.fromScanResult(
        <String, dynamic>{
          'device': <String, dynamic>{'id': 42, 'addressType': 7},
          'rssiDb': 'loud',
          'timestamp': true,
          'connectable': 'maybe',
          'advertisement': <String, dynamic>{
            'localName': 99,
            'manufacturerData': <String, dynamic>{'65535': 'not a list'},
          },
        },
      );

      expect(device.deviceId, 'unknown');
      expect(device.rssi, 0);
      expect(device.timestamp, 0);
      expect(device.connectable, isTrue);
      expect(device.isOneBit, isTrue);
    });
  });

  group('event contract', () {
    test('permissionChanged does not reset the radio to unknown', () async {
      final service = await startService(permission: 'notDetermined');
      expect(service.current.radio, BleRadioState.ready);
      expect(service.current.permission, BlePermissionState.notDetermined);
      expect(service.current.isOperational, isFalse);

      emitEvent(<String, dynamic>{
        'event': 'permissionChanged',
        'permission': 'granted',
      });
      await Future<void>.delayed(Duration.zero);

      // Routed through _applyState this payload carried no `state` key, so
      // `radio` fell back to `unknown`, isOperational went false, and
      // BleLifecycleObserver then cancelled every running scan.
      expect(service.current.radio, BleRadioState.ready);
      expect(service.current.permission, BlePermissionState.granted);
      expect(service.current.isOperational, isTrue);

      await service.dispose();
    });

    test('connectionChanged — the name Kotlin sends — updates state',
        () async {
      final service = await startService();

      emitEvent(<String, dynamic>{
        'event': 'connectionChanged',
        'deviceId': 'AA:BB:CC:DD:EE:FF',
        'state': 'connected',
      });
      await Future<void>.delayed(Duration.zero);

      final info = service.current.connections['AA:BB:CC:DD:EE:FF'];
      expect(info, isNotNull);
      expect(info!.state, BleConnectionState.connected);
      // isConnected needs servicesDiscovered too, which has not arrived yet.
      expect(info.isConnected, isFalse);

      await service.dispose();
    });

    test('servicesDiscovered completes the connection', () async {
      final service = await startService();

      emitEvent(<String, dynamic>{
        'event': 'connectionChanged',
        'deviceId': 'AA:BB',
        'state': 'connected',
      });
      await Future<void>.delayed(Duration.zero);

      emitEvent(<String, dynamic>{
        'event': 'servicesDiscovered',
        'deviceId': 'AA:BB',
        'services': <String>[BleUuids.oneBitService],
      });
      await Future<void>.delayed(Duration.zero);

      final info = service.current.connections['AA:BB'];
      expect(info, isNotNull);
      expect(info!.isConnected, isTrue);
      expect(info.hasOneBitService, isTrue);

      await service.dispose();
    });

    test('a scan that runs out its window does not become an error',
        () async {
      final service = await startService();
      await service.startScan(const BleScanConfig());
      expect(service.current.scan, BleScanState.scanning);

      // The native order is scanStateChanged first, then the timeout.
      emitEvent(<String, dynamic>{
        'event': 'scanStateChanged',
        'scanning': false,
        'scanId': 'scan-1',
      });
      emitEvent(<String, dynamic>{
        'event': 'transportError',
        'code': 'ble.scan.timeout',
        'context': 'scan',
      });
      await Future<void>.delayed(Duration.zero);

      expect(service.current.scan, BleScanState.idle);

      await service.dispose();
    });

    test('a genuine scan failure still surfaces as an error', () async {
      final service = await startService();
      await service.startScan(const BleScanConfig());

      emitEvent(<String, dynamic>{
        'event': 'scanStateChanged',
        'scanning': false,
        'scanId': 'scan-1',
      });
      emitEvent(<String, dynamic>{
        'event': 'transportError',
        'code': 'ble.scan.failed',
        'context': 'scan',
      });
      await Future<void>.delayed(Duration.zero);

      expect(service.current.scan, BleScanState.error);

      await service.dispose();
    });

    test('scan starts without a hardware service filter', () async {
      Map<String, dynamic>? captured;
      messenger.setMockMethodCallHandler(methodChannel, (call) async {
        if (call.method == 'getState') {
          return <String, dynamic>{
            'state': 'ready',
            'permission': 'granted',
            'batterySaver': false,
            'recoveryRequired': false,
          };
        }
        if (call.method == 'startScan') {
          captured = Map<String, dynamic>.from(call.arguments as Map);
          return <String, dynamic>{'id': 'scan-1'};
        }
        return null;
      });

      final service = BleService(
        methodChannel: methodChannel,
        eventChannel: eventChannel,
      );
      await service.initialize();
      await service.startScan(const BleScanConfig());

      // Filtering on the service UUID would match nothing: peers no longer
      // advertise it, because it does not fit beside the identity payload.
      expect(captured, isNotNull);
      expect(captured!['serviceUuids'], isEmpty);

      await service.dispose();
    });
  });
}
