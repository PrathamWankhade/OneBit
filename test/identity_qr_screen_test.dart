import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/features/identity/identity_models.dart';
import 'package:onebit/features/identity/identity_providers.dart';
import 'package:onebit/features/identity/identity_repository.dart';
import 'package:onebit/features/identity/presentation/identity_qr_screen.dart';
import 'package:onebit/features/identity/presentation/identity_qr_scanner_view.dart';
import 'package:onebit/features/peer_registry/peer_entry.dart';
import 'package:onebit/features/peer_registry/peer_lifecycle_state.dart';
import 'package:onebit/features/peer_registry/peer_registry_providers.dart';

const _methodChannel = MethodChannel(
  'dev.steenbakker.mobile_scanner/scanner/method',
);
const _eventChannel = EventChannel(
  'dev.steenbakker.mobile_scanner/scanner/event',
);
const _orientationChannel = EventChannel(
  'dev.steenbakker.mobile_scanner/scanner/deviceOrientation',
);

/// Bounded replacement for `pumpAndSettle`: the pager animates and the
/// scanner holds a camera view, so settle is never guaranteed to finish.
Future<void> pumpFrames(WidgetTester tester, {int frames = 10}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Uint8List keyBytes;
  late IdentityInfo identity;

  setUp(() {
    keyBytes = Uint8List.fromList(List.generate(32, (i) => i));
    identity = IdentityInfo(
      id: 1,
      identityId: IdentityRepository.bytesToHex(keyBytes),
      displayName: 'Test User',
      createdAt: DateTime(2025),
      publicKeyBytes: keyBytes,
    );

    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    // The scanner page talks to `mobile_scanner`, whose plugin is absent
    // in tests. Without these handlers the camera start fails inside an
    // unawaited future and the test dies with an unhandled error.
    messenger.setMockMethodCallHandler(_methodChannel, (call) async {
      switch (call.method) {
        // MobileScannerAuthorizationState.authorized
        case 'state':
          return 1;
        case 'start':
          return <String, Object?>{
            'textureId': 1,
            'cameraDirection': 1,
            'numberOfCameras': 1,
            'currentTorchState': 0,
            'size': <String, Object?>{'width': 640.0, 'height': 480.0},
            // Android SurfaceProducer configuration.
            'handlesCropAndRotation': true,
            'naturalDeviceOrientation': 'PORTRAIT_UP',
            'sensorOrientation': 90,
            // iOS/macOS initial orientation.
            'initialDeviceOrientation': 'PORTRAIT_UP',
          };
        default:
          return null;
      }
    });

    // Barcode and orientation events: stay silent rather than erroring.
    messenger.setMockStreamHandler(
      _eventChannel,
      MockStreamHandler.inline(onListen: (arguments, events) {}),
    );
    messenger.setMockStreamHandler(
      _orientationChannel,
      MockStreamHandler.inline(onListen: (arguments, events) {}),
    );
  });

  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_methodChannel, null);
    messenger.setMockStreamHandler(_eventChannel, null);
    messenger.setMockStreamHandler(_orientationChannel, null);
  });

  Widget buildTestApp({
    List<PeerEntry> peers = const [],
    int initialPage = 0,
  }) {
    return ProviderScope(
      overrides: [
        // Neither provider should reach for the real database here.
        localIdentityProvider.overrideWith((ref) async => identity),
        peerEntriesProvider.overrideWith(
          (ref) => Stream<List<PeerEntry>>.value(peers),
        ),
      ],
      child: MaterialApp(
        home: IdentityQrScreen(initialPage: initialPage),
      ),
    );
  }

  PeerEntry peer({PeerLifecycleState lifecycleState = PeerLifecycleState.disconnected}) {
    return PeerEntry(
      identityId: 'b' * 64,
      peer: PeerInfo(
        id: 1,
        identityId: 'b' * 64,
        displayName: 'Peer',
        createdAt: DateTime(2025),
      ),
      lifecycleState: lifecycleState,
    );
  }

  group('IdentityQrScreen — my code page', () {
    testWidgets('renders the code, the status card and a scan button',
        (tester) async {
      await tester.pumpWidget(buildTestApp());
      await pumpFrames(tester);

      expect(find.text('My QR Code'), findsOneWidget);
      expect(find.text('Test User'), findsOneWidget);
      expect(find.text('Scan a QR code'), findsOneWidget);

      // No peers bound yet.
      expect(find.text('NO PEER BOUND'), findsOneWidget);
      expect(find.text('scan a QR code to bind a peer'), findsOneWidget);
      expect(find.text('PEER BOUND'), findsNothing);
    });

    testWidgets('does not build the camera until the scanner is reached',
        (tester) async {
      await tester.pumpWidget(buildTestApp());
      await pumpFrames(tester);

      // Opening "My QR Code" must not request the camera.
      expect(find.byType(IdentityQrScannerView), findsNothing);
    });

    testWidgets('reports awaiting proximity link when a peer is not connected',
        (tester) async {
      await tester.pumpWidget(buildTestApp(peers: [peer()]));
      await pumpFrames(tester);

      expect(find.text('PEER BOUND'), findsOneWidget);
      expect(find.text('awaiting proximity link'), findsOneWidget);
      expect(find.text('NO PEER BOUND'), findsNothing);
    });

    testWidgets('reports an established link once the peer connects',
        (tester) async {
      await tester.pumpWidget(
        buildTestApp(peers: [peer(lifecycleState: PeerLifecycleState.connected)]),
      );
      await pumpFrames(tester);

      expect(find.text('PEER BOUND'), findsOneWidget);
      expect(find.text('proximity link established'), findsOneWidget);
      expect(find.text('awaiting proximity link'), findsNothing);
    });
  });

  group('IdentityQrScreen — scanner page', () {
    testWidgets('swiping left opens the scanner', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await pumpFrames(tester);

      expect(find.text('My QR Code'), findsOneWidget);

      await tester.drag(find.byType(PageView), const Offset(-600, 0));
      await pumpFrames(tester);

      expect(find.text('Scan QR Code'), findsOneWidget);
      expect(find.byType(IdentityQrScannerView), findsOneWidget);
      expect(find.text('Point camera at a OneBit QR code'), findsOneWidget);
      expect(find.text('My QR Code'), findsNothing);
    });

    testWidgets('/identity/scan opens directly on the scanner', (tester) async {
      await tester.pumpWidget(buildTestApp(initialPage: 1));
      await pumpFrames(tester);

      expect(find.text('Scan QR Code'), findsOneWidget);
      expect(find.byType(IdentityQrScannerView), findsOneWidget);
      expect(find.text('My QR Code'), findsNothing);
    });
  });
}
