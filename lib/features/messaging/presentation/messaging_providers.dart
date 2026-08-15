import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/core/database/database_providers.dart';
import 'package:onebit/core/logger/logger_providers.dart';
import 'package:onebit/core/result/result.dart';
import 'package:onebit/features/dtn/dtn_providers.dart';
import 'package:onebit/features/messaging/data/repositories/sqlite_channel_repository.dart';
import 'package:onebit/features/messaging/data/repositories/sqlite_draft_repository.dart';
import 'package:onebit/features/messaging/data/repositories/sqlite_message_repository.dart';
import 'package:onebit/features/messaging/data/repositories/sqlite_notification_repository.dart';
import 'package:onebit/features/messaging/data/repositories/sqlite_receipt_repository.dart';
import 'package:onebit/features/messaging/data/repositories/sqlite_search_repository.dart';
import 'package:onebit/features/messaging/domain/channels/channel.dart';
import 'package:onebit/features/messaging/domain/channels/channel_repository.dart';
import 'package:onebit/features/messaging/domain/channels/conversation_summary.dart';
import 'package:onebit/features/messaging/domain/drafts/draft.dart';
import 'package:onebit/features/messaging/domain/drafts/draft_repository.dart';
import 'package:onebit/features/messaging/domain/engine/messaging_engine.dart';
import 'package:onebit/features/messaging/domain/messages/message.dart';
import 'package:onebit/features/messaging/domain/messages/message_repository.dart';
import 'package:onebit/features/messaging/domain/notifications/notification.dart';
import 'package:onebit/features/messaging/domain/notifications/notification_repository.dart';
import 'package:onebit/features/messaging/domain/receipts/receipt_repository.dart';
import 'package:onebit/features/messaging/domain/search/search_repository.dart';
export 'compose_message_controller.dart'
    show composeMessageControllerProvider, ComposeView, ComposeMode;

/// The node id stamped onto every outbound message.
///
/// The identity feature will plug the real node id here as soon as one
/// exists; the current value keeps the provider graph synchronous.
final Provider<String> localNodeIdProvider = Provider<String>((ref) => 'local');

/// Channel repository (drift-backed, shared database).
final Provider<ChannelRepository> channelRepositoryProvider =
    Provider<ChannelRepository>(
      (ref) => SqliteChannelRepository(
        db: ref.watch(databaseProvider),
        localNodeId: ref.watch(localNodeIdProvider),
        logger: ref.watch(appLoggerProvider),
      ),
    );

/// Message repository.
final Provider<MessageRepository> messageRepositoryProvider =
    Provider<MessageRepository>(
      (ref) => SqliteMessageRepository(
        db: ref.watch(databaseProvider),
        logger: ref.watch(appLoggerProvider),
      ),
    );

/// Draft repository.
final Provider<DraftRepository> draftRepositoryProvider =
    Provider<DraftRepository>(
      (ref) => SqliteDraftRepository(
        db: ref.watch(databaseProvider),
        logger: ref.watch(appLoggerProvider),
      ),
    );

/// Receipt repository.
final Provider<ReceiptRepository> receiptRepositoryProvider =
    Provider<ReceiptRepository>(
      (ref) => SqliteReceiptRepository(
        db: ref.watch(databaseProvider),
        logger: ref.watch(appLoggerProvider),
      ),
    );

/// Search repository (FTS5).
final Provider<SearchRepository> searchRepositoryProvider =
    Provider<SearchRepository>(
      (ref) => SqliteSearchRepository(
        db: ref.watch(databaseProvider),
        logger: ref.watch(appLoggerProvider),
      ),
    );

/// Notification repository.
final Provider<NotificationRepository> notificationRepositoryProvider =
    Provider<NotificationRepository>(
      (ref) => SqliteNotificationRepository(
        db: ref.watch(databaseProvider),
        logger: ref.watch(appLoggerProvider),
      ),
    );

/// The messaging façade: engine + repository wiring.
///
/// Watching this provider starts the engine (and its inbound pump) lazily
/// on first read; disposal stops the pump and cleans the typing bus.
final Provider<MessagingEngine> messagingEngineProvider =
    Provider<MessagingEngine>((ref) {
      final logger = ref.watch(appLoggerProvider);
      final engine = MessagingEngine(
        localNodeId: ref.watch(localNodeIdProvider),
        dtn: ref.watch(dtnRepositoryProvider),
        channels: ref.watch(channelRepositoryProvider),
        messages: ref.watch(messageRepositoryProvider),
        drafts: ref.watch(draftRepositoryProvider),
        receipts: ref.watch(receiptRepositoryProvider),
        search: ref.watch(searchRepositoryProvider),
        notifications: ref.watch(notificationRepositoryProvider),
        logger: logger,
      );
      engine.start();
      ref.onDispose(() => unawaited(engine.stop()));
      return engine;
    });

// ---------------------------------------------------------------------------
// UI-facing view providers
// ---------------------------------------------------------------------------

/// Timeline stream of a channel (newest-last).
final channelTimelineProvider =
    StreamProvider.family.autoDispose<Result<List<Message>>, String>(
      (ref, channelId) =>
          ref.watch(messagingEngineProvider).watchChannel(channelId),
    );

/// Conversation list stream (active channels, archived excluded).
final conversationSummariesProvider =
    StreamProvider<Result<List<ConversationSummary>>>(
      (ref) => ref.watch(messagingEngineProvider).watchSummaries(),
    );

/// Conversation list stream including archived channels.
final archivedConversationSummariesProvider =
    StreamProvider.autoDispose<Result<List<ConversationSummary>>>(
      (ref) => ref
          .watch(messagingEngineProvider)
          .watchSummaries(includeArchived: true),
    );

/// Draft stream of a channel (null when absent).
final channelDraftProvider =
    StreamProvider.family.autoDispose<Result<Draft?>, String>(
  (ref, channelId) => ref.watch(messagingEngineProvider).watchDraft(channelId),
);

/// Single-channel lookup.
final channelProvider = FutureProvider.family<Result<Channel?>, String>(
  (ref, channelId) =>
      ref.watch(channelRepositoryProvider).getChannel(channelId),
);

/// Internal notification event stream (future UI surfaces these).
final notificationStreamProvider = StreamProvider<Result<NotificationEvent>>(
  (ref) => ref.watch(messagingEngineProvider).watchNotifications(),
);

/// Typing bookkeeping: presence keys currently active (`channelId::node`).
final typingPresenceProvider = Provider<ValueNotifier<Set<String>>>(
  (ref) => ref.watch(messagingEngineProvider).typing.typingKeys,
);

// Compose message controller
