import 'package:onebit/core/errors/failure.dart';
import 'package:onebit/core/logger/app_logger.dart';
import 'package:onebit/core/logger/log_tags.dart';
import 'package:onebit/core/result/result.dart';
import 'package:onebit/features/dtn/domain/dtn_failure.dart';
import 'package:onebit/features/dtn/domain/dtn_repository.dart';
import 'package:onebit/features/messaging/data/adapters/dtn_transport.dart';
import 'package:onebit/features/messaging/data/wire/message_wire_codec.dart';
import 'package:onebit/features/messaging/domain/messages/message.dart';
import 'package:onebit/features/messaging/domain/messages/message_repository.dart';
import 'package:onebit/features/messaging/domain/messages/message_status.dart';
import 'package:onebit/features/messaging/domain/notifications/notification.dart';
import 'package:onebit/features/messaging/domain/notifications/notification_repository.dart';

/// Moves queued messages onto the mesh through the one allowed seam:
/// [DTNRepository].
///
/// Encode → persist packet id → store → persist status. A store failure
/// marks the message [MessageStatus.failed] with the reason recorded in its
/// metadata; the envelope id returned by the DTN layer is recorded **before**
/// the wire store so a crash in between is reconciled idempotently on the
/// next start (DTN store is idempotent per packet id).
final class Outbox {
  Outbox({
    required this.localNodeId,
    required this.dtn,
    required this.messages,
    required this.notifications,
    required this.logger,
  });

  /// Source node id stamped on every outgoing envelope.
  final String localNodeId;

  final DTNRepository dtn;
  final MessageRepository messages;
  final NotificationRepository notifications;
  final AppLogger logger;

  static const _tag = LogTags.messaging;

  /// Stores the envelope for [message] and advances it to `waiting`.
  Future<Result<Message>> enqueue(Message message) => _enqueue(message);

  Future<Result<Message>> _enqueue(Message message) async {
    // Already parked with its envelope — nothing to do (idempotent retry).
    if (message.status == MessageStatus.waiting &&
        message.metadata.packetId != null) {
      return Ok(message);
    }

    List<int> payload;
    try {
      final wire = WireMessageEnvelope.of(message);
      payload = const MessageWireCodec().encode(wire);
    } on Object catch (error) {
      return Err(
        MessageValidationFailure(
          reason: 'encodeFailure',
          message: 'cannot encode ${message.messageId}: $error',
        ),
      );
    }

    final now = DateTime.now();
    // Crash recovery reuses the packet id recorded before the first store
    // attempt; every other path (retry, resend, cancel re-arm) mints a fresh
    // one so the DTN layer never confuses a cancelled envelope with a new
    // delivery.
    final reuse =
        message.metadata.packetId != null &&
        (message.status == MessageStatus.created ||
            message.status == MessageStatus.queued);
    final packetId = reuse
        ? message.metadata.packetId!
        : MessengerEnvelopeDefaults.packetId(localNodeId, now);
    final packet = MessengerEnvelopeDefaults.messagePacket(
      packetId: packetId,
      source: localNodeId,
      destination: message.receiver ?? message.channelId,
      payload: payload,
      priority: message.priority,
      now: now,
    );

    // Persist the envelope id while still in `queued` (crash-safe window).
    if (!reuse && message.status != MessageStatus.failed) {
      final parked = await messages.update(
        message.copyWith(
          metadata: message.metadata.copyWith(
            packetId: packetId,
            lastError: null,
          ),
        ),
      );
      if (parked is Err<Message>) {
        return parked;
      }
    }

    try {
      await dtn.store(packet);
    } on DtnFailure catch (failure) {
      logger.warning(
        'outbox store(${message.messageId}) failed: $failure',
        tag: _tag,
      );
      await _markFailed(message, failure.message ?? 'store rejected');
      return Err(
        UnexpectedFailure(
          message: 'DTN store failed for ${message.messageId}',
          cause: failure,
        ),
      );
    } on Object catch (error, stackTrace) {
      // Any other failure (transport hiccup, broken plugin) parks the
      // message the same way — the seam must never throw into callers.
      logger.warning(
        'outbox store(${message.messageId}) threw: $error',
        tag: _tag,
        error: error,
      );
      await _markFailed(message, 'store threw: $error');
      return Err(
        UnexpectedFailure(
          message: 'DTN store threw for ${message.messageId}',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }

    final updated = await messages.update(
      message.copyWith(
        status: MessageStatus.waiting,
        metadata: message.metadata.copyWith(packetId: packetId),
      ),
    );
    logger.debug('enqueued ${message.messageId} as $packetId', tag: _tag);
    final current = updated is Ok<Message> ? updated.value : message;
    await notifications.push(
      NotificationEvent(
        kind: NotificationKind.messageEnqueued,
        channelId: current?.channelId ?? message.channelId,
        messageId: current?.messageId ?? message.messageId,
        node: current?.receiver ?? message.receiver,
        level: NotificationLevel.info,
        payload: {'packetId': packetId},
        createdAt: DateTime.now(),
      ),
    );
    return updated;
  }

  /// Re-stores an already-delivered envelope under a fresh packet id
  /// (edit resend). New packet, message stays in its current state.
  Future<Result<Message>> resend(Message message) => _enqueue(message);

  /// Cancels the envelope of [message] against the DTN layer and marks the
  /// message failed (`cancelled`).
  Future<Result<void>> cancel(Message message) async {
    final packetId = message.metadata.packetId;
    if (packetId != null) {
      try {
        await dtn.cancel(packetId);
      } on DtnFailure catch (failure) {
        if (failure.kind != DtnFailureKind.notFound) {
          logger.warning(
            'outbox cancel($packetId) failed: $failure',
            tag: _tag,
          );
        }
      }
    }
    await _markFailed(message, 'cancelled by user');
    return const Ok(null);
  }

  Future<void> _markFailed(Message message, String reason) async {
    await messages.update(
      message.copyWith(
        status: MessageStatus.failed,
        metadata: message.metadata.copyWith(
          lastError: reason,
          attemptCount: message.metadata.attemptCount + 1,
        ),
      ),
    );
    await notifications.push(
      NotificationEvent(
        kind: NotificationKind.messageFailed,
        channelId: message.channelId,
        messageId: message.messageId,
        node: message.receiver,
        level: NotificationLevel.error,
        title: 'message failed',
        body: reason,
        payload: {'reason': reason},
        createdAt: DateTime.now(),
      ),
    );
  }
}
