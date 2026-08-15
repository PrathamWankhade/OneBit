import 'package:flutter/foundation.dart';

/// A per-channel composing draft.
@immutable
final class Draft {
  const Draft({
    required this.channelId,
    required this.body,
    this.editingMessageId,
    this.createdAt,
    this.updatedAt,
  });

  final String channelId;

  /// The draft body (supports long messages up to the payload budget).
  final String body;

  /// When non-null, this draft edits that message in place.
  final String? editingMessageId;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isEmpty => body.trim().isEmpty;

  Draft copyWith({
    String? body,
    String? editingMessageId,
    DateTime? updatedAt,
  }) => Draft(
    channelId: channelId,
    body: body ?? this.body,
    editingMessageId: editingMessageId ?? this.editingMessageId,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  @override
  bool operator ==(Object other) =>
      other is Draft && other.channelId == channelId;

  @override
  int get hashCode => channelId.hashCode;
}
