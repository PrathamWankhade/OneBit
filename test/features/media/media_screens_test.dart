import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:onebit/app/app_shell.dart';
import 'package:onebit/core/navigation/app_route_paths.dart';
import 'package:onebit/features/media/attachments/attachment.dart';
import 'package:onebit/features/media/presentation/media_gallery_screen.dart';
import 'package:onebit/features/media/presentation/media_providers.dart';
import 'package:onebit/features/media/presentation/transfer_progress_screen.dart';
import 'package:onebit/features/media/transfer/transfer_bitmap.dart';
import 'package:onebit/features/media/transfer/transfer_session.dart';
import 'package:onebit/features/media/transfer/transfer_state.dart';
import 'package:onebit/shared/design_system/components/onebit_empty_state.dart';

import '../../app/support/app_navigation_support.dart';
import '../../app/support/screen_test_support.dart';

/// Phase 10.5 media surfaces: the shared gallery and the transfer progress
/// screen (deep-linkable via the channels branch).
void main() {
  Future<void> seedAttachment(
    ProviderContainer container, {
    required String id,
    required String fileName,
    required String mimeType,
    required MediaCategory category,
  }) async {
    await container
        .read(sqliteAttachmentRepositoryProvider)
        .save(
          Attachment(
            attachmentId: id,
            messageId: 'msg-$id',
            metadata: AttachmentMetadata(
              fileName: fileName,
              mimeType: mimeType,
              category: category,
              sizeBytes: 2048,
            ),
            status: AttachmentStatus.ready,
            createdAt: DateTime.utc(2026, 1, 1),
            updatedAt: DateTime.utc(2026, 1, 1),
            isInline: true,
            inlineBytes: [1, 2, 3],
          ),
        );
  }

  Future<TransferSession> seedTransfer(
    ProviderContainer container, {
    required String sessionId,
    required String attachmentId,
    TransferState state = TransferState.queued,
  }) async {
    final session = TransferSession(
      sessionId: sessionId,
      attachmentId: attachmentId,
      peerNodeId: 'peer-9',
      direction: TransferDirection.send,
      state: state,
      chunkSize: 512,
      totalChunks: 4,
      chunksBitmap: TransferBitmap.empty(4),
      bytesTransferred: 0,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
      lastError: state == TransferState.failed
          ? 'retry budget exhausted'
          : null,
    );
    await container
        .read(sqliteTransferRepositoryProvider)
        .createSession(session);
    return session;
  }

  Future<void> pumpTransfer(WidgetTester tester, String sessionId) async {
    GoRouter.of(
      tester.element(find.byType(AppShell)),
    ).go(AppRoutePaths.transferOf(sessionId));
    await tester.pumpAndSettle();
  }

  group('media gallery', () {
    testWidgets('empty catalog shows the welcome empty state', (tester) async {
      await pumpShell(tester);

      GoRouter.of(
        tester.element(find.byType(AppShell)),
      ).go(AppRoutePaths.mediaGallery);
      await tester.pumpAndSettle();

      expect(find.byType(MediaGalleryScreen), findsOneWidget);
      expect(find.text('No media yet'), findsOneWidget);

      await disposeApp(tester);
    });

    testWidgets('seeded attachments render tiles and category filters', (
      tester,
    ) async {
      final container = await pumpShell(tester);
      await container
          .read(sqliteAttachmentRepositoryProvider)
          .save(
            Attachment(
              attachmentId: 'att-1',
              messageId: 'msg-1',
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

      GoRouter.of(
        tester.element(find.byType(AppShell)),
      ).go(AppRoutePaths.mediaGallery);
      await tester.pumpAndSettle();

      expect(find.byType(MediaGalleryScreen), findsOneWidget);
      expect(find.text('photo.png'), findsOneWidget);
      expect(find.text('1.2 KB'), findsOneWidget);
      expect(find.text('Images'), findsOneWidget);
      expect(find.text('Documents'), findsOneWidget);

      await tester.tap(find.text('Images'));
      await tester.pumpAndSettle();
      expect(find.text('photo.png'), findsOneWidget);

      await disposeApp(tester);
    });

    testWidgets('category filters isolate their own attachment kinds', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final container = await pumpShell(tester);
      await seedAttachment(
        container,
        id: 'att-img',
        fileName: 'photo.png',
        mimeType: 'image/png',
        category: MediaCategory.image,
      );
      await seedAttachment(
        container,
        id: 'att-doc',
        fileName: 'notes.txt',
        mimeType: 'text/plain',
        category: MediaCategory.document,
      );
      await tester.pumpAndSettle();

      GoRouter.of(
        tester.element(find.byType(AppShell)),
      ).go(AppRoutePaths.mediaGallery);
      await tester.pumpAndSettle();

      expect(find.text('photo.png'), findsOneWidget);
      expect(find.text('notes.txt'), findsOneWidget);

      await tester.tap(find.text('Documents'));
      await tester.pumpAndSettle();
      expect(find.text('notes.txt'), findsOneWidget);
      expect(find.text('photo.png'), findsNothing);

      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();
      expect(find.text('photo.png'), findsOneWidget);
      expect(find.text('notes.txt'), findsOneWidget);

      await disposeApp(tester);
    });
  });

  group('transfer progress', () {
    testWidgets('unknown session id renders the not-found state', (
      tester,
    ) async {
      await pumpShell(tester);

      GoRouter.of(
        tester.element(find.byType(AppShell)),
      ).go(AppRoutePaths.transferOf('missing-session'));
      await tester.pumpAndSettle();

      expect(find.byType(TransferProgressScreen), findsOneWidget);
      expect(find.byType(OneBitEmptyState), findsOneWidget);

      await disposeApp(tester);
    });

    testWidgets('active session renders progress, peer and control buttons', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final container = await pumpShell(tester);
      await seedAttachment(
        container,
        id: 'att-1',
        fileName: 'report.pdf',
        mimeType: 'application/pdf',
        category: MediaCategory.document,
      );
      await seedTransfer(container, sessionId: 'sess-1', attachmentId: 'att-1');
      await tester.pumpAndSettle();

      await pumpTransfer(tester, 'sess-1');

      expect(find.text('report.pdf'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('0 B'), findsOneWidget);
      expect(find.textContaining('2.0 KB'), findsOneWidget);
      expect(find.text('Pause'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
      expect(find.text('4 × 512 B'), findsOneWidget);
      expect(find.textContaining('ETA'), findsOneWidget);

      await disposeApp(tester);
    });

    testWidgets('pause flips the control to resume', (tester) async {
      final container = await pumpShell(tester);
      await seedAttachment(
        container,
        id: 'att-2',
        fileName: 'movie.mp4',
        mimeType: 'video/mp4',
        category: MediaCategory.video,
      );
      await seedTransfer(container, sessionId: 'sess-2', attachmentId: 'att-2');
      await tester.pumpAndSettle();

      await pumpTransfer(tester, 'sess-2');

      await tester.tap(find.text('Pause'));
      await tester.pumpAndSettle();

      expect(find.text('Resume'), findsOneWidget);
      expect(find.text('Pause'), findsNothing);

      await disposeApp(tester);
    });

    testWidgets('failed session offers retry which re-queues it', (
      tester,
    ) async {
      final container = await pumpShell(tester);
      await seedAttachment(
        container,
        id: 'att-3',
        fileName: 'broken.zip',
        mimeType: 'application/zip',
        category: MediaCategory.document,
      );
      await seedTransfer(
        container,
        sessionId: 'sess-3',
        attachmentId: 'att-3',
        state: TransferState.failed,
      );
      await tester.pumpAndSettle();

      await pumpTransfer(tester, 'sess-3');

      expect(find.text('Failed'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Retry'), findsNothing);
      expect(find.text('Pause'), findsOneWidget);

      await disposeApp(tester);
    });

    testWidgets('cancel confirms through the dialog and ends the session', (
      tester,
    ) async {
      final container = await pumpShell(tester);
      await seedAttachment(
        container,
        id: 'att-4',
        fileName: 'payload.bin',
        mimeType: 'application/octet-stream',
        category: MediaCategory.document,
      );
      await seedTransfer(container, sessionId: 'sess-4', attachmentId: 'att-4');
      await tester.pumpAndSettle();

      await pumpTransfer(tester, 'sess-4');

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Cancel transfer?'), findsOneWidget);
      await tester.tap(
        find
            .descendant(
              of: find.byType(AlertDialog),
              matching: find.text('Delete'),
            )
            .last,
      );
      await tester.pumpAndSettle();

      expect(find.text('Pause'), findsNothing);
      expect(find.text('Delete'), findsNothing);
      expect(find.text('Resume'), findsNothing);

      await disposeApp(tester);
    });

    testWidgets('completed session hides every control', (tester) async {
      final container = await pumpShell(tester);
      await seedAttachment(
        container,
        id: 'att-5',
        fileName: 'done.png',
        mimeType: 'image/png',
        category: MediaCategory.image,
      );
      await seedTransfer(
        container,
        sessionId: 'sess-5',
        attachmentId: 'att-5',
        state: TransferState.completed,
      );
      await tester.pumpAndSettle();

      await pumpTransfer(tester, 'sess-5');

      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('Pause'), findsNothing);
      expect(find.text('Retry'), findsNothing);
      expect(find.text('Delete'), findsNothing);

      await disposeApp(tester);
    });
  });
}
