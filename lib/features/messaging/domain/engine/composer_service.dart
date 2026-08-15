import 'package:onebit/core/errors/failure.dart';
import 'package:onebit/core/logger/app_logger.dart';
import 'package:onebit/core/logger/log_tags.dart';
import 'package:onebit/core/result/result.dart';
import 'package:onebit/features/messaging/data/id/message_id_generator.dart';
import 'package:onebit/features/messaging/data/wire/message_wire_codec.dart';
import 'package:onebit/features/messaging/domain/channels/channel_repository.dart';
import 'package:onebit/features/messaging/domain/messages/message.dart';
import 'package:onebit/features/messaging/domain/messages/message_metadata.dart';
import 'package:onebit/features/messaging/domain/messages/message_priority.dart';
import 'package:onebit/features/messaging/domain/messages/message_repository.dart';
import 'package:onebit/features/messaging/domain/messages/message_status.dart';
import 'package:onebit/features/messaging/domain/messages/message_type.dart';

/// Validates and prepares an outgoing message.
///
/// The composer is the only place a user-initiated send enters the app: it
/// checks the channel exists, allocates the per-channel sequence id and
/// persists the message in [MessageStatus.queued]. Delivery is the outbox's
/// problem.
final class ComposerService {
  ComposerService({
    required this.localNodeId,
    required this.channels,
    required this.messages,
    required this.logger,
    this.idGenerator = const MessageIdGenerator(),
  });

  /// The node id of every message composed by this engine.
  final String localNodeId;

  final ChannelRepository channels;
  final MessageRepository messages;

  /// Supplies wire-safe message ids.
  final MessageIdGenerator idGenerator;

  final AppLogger logger;

  static const _tag = LogTags.messaging;

  /// Reserved message types that can never be composed by a user.
  static final Set<MessageType> _nonComposable = {
    MessageType.receipt,
    MessageType.system,
    MessageType.identity,
    MessageType.handshake,
    MessageType.developer,
  };

  /// Composes, validates and persists a new outgoing message.
  ///
  /// Returns the persisted message in [MessageStatus.queued], or an
  /// [Err] with a [MessageValidationFailure] / storage failure. Passing a
  /// [clientId] makes the send idempotent at compose time (the id becomes
  /// the message id); pass `null` to mint a fresh id.
  Future<Result<Message>> prepareSend({
    required String channelId,
    required String body,
    MessageType type = MessageType.text,
    MessagePriority priority = MessagePriority.normal,
    String? replyTo,
    bool forwarded = false,
    String? clientId,
    Duration? ttl,
    DateTime? timestamp,
  }) async {
    if (body.trim().isEmpty) {
      return const Err(
        MessageValidationFailure(
          reason: 'emptyBody',
          message: 'message body must not be blank',
        ),
      );
    }
    if (body.length > MessageWireCodec.maxPayloadBytes - 8 * 1024) {
      return const Err(
        MessageValidationFailure(
          reason: 'tooLong',
          message: 'message body exceeds the wire payload budget',
        ),
      );
    }
    if (_nonComposable.contains(type)) {
      return const Err(
        MessageValidationFailure(
          reason: 'nonComposableType',
          message: 'this message type cannot be composed and sent',
        ),
      );
    }

    final channelResult = await channels.getChannel(channelId);
    final channel = channelResult.value;
    if (channel == null) {
      return Err(
        MessageValidationFailure(
          reason: 'unknownChannel',
          message: 'no channel $channelId',
        ),
      );
    }

    final sequenceResult = await channels.nextSequence(channelId);
    if (sequenceResult.isErr) {
      return Err(sequenceResult.failure!);
    }
    final sequence = sequenceResult.value!;

    final now = timestamp ?? DateTime.now();
    final message = Message(
      messageId: clientId ?? idGenerator.next(),
      channelId: channelId,
      sender: localNodeId,
      receiver: channel.peer,
      type: type,
      status: MessageStatus.queued,
      priority: priority,
      body: body,
      timestamp: now,
      sequence: sequence,
      packetOrder: now.microsecondsSinceEpoch,
      replyTo: replyTo,
      forwarded: forwarded,
      ttl: ttl,
      metadata: MessageMetadata(clientId: clientId),
    );

    final stored = await messages.insert(message);
    if (stored is Ok<Message>) {
      logger.debug(
        'composed ${stored.value!.messageId} -> $channelId',
        tag: _tag,
      );
    } else {
      logger.warning('compose failed: ${stored.failure}', tag: _tag);
    }
    return stored;
  }
}
