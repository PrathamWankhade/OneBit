import 'package:drift/drift.dart';
import 'package:onebit/core/database/database.dart';
import 'package:onebit/core/database/repository/result_guards.dart';
import 'package:onebit/core/database/tables/enums.dart' as core;
import 'package:onebit/core/errors/failure.dart';
import 'package:onebit/core/logger/app_logger.dart';
import 'package:onebit/core/logger/log_tags.dart';
import 'package:onebit/core/result/result.dart';
import 'package:onebit/features/messaging/data/mappers/channel_mapper.dart';
import 'package:onebit/features/messaging/domain/channels/channel.dart';
import 'package:onebit/features/messaging/domain/channels/channel_repository.dart';
import 'package:onebit/features/messaging/domain/channels/channel_settings.dart';
import 'package:onebit/features/messaging/domain/channels/channel_type.dart';
import 'package:onebit/features/messaging/domain/channels/conversation_summary.dart';
import 'package:onebit/features/messaging/domain/channels/pinned_message.dart';

/// Drift-backed [ChannelRepository].
final class SqliteChannelRepository implements ChannelRepository {
  SqliteChannelRepository({
    required this._db,
    required this.localNodeId,
    required this.logger,
  });

  final OneBitDatabase _db;
  final String localNodeId;
  final AppLogger logger;

  static const _tag = LogTags.messaging;

  $ChannelsTable get _channels => _db.channels;
  $PinnedMessagesTable get _pins => _db.pinnedMessages;

  Channel _withPeer(Channel channel) {
    if (channel.type != ChannelType.private || channel.peer != null) {
      return channel;
    }
    final peer = ChannelMapper.peerOf(channel.channelId, localNodeId);
    return peer == null
        ? channel
        : Channel(
            channelId: channel.channelId,
            type: channel.type,
            title: channel.title,
            peer: peer,
            createdAt: channel.createdAt,
            settings: channel.settings,
            summary: channel.summary.copyWith(peerNode: peer),
          );
  }

  ConversationSummary _summaryWithPeer(ConversationSummary summary) {
    if (summary.type != ChannelType.private || summary.peerNode != null) {
      return summary;
    }
    final peer = ChannelMapper.peerOf(summary.channelId, localNodeId);
    return peer == null ? summary : summary.copyWith(peerNode: peer);
  }

  @override
  Stream<Result<List<ConversationSummary>>> watchSummaries({
    bool includeArchived = false,
  }) {
    final query = _db.select(_channels)
      ..where(
        (t) =>
            includeArchived ? const Constant(true) : t.archived.equals(false),
      )
      ..orderBy([
        (t) => OrderingTerm.desc(t.pinned),
        (t) => OrderingTerm.desc(t.updatedAt),
      ]);
    return ResultGuards.guardWatch(
      logger,
      '$_tag.watchSummaries',
      query.watch().map(
        (rows) =>
            rows.map(ChannelMapper.toSummary).map(_summaryWithPeer).toList(),
      ),
    );
  }

  @override
  Future<Result<List<ConversationSummary>>> listSummaries({
    bool includeArchived = false,
  }) => ResultGuards.guard(logger, '$_tag.listSummaries', () async {
    final rows =
        await (_db.select(_channels)
              ..where(
                (t) => includeArchived
                    ? const Constant(true)
                    : t.archived.equals(false),
              )
              ..orderBy([
                (t) => OrderingTerm.desc(t.pinned),
                (t) => OrderingTerm.desc(t.updatedAt),
              ]))
            .get();
    return rows.map(ChannelMapper.toSummary).map(_summaryWithPeer).toList();
  });

  @override
  Future<Result<Channel?>> getChannel(String channelId) =>
      ResultGuards.guard(logger, '$_tag.getChannel($channelId)', () async {
        final row = await (_db.select(
          _channels,
        )..where((t) => t.channelId.equals(channelId))).getSingleOrNull();
        return row == null ? null : _withPeer(ChannelMapper.toDomain(row));
      });

  @override
  Future<Result<Channel>> create(CreateChannelParams params) {
    if (params.type == ChannelType.private) {
      final peer = params.peer;
      if (peer == null || peer == localNodeId) {
        return Future.value(
          const Err(
            MessageValidationFailure(
              reason: 'invalidPeer',
              message: 'private channels need a distinct peer',
            ),
          ),
        );
      }
    }
    return ResultGuards.guard(logger, '$_tag.create(${params.type})', () async {
      final id = _channelIdFor(params);
      final existing = await (_db.select(
        _channels,
      )..where((t) => t.channelId.equals(id))).getSingleOrNull();
      if (existing != null) return _withPeer(ChannelMapper.toDomain(existing));

      final title =
          params.title ??
          (params.type == ChannelType.private ? params.peer! : '');
      await _db
          .into(_channels)
          .insert(
            ChannelRow(
              channelId: id,
              type: ChannelMapper.toCore(params.type),
              title: title,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              unreadCount: 0,
              lastMessageId: null,
              lastMessageAt: null,
              archived: false,
              pinned: false,
              muted: false,
              mutedUntil: null,
              lastSequence: 0,
              notificationPreference: 'all',
              autoDeleteAfter: _secondsOrNull(params.autoDeleteAfter),
            ),
          );
      final row = await (_db.select(
        _channels,
      )..where((t) => t.channelId.equals(id))).getSingle();
      return _withPeer(ChannelMapper.toDomain(row));
    });
  }

  String _channelIdFor(CreateChannelParams params) {
    switch (params.type) {
      case ChannelType.private:
        return ChannelMapper.privateChannelId(localNodeId, params.peer!);
      case ChannelType.group:
      case ChannelType.broadcast:
      case ChannelType.emergency:
      case ChannelType.developer:
        // Deterministic per-(type, title) id so retries converge on the
        // same channel while distinct broadcasts stay distinct.
        final seed = params.peer ?? params.title ?? '';
        final hash = seed.hashCode.abs().toRadixString(16);
        return 'channel:${params.type.name}:$hash';
    }
  }

  @override
  Future<Result<Channel>> rename(String channelId, String title) =>
      ResultGuards.guard(logger, '$_tag.rename($channelId)', () async {
        await _touch(channelId, ChannelsCompanion(title: Value(title)));
        final row = await (_db.select(
          _channels,
        )..where((t) => t.channelId.equals(channelId))).getSingle();
        return _withPeer(ChannelMapper.toDomain(row));
      });

  @override
  Future<Result<void>> archive(String channelId, {bool archived = true}) =>
      ResultGuards.guard(logger, '$_tag.archive($channelId)', () async {
        await _touch(channelId, ChannelsCompanion(archived: Value(archived)));
      });

  @override
  Future<Result<void>> deleteChannel(String channelId) =>
      ResultGuards.guard(logger, '$_tag.deleteChannel($channelId)', () async {
        // The FKs cascade messages → receipts/reactions/metadata/attachments
        // and channels → drafts/pins/typing; a single delete removes the
        // whole channel in one transaction.
        await (_db.delete(
          _channels,
        )..where((t) => t.channelId.equals(channelId))).go();
      });

  @override
  Future<Result<void>> recordTypingEvent({
    required String channelId,
    required String node,
    required TypingDiagnosticsKind kind,
    required DateTime startedAt,
    DateTime? endedAt,
  }) => ResultGuards.guard(logger, '$_tag.recordTypingEvent', () async {
    final coreKind =
        core.TypingKind.values.where((k) => k.name == kind.name).firstOrNull ??
        core.TypingKind.idle;
    // Developer diagnostics only — failures never disturb the typing bus.
    await _db
        .into(_db.typingEvents)
        .insert(
          TypingEventsCompanion.insert(
            channelId: channelId,
            node: node,
            kind: coreKind,
            startedAt: startedAt,
            endedAt: Value(endedAt),
          ),
        );
  });

  @override
  Future<Result<void>> setMuted(String channelId, {DateTime? until}) =>
      ResultGuards.guard(logger, '$_tag.setMuted($channelId)', () async {
        await _touch(
          channelId,
          ChannelsCompanion(muted: const Value(true), mutedUntil: Value(until)),
        );
      });

  @override
  Future<Result<void>> unmute(String channelId) =>
      ResultGuards.guard(logger, '$_tag.unmute($channelId)', () async {
        await _touch(
          channelId,
          const ChannelsCompanion(muted: Value(false), mutedUntil: Value(null)),
        );
      });

  @override
  Future<Result<void>> setPinned(String channelId, {required bool pinned}) =>
      ResultGuards.guard(logger, '$_tag.setPinned($channelId)', () async {
        await _touch(channelId, ChannelsCompanion(pinned: Value(pinned)));
      });

  @override
  Future<Result<void>> setNotificationPreference(
    String channelId,
    ChannelNotificationPreference preference,
  ) => ResultGuards.guard(logger, '$_tag.setNotificationPreference', () async {
    await _touch(
      channelId,
      ChannelsCompanion(notificationPreference: Value(preference.name)),
    );
  });

  @override
  Future<Result<void>> markRead(String channelId) =>
      ResultGuards.guard(logger, '$_tag.markRead($channelId)', () async {
        await _touch(channelId, const ChannelsCompanion(unreadCount: Value(0)));
      });

  /// Transactional monotonic per-channel sequence allocation.
  @override
  Future<Result<int>> nextSequence(String channelId) =>
      ResultGuards.guard(logger, '$_tag.nextSequence($channelId)', () async {
        return _db.transaction(() async {
          final row = await (_db.select(
            _channels,
          )..where((t) => t.channelId.equals(channelId))).getSingleOrNull();
          if (row == null) return 1;
          final next = row.lastSequence + 1;
          await (_db.update(_channels)
                ..where((t) => t.channelId.equals(channelId)))
              .write(ChannelsCompanion(lastSequence: Value(next)));
          return next;
        });
      });

  @override
  Future<Result<void>> bumpActivity(
    String channelId, {
    int unreadDelta = 0,
    String? lastMessageId,
    DateTime? lastMessageAt,
  }) => ResultGuards.guard(logger, '$_tag.bumpActivity($channelId)', () async {
    final now = DateTime.now();
    final row = await (_db.select(
      _channels,
    )..where((t) => t.channelId.equals(channelId))).getSingleOrNull();
    if (row == null) {
      throw const MessageValidationFailure(
        reason: 'Unknown channel for bumpActivity.',
      );
    }
    await (_db.update(
      _channels,
    )..where((t) => t.channelId.equals(channelId))).write(
      ChannelsCompanion(
        unreadCount: Value(
          (row.unreadCount + unreadDelta).clamp(0, 1 << 24).toInt(),
        ),
        lastMessageId: Value(lastMessageId),
        lastMessageAt: Value(lastMessageAt),
        updatedAt: Value(now),
      ),
    );
  });

  // ---- Pinned messages --------------------------------------------------------

  @override
  Future<Result<void>> pinMessage(String channelId, String messageId) =>
      ResultGuards.guard(logger, '$_tag.pinMessage', () async {
        await _db
            .into(_pins)
            .insert(
              PinnedMessagesCompanion.insert(
                channelId: channelId,
                messageId: messageId,
                pinnedBy: localNodeId,
                pinnedAt: DateTime.now(),
              ),
              mode: InsertMode.insertOrIgnore,
            );
      });

  @override
  Future<Result<void>> unpinMessage(String channelId, String messageId) =>
      ResultGuards.guard(logger, '$_tag.unpinMessage', () async {
        await (_db.delete(_pins)..where(
              (t) =>
                  t.channelId.equals(channelId) & t.messageId.equals(messageId),
            ))
            .go();
      });

  @override
  Future<Result<List<PinnedMessage>>> pinnedMessages(String channelId) =>
      ResultGuards.guard(logger, '$_tag.pinnedMessages', () async {
        final rows =
            await (_db.select(_pins)
                  ..where((t) => t.channelId.equals(channelId))
                  ..orderBy([(t) => OrderingTerm.desc(t.pinnedAt)]))
                .get();
        return rows.map(ChannelMapper.toPinnedMessage).toList();
      });

  Future<void> _touch(String channelId, ChannelsCompanion companion) async {
    await (_db.update(_channels)..where((t) => t.channelId.equals(channelId)))
        .write(companion.copyWith(updatedAt: Value(DateTime.now())));
  }

  static int? _secondsOrNull(Duration? duration) => duration?.inSeconds;
}
