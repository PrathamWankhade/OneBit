import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:onebit/core/errors/failure.dart';
import 'package:onebit/core/result/result.dart';
import 'package:onebit/features/messaging/domain/messages/message.dart';
import 'package:onebit/features/messaging/domain/messages/message_priority.dart';
import 'package:onebit/features/messaging/domain/messages/message_type.dart';

/// A message serialized for the wire (inside a DTN envelope payload).
///
/// Deliberately plain JSON: the envelope is what the future crypto layer
/// seals; until then it travels as-is and local SQLite keeps `body` at
/// rest. `v` is the payload schema version.
@immutable
final class WireMessageEnvelope {
  const WireMessageEnvelope({
    required this.messageId,
    required this.channelId,
    required this.sender,
    required this.type,
    required this.body,
    required this.sequence,
    required this.timestamp,
    this.v = 1,
    this.receiver,
    this.replyTo,
    this.edited = false,
    this.forwarded = false,
    this.priority = MessagePriority.normal,
    this.version = 1,
    this.ttlSeconds,
  });

  final int v;
  final String messageId;
  final String channelId;
  final String sender;
  final String? receiver;
  final MessageType type;
  final String body;
  final int sequence;
  final DateTime timestamp;
  final String? replyTo;
  final bool edited;
  final bool forwarded;
  final MessagePriority priority;
  final int version;
  final int? ttlSeconds;

  /// Snapshots the transport-relevant fields of [message].
  factory WireMessageEnvelope.of(Message message) => WireMessageEnvelope(
    messageId: message.messageId,
    channelId: message.channelId,
    sender: message.sender,
    receiver: message.receiver,
    type: message.type,
    body: message.body,
    sequence: message.sequence,
    timestamp: message.timestamp,
    replyTo: message.replyTo,
    edited: message.edited,
    forwarded: message.forwarded,
    priority: message.priority,
    version: message.version,
    ttlSeconds: message.ttl?.inSeconds,
  );
}

/// Sealed decode outcome: what an envelope payload actually is.
sealed class WireEnvelope {
  const WireEnvelope();
}

final class WireMessageResult extends WireEnvelope {
  const WireMessageResult(this.payload);
  final WireMessageEnvelope payload;
}

final class WireReceiptEnvelope extends WireEnvelope {
  const WireReceiptEnvelope({
    required this.messageId,
    required this.node,
    required this.at,
    required this.isRead,
    this.device,
    this.version = 1,
    this.channelId,
    this.cursorMessageId,
    this.cursorSequence,
    this.cursorTimestamp,
  });

  final String messageId;
  final String node;
  final DateTime at;

  /// true = read receipt, false = delivery receipt.
  final bool isRead;
  final String? device;
  final int version;

  /// Read-cursor batching: when present, this receipt covers every message
  /// of [channelId] read through the cursor key instead of one message.
  final String? channelId;
  final String? cursorMessageId;
  final int? cursorSequence;
  final DateTime? cursorTimestamp;

  bool get isCursor => cursorMessageId != null && channelId != null;
}

class WireTypingEnvelope extends WireEnvelope {
  const WireTypingEnvelope({
    required this.channelId,
    required this.node,
    required this.state,
    required this.ts,
  });

  final String channelId;
  final String node;
  final String state; // started | stopped
  final DateTime ts;
}

/// Unknown / malformed envelope kind.
final class WireUnknownEnvelope extends WireEnvelope {
  const WireUnknownEnvelope(this.reason);
  final String reason;
}

/// Versioned wire codec for message, receipt and typing envelopes.
///
/// Encode throws [FormatException]; decode returns a [Result] that never
/// throws, so the inbound pump treats bad payloads as dropped packets.
final class MessageWireCodec {
  const MessageWireCodec();

  static const int currentVersion = 1;

  /// Maximum serialized payload budget (aligns with DTN envelope limits).
  static const int maxPayloadBytes = 64 * 1024;

  List<int> encode(WireMessageEnvelope envelope) {
    final map = <String, Object?>{
      'v': envelope.v,
      'kind': 'M',
      'mid': envelope.messageId,
      'cid': envelope.channelId,
      'sender': envelope.sender,
      if (envelope.receiver != null) 'receiver': envelope.receiver,
      'type': envelope.type.wireName,
      'body': envelope.body,
      'seq': envelope.sequence,
      'ts': envelope.timestamp.millisecondsSinceEpoch,
      if (envelope.replyTo != null) 'replyTo': envelope.replyTo,
      'edited': envelope.edited,
      'forwarded': envelope.forwarded,
      'prio': envelope.priority.wireName,
      'ver': envelope.version,
      if (envelope.ttlSeconds != null) 'ttl': envelope.ttlSeconds,
    };
    final bytes = utf8.encode(jsonEncode(map));
    if (bytes.length > maxPayloadBytes) {
      throw const FormatException('message payload exceeds budget');
    }
    return bytes;
  }

  List<int> encodeReceipt({
    required String messageId,
    required String node,
    required DateTime at,
    required bool isRead,
    String? device,
    int version = 1,
  }) => _encodeReceipt({
    'v': currentVersion,
    'kind': 'R',
    'mid': messageId,
    'node': node,
    'at': at.millisecondsSinceEpoch,
    'read': isRead,
    'device': ?device,
    'ver': version,
  });

  /// One batched read-cursor envelope per channel-mark-read operation: the
  /// peer reads everything up to (and including) the cursor message in one
  /// packet instead of one envelope per message.
  List<int> encodeReadCursor({
    required String channelId,
    required String node,
    required String throughMessageId,
    required int throughSequence,
    required DateTime throughTimestamp,
    required DateTime at,
    String? device,
    int version = 1,
  }) => _encodeReceipt({
    'v': currentVersion,
    'kind': 'R',
    'mid': throughMessageId,
    'node': node,
    'at': at.millisecondsSinceEpoch,
    'read': true,
    'cid': channelId,
    'cursor': {
      'mid': throughMessageId,
      'seq': throughSequence,
      'ts': throughTimestamp.millisecondsSinceEpoch,
    },
    'device': ?device,
    'ver': version,
  });

  List<int> _encodeReceipt(Map<String, Object?> map) =>
      utf8.encode(jsonEncode(map));

  List<int> encodeTyping({
    required String channelId,
    required String node,
    required String state,
    required DateTime ts,
  }) => utf8.encode(
    jsonEncode(<String, Object>{
      'v': currentVersion,
      'kind': 'T',
      'cid': channelId,
      'node': node,
      'state': state,
      'ts': ts.millisecondsSinceEpoch,
    }),
  );

  /// Decodes an inbound envelope payload.
  Result<WireEnvelope> decode(List<int> bytes) {
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map<String, Object?>) {
        return const Err(
          SerializationFailure(
            source: 'WireCodec',
            message: 'envelope is not a JSON object',
          ),
        );
      }
      final kind = decoded['kind'];
      switch (kind) {
        case 'M':
          return Ok(_decodeMessage(decoded));
        case 'R':
          final cursor = decoded['cursor'];
          Map<String, Object?>? cursorMap;
          if (cursor is Map<String, Object?>) {
            cursorMap = cursor;
          }
          return Ok(
            WireReceiptEnvelope(
              messageId: _string(decoded, 'mid'),
              node: _string(decoded, 'node'),
              at: DateTime.fromMillisecondsSinceEpoch(_int(decoded, 'at')),
              isRead: decoded['read'] == true,
              device: decoded['device'] as String?,
              version: _intOr(decoded, 'ver', 1),
              channelId: decoded['cid'] as String?,
              cursorMessageId: cursorMap?['mid']?.toString(),
              cursorSequence: (cursorMap?['seq'] as num?)?.toInt(),
              cursorTimestamp: cursorMap?['ts'] == null
                  ? null
                  : DateTime.fromMillisecondsSinceEpoch(
                      (cursorMap!['ts'] as num).toInt(),
                    ),
            ),
          );
        case 'T':
          return Ok(
            WireTypingEnvelope(
              channelId: _string(decoded, 'cid'),
              node: _string(decoded, 'node'),
              state: _string(decoded, 'state'),
              ts: DateTime.fromMillisecondsSinceEpoch(_int(decoded, 'ts')),
            ),
          );
        default:
          return const Err(
            SerializationFailure(
              source: 'wireCodec',
              message: 'unknown envelope kind',
            ),
          );
      }
    } on Object catch (error) {
      return Err(SerializationFailure(source: 'wireCodec', message: '$error'));
    }
  }

  WireMessageResult _decodeMessage(Map<String, Object?> map) {
    final type =
        MessageType.fromWireName(_string(map, 'type')) ?? MessageType.text;
    final priority =
        MessagePriority.values
            .where((p) => p.wireName == map['prio'])
            .firstOrNull ??
        MessagePriority.normal;
    return WireMessageResult(
      WireMessageEnvelope(
        v: _int(map, 'v'),
        messageId: _string(map, 'mid'),
        channelId: _string(map, 'cid'),
        sender: _string(map, 'sender'),
        receiver: map['receiver'] as String?,
        type: type,
        body: map['body']?.toString() ?? '',
        sequence: _int(map, 'seq'),
        timestamp: DateTime.fromMillisecondsSinceEpoch(_int(map, 'ts')),
        replyTo: map['replyTo'] as String?,
        edited: map['edited'] == true,
        forwarded: map['forwarded'] == true,
        priority: priority,
        version: _intOr(map, 'ver', 1),
        ttlSeconds: _intOr(map, 'ttl') == 0 ? null : _intOr(map, 'ttl'),
      ),
    );
  }

  String _string(Map<String, Object?> map, String key) =>
      map[key]?.toString() ?? '';
  int _int(Map<String, Object?> map, String key) =>
      (map[key] as num?)?.toInt() ?? 0;
  int _intOr(Map<String, Object?> map, String key, [int fallback = 0]) =>
      (map[key] as num?)?.toInt() ?? fallback;
}

/// A wire payload that could not be decoded is a dropped packet (never a
/// crash): the inbound pump logs it and moves on.
const SerializationFailure wireDecodeFailure = SerializationFailure(
  source: 'wireCodec',
  message: 'undecodable payload',
);
