/// I9.3 — Message bubble for outbound messages.
///
/// Displays a single outbound message with content, timestamp,
/// and delivery state.
library;

import 'package:flutter/material.dart';
import 'package:onebit/core/theme/app_theme.dart';
import 'package:onebit/features/message/models/message_state.dart';

/// A chat bubble for an outbound message.
///
/// Always right-aligned (sent by local user). Shows content,
/// creation time, and current delivery state.
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.content,
    required this.createdAt,
    required this.state,
  });

  /// The message text content.
  final String content;

  /// When the message was created.
  final DateTime createdAt;

  /// The current delivery state.
  final MessageState state;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: const BoxDecoration(
          color: AppTheme.accentMuted,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(12),
            topRight: Radius.circular(12),
            bottomLeft: Radius.circular(12),
            bottomRight: Radius.circular(4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              content,
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(createdAt),
                  style: AppTheme.caption.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(width: 4),
                _StateLabel(state: state),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

/// Small label showing the delivery state.
class _StateLabel extends StatelessWidget {
  const _StateLabel({required this.state});

  final MessageState state;

  @override
  Widget build(BuildContext context) {
    final (label, color) = _stateInfo();

    return Text(
      label,
      style: AppTheme.caption.copyWith(
        color: color.withValues(alpha: 0.8),
        fontWeight: FontWeight.w500,
      ),
    );
  }

  (String, Color) _stateInfo() {
    return switch (state) {
      MessageState.created => ('Created', AppTheme.textSecondary),
      MessageState.queued => ('Queued', AppTheme.textSecondary),
      MessageState.routeLookup => ('Preparing', AppTheme.blue),
      MessageState.ready => ('Ready', AppTheme.blue),
      MessageState.transmitting => ('Sending\u2026', AppTheme.blue),
      MessageState.relaying => ('Relaying', AppTheme.blue),
      MessageState.delivered => ('Sent', AppTheme.accent),
      MessageState.noRoute => ('No route', AppTheme.red),
      MessageState.failed => ('Failed', AppTheme.red),
      MessageState.expired => ('Expired', AppTheme.red),
      MessageState.rejected => ('Rejected', AppTheme.red),
    };
  }
}
