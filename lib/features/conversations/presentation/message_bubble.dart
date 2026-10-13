import 'package:flutter/material.dart';
import 'package:onebit/core/theme/app_theme.dart';
import 'package:onebit/features/protocol/delivery_state.dart';

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
    this.deliveryState,
    this.replyQuote,
    this.animate = false,
    this.encrypted = false,
    super.key,
  });

  final String content;
  final DateTime timestamp;
  final bool isReceived;

  /// The raw row status. Only consulted when [deliveryState] is not
  /// handed in — the screen computes the contract's answer once per
  /// row and passes it down.
  final String status;

  /// What this message's facts add up to (I9.14.a) — the thread's
  /// single delivery vocabulary, derived from the row plus the
  /// transport's in-memory attempt bookkeeping.
  final DeliveryState? deliveryState;

  /// Whether the bytes traveled encrypted. Read from the row, never
  /// promised: a bubble without the lock makes no claim.
  final bool encrypted;

  /// The message this one answers, as the sender quoted it.
  ///
  /// A null quote is an ordinary message; it is carried alongside
  /// `content` rather than inside it so the body stays selectable text.
  final String? replyQuote;

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
    // I9.14.a — one answer per row: whatever the screen could not
    // know (attempts in flight, the retry schedule) falls back to the
    // durable status alone.
    final state = widget.deliveryState ??
        deliveryStateOf(
          status: widget.status,
          transmitting: false,
          retryAttempts: 0,
        );
    final label = widget.isReceived ? null : deliveryLabelOf(state);

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
                if (widget.replyQuote != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.bgBase,
                      borderRadius: BorderRadius.circular(6),
                      border: const Border(
                        left: BorderSide(color: AppTheme.accent, width: 3),
                      ),
                    ),
                    child: Text(
                      widget.replyQuote!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.caption.copyWith(
                        color: AppTheme.textTertiary,
                      ),
                    ),
                  ),
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
                      if (widget.encrypted) ...[
                        const Icon(
                          Icons.lock_outline,
                          size: 10,
                          color: AppTheme.trust,
                        ),
                        const SizedBox(width: 3),
                      ],
                      Text(
                        _formatTime(widget.timestamp),
                        style: AppTheme.caption.copyWith(
                          color: AppTheme.textTertiary,
                        ),
                      ),
                      if (!widget.isReceived) ...[
                        const SizedBox(width: 4),
                        DeliveryStatusIcon(state),
                      ],
                    ],
                  ),
                ),
                // I9.14.a — states the icon cannot carry alone say so
                // in words, from the same contract that chose the
                // icon. Failures and expiry wear the red the problem
                // deserves; the rest stay quiet.
                if (label != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      label,
                      style: AppTheme.caption.copyWith(
                        color: state == DeliveryState.expired ||
                                state == DeliveryState.failed
                            ? AppTheme.red
                            : AppTheme.textTertiary,
                      ),
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

/// The icon the delivery contract picks for [state] (I9.14.a) — the
/// same mark every outgoing row wears, whether its body is text, a
/// file, or a voice note. A renderer never chooses an icon from a raw
/// status string again; the string became words once, in
/// [deliveryStateOf], and this is the picture of the answer.
class DeliveryStatusIcon extends StatelessWidget {
  const DeliveryStatusIcon(this.state, {super.key});

  final DeliveryState state;

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case DeliveryState.transmitting:
        return const SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: AppTheme.textTertiary,
          ),
        );
      case DeliveryState.queued:
        return const Icon(Icons.schedule, size: 12, color: AppTheme.textTertiary);
      case DeliveryState.retrying:
        return const Icon(Icons.sync_problem, size: 12, color: AppTheme.textTertiary);
      case DeliveryState.relayed:
        return const Icon(Icons.done, size: 12, color: AppTheme.textTertiary);
      case DeliveryState.delivered:
        return const Icon(Icons.done_all, size: 12, color: AppTheme.textTertiary);
      case DeliveryState.read:
        return const Icon(Icons.done_all, size: 12, color: AppTheme.accent);
      case DeliveryState.expired:
        return const Icon(Icons.timer_off, size: 12, color: AppTheme.red);
      case DeliveryState.failed:
        return const Icon(Icons.error_outline, size: 12, color: AppTheme.red);
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
