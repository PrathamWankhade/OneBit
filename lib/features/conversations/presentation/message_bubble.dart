import 'package:flutter/material.dart';
import 'package:onebit/core/theme/app_theme.dart';

/// F4 Message Bubble — incoming and outgoing variants with smooth animation.
///
/// Incoming: `bg-elevated` background, left-aligned.
/// Outgoing: `accent-subtle` background, right-aligned.
/// Both show timestamp and delivery status.
/// Animated entry: slide up + fade in for emotional touch.
class MessageBubble extends StatefulWidget {
  const MessageBubble({
    required this.content,
    required this.timestamp,
    required this.isReceived,
    this.status = 'sent',
    this.animate = false,
    super.key,
  });

  final String content;
  final DateTime timestamp;
  final bool isReceived;
  final String status;
  final bool animate;

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 300),
      );
      _fadeAnimation = CurvedAnimation(
        parent: _controller!,
        curve: Curves.easeOut,
      );
      _slideAnimation = Tween<Offset>(
        begin: const Offset(0, 0.3),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _controller!,
        curve: Curves.easeOutCubic,
      ));
      _controller!.forward();
    } else {
      _fadeAnimation = const AlwaysStoppedAnimation(1.0);
      _slideAnimation = const AlwaysStoppedAnimation(Offset.zero);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Align(
          alignment: widget.isReceived ? Alignment.centerLeft : Alignment.centerRight,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.75,
            ),
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Column(
              crossAxisAlignment:
                  widget.isReceived ? CrossAxisAlignment.start : CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: widget.isReceived ? AppTheme.bgElevated : AppTheme.accentMuted,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(12),
                      topRight: const Radius.circular(12),
                      bottomLeft: Radius.circular(widget.isReceived ? 4 : 12),
                      bottomRight: Radius.circular(widget.isReceived ? 12 : 4),
                    ),
                  ),
                  child: Text(
                    widget.content,
                    style: AppTheme.bodyLarge.copyWith(
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(widget.timestamp),
                        style: AppTheme.caption.copyWith(
                          color: AppTheme.textTertiary,
                        ),
                      ),
                      if (!widget.isReceived) ...[
                        const SizedBox(width: 4),
                        _StatusIcon(status: widget.status),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
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

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case 'sending':
        return const SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: AppTheme.textTertiary,
          ),
        );
      case 'sent':
        return const Icon(Icons.done, size: 12, color: AppTheme.textTertiary);
      case 'delivered':
        return const Icon(Icons.done_all, size: 12, color: AppTheme.textTertiary);
      case 'read':
        return const Icon(Icons.done_all, size: 12, color: AppTheme.accent);
      case 'failed':
        return const Icon(Icons.error_outline, size: 12, color: AppTheme.red);
      default:
        return const SizedBox.shrink();
    }
  }
}

/// Date divider between message groups.
class DateDivider extends StatelessWidget {
  const DateDivider({required this.date, super.key});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
      child: Row(
        children: [
          const Expanded(child: Divider(color: AppTheme.divider)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              _formatDate(date),
              style: AppTheme.caption.copyWith(color: AppTheme.textTertiary),
            ),
          ),
          const Expanded(child: Divider(color: AppTheme.divider)),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(dt.year, dt.month, dt.day);

    if (dateOnly == today) return 'Today';
    final yesterday = today.subtract(const Duration(days: 1));
    if (dateOnly == yesterday) return 'Yesterday';

    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${months[dt.month - 1]} ${dt.day}';
  }
}

/// Unread messages divider.
class UnreadDivider extends StatelessWidget {
  const UnreadDivider({required this.count, super.key});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 32),
      child: Row(
        children: [
          const Expanded(
            child: Divider(color: AppTheme.accent, height: 1),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              '$count new message${count == 1 ? '' : 's'}',
              style: AppTheme.caption.copyWith(color: AppTheme.accent),
            ),
          ),
          const Expanded(
            child: Divider(color: AppTheme.accent, height: 1),
          ),
        ],
      ),
    );
  }
}
