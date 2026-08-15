import 'package:flutter/foundation.dart';

/// Live typing indicator of one node in one channel.
@immutable
final class TypingState {
  const TypingState({
    required this.node,
    required this.channelId,
    required this.state,
    required this.since,
  });

  /// Who is typing.
  final String node;

  final String channelId;

  /// started → stopped (user action), or → timeout → idle (clock).
  final TypingPhase state;

  /// When the phase began.
  final DateTime since;

  bool get isTyping => state == TypingPhase.started;

  TypingState copyWith({TypingPhase? state, DateTime? since}) => TypingState(
    node: node,
    channelId: channelId,
    state: state ?? this.state,
    since: since ?? this.since,
  );

  @override
  bool operator ==(Object other) =>
      other is TypingState &&
      other.node == node &&
      other.channelId == channelId &&
      other.state == state;

  @override
  int get hashCode => Object.hash(node, channelId, state);
}

/// Phase of a typing indicator.
enum TypingPhase {
  /// User started typing.
  started,

  /// User stopped (sent or abandoned).
  stopped,

  /// No activity for the timeout window.
  timeout,

  /// Fully idle (after timeout), removed from the bus.
  idle;

  String get wireName => name;
}

/// Typing bus entry with a heartbeat deadline (internal to the engine).
final class TypingPresence {
  const TypingPresence({required this.state, required this.expiresAt});

  final TypingState state;
  final DateTime expiresAt;
}
