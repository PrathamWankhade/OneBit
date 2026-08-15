import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:onebit/app/app_shell.dart';
import 'package:onebit/core/crypto/identity/identity_crypto.dart';
import 'package:onebit/core/crypto/identity/qr_domain.dart';
import 'package:onebit/core/crypto/identity/qr_payload.dart';
import 'package:onebit/core/database/connection/connection_factory.dart'
    show InMemoryConnectionFactory;
import 'package:onebit/core/database/database_providers.dart'
    show databaseConnectionFactoryProvider;
import 'package:onebit/core/navigation/app_route_paths.dart';
import 'package:onebit/core/widgets/onebit_qr_code.dart';
import 'package:onebit/features/identity/presentation/identity_providers.dart';
import 'package:onebit/features/identity/presentation/qr_identity_screen.dart';
import 'package:onebit/features/identity/presentation/qr_scanner_controller.dart';
import 'package:onebit/features/identity/presentation/qr_scanner_screen.dart';
import 'package:onebit/features/identity/presentation/qr_scanner_service.dart';
import 'package:onebit/shared/design_system/components/onebit_technical_card.dart';

import '../../app/support/app_navigation_support.dart';
import '../../app/support/screen_test_support.dart';

/// Phase 10.5 identity surfaces: the signed identity QR card and the
/// scanner state machine (camera seam faked via [qrScannerServiceProvider]).
void main() {
  group('qr identity screen', () {
    testWidgets('renders the signed card and identity details', (tester) async {
      await pumpShell(tester);

      GoRouter.of(
        tester.element(find.byType(AppShell)),
      ).go(AppRoutePaths.qrIdentity);
      await tester.pumpAndSettle();

      expect(find.byType(QrIdentityScreen), findsOneWidget);
      expect(find.byType(OneBitQrCode), findsOneWidget);
      expect(find.text('Identity card'), findsOneWidget);
      expect(find.text('Test Node'), findsOneWidget);
      expect(find.text('Verified'), findsOneWidget);
      expect(find.text('Node ID'), findsOneWidget);
      expect(find.byType(OneBitTechnicalCard), findsWidgets);
      expect(
        find.text(
          'Scan this QR code with another node to verify your identity.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('OB1:'), findsNothing);

      await disposeApp(tester);
    });

    testWidgets('copy fingerprint writes hex to the clipboard', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final writes = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          writes.add(call);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await pumpShell(tester);

      GoRouter.of(
        tester.element(find.byType(AppShell)),
      ).go(AppRoutePaths.qrIdentity);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Copy fingerprint'));
      await tester.pump();

      final setData = writes.where((c) => c.method == 'Clipboard.setData');
      expect(setData, hasLength(1));
      expect(
        (setData.single.arguments as Map)['text'],
        List.filled(32, '00').join(),
      );

      await disposeApp(tester);
    });

    testWidgets('share copies the signed OB1 card text', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final writes = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          writes.add(call);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await pumpShell(tester);

      GoRouter.of(
        tester.element(find.byType(AppShell)),
      ).go(AppRoutePaths.qrIdentity);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Share identity'));
      await tester.pump();

      final setData = writes.where((c) => c.method == 'Clipboard.setData');
      expect(setData, hasLength(1));
      expect((setData.single.arguments as Map)['text'], startsWith('OB1:'));

      await disposeApp(tester);
    });
  });

  group('qr scanner screen', () {
    late _FakeQrScannerService service;
    late ProviderContainer container;
    late String validCardWire;

    Future<void> pumpScanner(WidgetTester tester) async {
      container = ProviderContainer(
        overrides: [
          identityRepositoryProvider.overrideWithValue(
            FakeIdentityRepository(identity: testIdentity()),
          ),
          databaseConnectionFactoryProvider.overrideWithValue(
            const InMemoryConnectionFactory(),
          ),
          qrScannerServiceProvider.overrideWithValue(service),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const OneBitApp(),
        ),
      );
      await tester.pumpAndSettle();
      GoRouter.of(
        tester.element(find.byType(AppShell)),
      ).go(AppRoutePaths.qrScanner);
      await tester.pumpAndSettle();
    }

    Future<void> tearDownScanner(WidgetTester tester) async {
      await disposeApp(tester);
      container.dispose();
      await tester.pump(const Duration(milliseconds: 10));
    }

    setUpAll(() async {
      // A genuinely signed card: the decoder verifies with real Ed25519,
      // so the test signs with real keys.
      final seed = Uint8List.fromList(List.generate(32, (i) => i));
      final publicKey = await IdentityCrypto.publicKeyFromSeed(seed);
      final card = QrIdentityCard(
        nodeId: 'NODE-AAAA-BBBB',
        displayName: 'Alice',
        fingerprintHex: List.filled(32, 'ab').join(),
        ed25519PublicKey: publicKey,
        x25519PublicKey: Uint8List(32),
        timestamp: 1767225600,
        signature: Uint8List(64),
      );
      validCardWire = await QrPayloadCodec.encodeCard(
        card,
        signer: (message) => IdentityCrypto.sign(seed: seed, message: message),
      );
    });

    setUp(() {
      service = _FakeQrScannerService();
    });

    testWidgets('idle invites a scan, start goes live', (tester) async {
      await pumpScanner(tester);

      expect(find.byType(QrScannerScreen), findsOneWidget);
      expect(
        find.text('Compare fingerprints to verify this identity.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Start scanning'));
      await tester.pumpAndSettle();

      final view = container.read(qrScannerControllerProvider);
      expect(view.phase, QrScannerPhase.scanning);
      expect(service.onDetect, isNotNull);

      await tearDownScanner(tester);
    });

    testWidgets('a valid card decodes into the success view', (tester) async {
      await pumpScanner(tester);

      await tester.tap(find.text('Start scanning'));
      await tester.pumpAndSettle();
      service.onDetect!(validCardWire);
      await tester.pumpAndSettle();

      expect(find.text('Identity found'), findsOneWidget);
      expect(find.textContaining('Alice'), findsWidgets);
      expect(find.text('Add to contacts'), findsOneWidget);

      await tearDownScanner(tester);
    });

    testWidgets('add contact persists the trust contact', (tester) async {
      await pumpScanner(tester);

      await tester.tap(find.text('Start scanning'));
      await tester.pumpAndSettle();
      service.onDetect!(validCardWire);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add to contacts'));
      await tester.pumpAndSettle();

      expect(find.text('Contact added'), findsOneWidget);
      expect(find.text('Add to contacts'), findsNothing);

      await tearDownScanner(tester);
    });

    testWidgets('tampered payload lands in the invalid view', (tester) async {
      await pumpScanner(tester);

      await tester.tap(find.text('Start scanning'));
      await tester.pumpAndSettle();
      service.onDetect!('OB1:not-a-card');
      await tester.pumpAndSettle();

      expect(find.text('Not a valid identity card'), findsOneWidget);
      expect(find.text('Scan another'), findsOneWidget);

      await tearDownScanner(tester);
    });

    testWidgets('stop scanning returns to the cancelled view', (tester) async {
      await pumpScanner(tester);

      await tester.tap(find.text('Start scanning'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Stop scanning'));
      await tester.pumpAndSettle();

      expect(find.text('Scan cancelled'), findsOneWidget);
      expect(service.stopped, isTrue);

      await tearDownScanner(tester);
    });

    testWidgets('denied camera permission shows the permission view', (
      tester,
    ) async {
      service.permissionGranted = false;
      await pumpScanner(tester);

      await tester.tap(find.text('Start scanning'));
      await tester.pumpAndSettle();

      expect(find.text('Camera access needed'), findsOneWidget);
      expect(find.text('Allow camera'), findsOneWidget);

      await tearDownScanner(tester);
    });

    testWidgets('scan another reopens the camera', (tester) async {
      await pumpScanner(tester);

      await tester.tap(find.text('Start scanning'));
      await tester.pumpAndSettle();
      service.onDetect!('OB1:not-a-card');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Scan another'));
      await tester.pumpAndSettle();

      expect(
        container.read(qrScannerControllerProvider).phase,
        QrScannerPhase.scanning,
      );
      expect(service.started, isTrue);

      await tearDownScanner(tester);
    });
  });
}

/// Camera seam fake: renders a plain box and exposes [onDetect] so tests
/// can feed payloads as if a barcode had been decoded.
final class _FakeQrScannerService implements QrScannerService {
  bool permissionGranted = true;
  bool started = false;
  bool stopped = false;
  ValueChanged<String>? onDetect;

  @override
  Future<bool> ensurePermission() async => permissionGranted;

  @override
  Future<void> start() async {
    started = true;
  }

  @override
  Future<void> stop() async {
    stopped = true;
  }

  @override
  void dispose() {}

  @override
  Widget buildPreview(
    BuildContext context, {
    required ValueChanged<String> onDetect,
  }) {
    this.onDetect = onDetect;
    return const SizedBox.expand();
  }
}
