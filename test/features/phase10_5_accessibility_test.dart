import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:onebit/app/app_shell.dart';
import 'package:onebit/core/database/connection/connection_factory.dart';
import 'package:onebit/core/database/database_providers.dart'
    show databaseConnectionFactoryProvider;
import 'package:onebit/core/navigation/app_route_paths.dart';
import 'package:onebit/features/identity/presentation/identity_providers.dart';
import 'package:onebit/features/identity/presentation/qr_identity_screen.dart';
import 'package:onebit/features/identity/presentation/qr_scanner_service.dart';
import 'package:onebit/features/media/attachments/attachment.dart';
import 'package:onebit/features/media/presentation/media_gallery_screen.dart';
import 'package:onebit/features/media/presentation/media_providers.dart';
import 'package:onebit/features/media/transfer/transfer_bitmap.dart';
import 'package:onebit/features/media/transfer/transfer_session.dart';
import 'package:onebit/features/media/transfer/transfer_state.dart';
import 'package:onebit/shared/design_system/accessibility/onebit_accessibility.dart';
import 'package:onebit/shared/design_system/components/onebit_button.dart';
import 'package:onebit/shared/design_system/components/onebit_icon_button.dart';
import 'package:onebit/shared/design_system/components/onebit_message_input.dart';

import '../app/support/app_navigation_support.dart';
import '../app/support/screen_test_support.dart';

/// Phase 10.5 screen-level accessibility + responsive coverage: QR identity,
/// QR scanner, transfer progress, media gallery, compose and conversation.
final class _FakeQrScannerService implements QrScannerService {
  @override
  Future<bool> ensurePermission() async => true;

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}

  @override
  void dispose() {}

  @override
  Widget buildPreview(
    BuildContext context, {
    required ValueChanged<String> onDetect,
  }) => Container(color: Colors.black);
}

void main() {
  Future<void> pumpAt(
    WidgetTester tester,
    String route, {
    Size size = const Size(360, 640),
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    GoRouter.of(tester.element(find.byType(AppShell))).go(route);
    await tester.pumpAndSettle();
  }

  group('conversation screen', () {
    testWidgets('attach control exposes a label and 48dp target', (
      tester,
    ) async {
      final container = await pumpShell(tester);
      final channelId = await seedChannel(
        container,
        peer: 'peer-1',
        title: 'Alice',
      );
      await tester.pumpAndSettle();

      await pumpAt(tester, AppRoutePaths.channelOf(channelId));

      final button = find.ancestor(
        of: find.byTooltip('Attach'),
        matching: find.byType(OneBitIconButton),
      );
      expect(button, findsOneWidget);
      final semantics = tester.getSemantics(button);
      expect(semantics.flagsCollection.isButton, isTrue);
      expect(semantics.tooltip, 'Attach');
      final size = tester.getSize(button);
      expect(
        size.width,
        greaterThanOrEqualTo(OneBitAccessibility.minInteractiveSize),
      );
      expect(
        size.height,
        greaterThanOrEqualTo(OneBitAccessibility.minInteractiveSize),
      );

      await disposeApp(tester);
    });

    testWidgets('timeline and composer stay usable at narrow widths', (
      tester,
    ) async {
      final container = await pumpShell(tester);
      final channelId = await seedChannel(
        container,
        peer: 'peer-1',
        title: 'Alice',
      );
      await seedOutbound(container, channelId, 'Hello');
      await tester.pumpAndSettle();

      await pumpAt(tester, AppRoutePaths.channelOf(channelId));

      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Hello'), findsOneWidget);
      expect(find.byType(OneBitMessageInput), findsOneWidget);
      expect(find.byTooltip('Attach'), findsWidgets);

      await disposeApp(tester);
    });
  });

  group('compose screen', () {
    testWidgets('send control exposes a label and 48dp target', (tester) async {
      final container = await pumpShell(tester);
      final channelId = await seedChannel(
        container,
        peer: 'peer-1',
        title: 'Alice',
      );
      await tester.pumpAndSettle();

      await pumpAt(tester, AppRoutePaths.composeOf(channelId));

      final button = find.ancestor(
        of: find.byTooltip('Send'),
        matching: find.byType(OneBitIconButton),
      );
      expect(button, findsOneWidget);
      final semantics = tester.getSemantics(button);
      expect(semantics.flagsCollection.isButton, isTrue);
      expect(semantics.tooltip, 'Send');
      final size = tester.getSize(button);
      expect(
        size.height,
        greaterThanOrEqualTo(OneBitAccessibility.minInteractiveSize),
      );

      await disposeApp(tester);
    });

    testWidgets('composer renders at narrow widths', (tester) async {
      final container = await pumpShell(tester);
      final channelId = await seedChannel(
        container,
        peer: 'peer-1',
        title: 'Alice',
      );
      await tester.pumpAndSettle();

      await pumpAt(tester, AppRoutePaths.composeOf(channelId));

      expect(find.byType(OneBitMessageInput), findsOneWidget);
      expect(find.byTooltip('Attach'), findsOneWidget);

      await disposeApp(tester);
    });
  });

  group('qr identity screen', () {
    testWidgets('copy fingerprint exposes a label and 48dp target', (
      tester,
    ) async {
      await pumpShell(tester);

      await pumpAt(tester, AppRoutePaths.qrIdentity);

      final button = find.ancestor(
        of: find.byTooltip('Copy fingerprint'),
        matching: find.byType(OneBitIconButton),
      );
      expect(button, findsOneWidget);
      final semantics = tester.getSemantics(button);
      expect(semantics.flagsCollection.isButton, isTrue);
      expect(semantics.tooltip, 'Copy fingerprint');
      final size = tester.getSize(button);
      expect(
        size.height,
        greaterThanOrEqualTo(OneBitAccessibility.minInteractiveSize),
      );

      await disposeApp(tester);
    });

    testWidgets('identity card renders at narrow widths', (tester) async {
      await pumpShell(tester);

      await pumpAt(tester, AppRoutePaths.qrIdentity);

      expect(find.byType(QrIdentityScreen), findsOneWidget);
      expect(find.text('Test Node'), findsOneWidget);
      expect(find.text('Verified'), findsOneWidget);

      await disposeApp(tester);
    });
  });

  group('qr scanner screen', () {
    testWidgets('start scanning exposes a label and 48dp target', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            identityRepositoryProvider.overrideWithValue(
              FakeIdentityRepository(identity: testIdentity()),
            ),
            databaseConnectionFactoryProvider.overrideWithValue(
              const InMemoryConnectionFactory(),
            ),
            qrScannerServiceProvider.overrideWithValue(_FakeQrScannerService()),
          ],
          child: const OneBitApp(),
        ),
      );
      await tester.pumpAndSettle();

      await pumpAt(tester, AppRoutePaths.qrScanner);

      final button = find.ancestor(
        of: find.text('Start scanning'),
        matching: find.byType(OneBitButton),
      );
      expect(button, findsOneWidget);
      expect(
        tester.getSemantics(button),
        isSemantics(label: 'Start scanning', isButton: true),
      );
      final size = tester.getSize(button);
      expect(
        size.height,
        greaterThanOrEqualTo(OneBitAccessibility.minInteractiveSize),
      );

      await disposeApp(tester);
    });
  });

  group('transfer progress screen', () {
    Future<void> seedSession(ProviderContainer container) async {
      await container
          .read(sqliteAttachmentRepositoryProvider)
          .save(
            Attachment(
              attachmentId: 'att-a11y',
              messageId: 'msg-a11y',
              metadata: const AttachmentMetadata(
                fileName: 'report.pdf',
                mimeType: 'application/pdf',
                category: MediaCategory.document,
                sizeBytes: 2048,
              ),
              status: AttachmentStatus.ready,
              createdAt: DateTime.utc(2026, 1, 1),
              updatedAt: DateTime.utc(2026, 1, 1),
              isInline: true,
              inlineBytes: [1, 2, 3],
            ),
          );
      await container
          .read(sqliteTransferRepositoryProvider)
          .createSession(
            TransferSession(
              sessionId: 'sess-a11y',
              attachmentId: 'att-a11y',
              peerNodeId: 'peer-9',
              direction: TransferDirection.send,
              state: TransferState.queued,
              chunkSize: 512,
              totalChunks: 4,
              chunksBitmap: TransferBitmap.empty(4),
              bytesTransferred: 0,
              createdAt: DateTime.utc(2026, 1, 1),
              updatedAt: DateTime.utc(2026, 1, 1),
            ),
          );
    }

    testWidgets('pause control exposes a label and 48dp target', (
      tester,
    ) async {
      final container = await pumpShell(tester);
      await seedSession(container);
      await tester.pumpAndSettle();

      await pumpAt(tester, AppRoutePaths.transferOf('sess-a11y'));

      final button = find.ancestor(
        of: find.text('Pause'),
        matching: find.byType(OneBitButton),
      );
      expect(button, findsOneWidget);
      expect(
        tester.getSemantics(button),
        isSemantics(label: 'Pause', isButton: true),
      );
      final size = tester.getSize(button);
      expect(
        size.height,
        greaterThanOrEqualTo(OneBitAccessibility.minInteractiveSize),
      );

      await disposeApp(tester);
    });
  });

  group('media gallery screen', () {
    testWidgets('tiles and category chips render at narrow widths', (
      tester,
    ) async {
      final container = await pumpShell(tester);
      await container
          .read(sqliteAttachmentRepositoryProvider)
          .save(
            Attachment(
              attachmentId: 'att-a11y-2',
              messageId: 'msg-a11y-2',
              metadata: const AttachmentMetadata(
                fileName: 'photo.png',
                mimeType: 'image/png',
                category: MediaCategory.image,
                sizeBytes: 1234,
              ),
              status: AttachmentStatus.ready,
              createdAt: DateTime.utc(2026, 1, 1),
              updatedAt: DateTime.utc(2026, 1, 1),
              isInline: true,
              inlineBytes: [1, 2, 3],
            ),
          );
      await tester.pumpAndSettle();

      await pumpAt(tester, AppRoutePaths.mediaGallery);

      expect(find.byType(MediaGalleryScreen), findsOneWidget);
      expect(find.text('photo.png'), findsOneWidget);
      expect(find.text('Images'), findsOneWidget);
      expect(find.text('Documents'), findsOneWidget);

      await disposeApp(tester);
    });
  });
}
