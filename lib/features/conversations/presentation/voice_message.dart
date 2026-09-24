import 'dart:math';
import 'package:flutter/material.dart';
import 'package:onebit/core/theme/app_theme.dart';

/// F9 — Voice message bubble.
///
/// 56px height, 240px width, bg-elevated, 8px radius.
/// Play button (32px circle, accent), waveform (120px), duration.
class VoiceMessageBubble extends StatefulWidget {
  const VoiceMessageBubble({
    required this.isReceived,
    required this.duration,
    this.timestamp,
    this.status = 'sent',
    this.isPlaying = false,
    this.progress = 0.0,
    this.onPlayPause,
    super.key,
  });

  final bool isReceived;
  final Duration duration;
  final DateTime? timestamp;
  final String status;
  final bool isPlaying;
  final double progress;
  final VoidCallback? onPlayPause;

  @override
  State<VoiceMessageBubble> createState() => _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends State<VoiceMessageBubble> {
  late List<double> _waveformData;

  @override
  void initState() {
    super.initState();
    _waveformData = _generateWaveform();
  }

  List<double> _generateWaveform() {
    final random = Random(42);
    return List.generate(30, (_) => 0.2 + random.nextDouble() * 0.8);
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: widget.isReceived ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.75,
        ),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          crossAxisAlignment: widget.isReceived
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.end,
          children: [
            // Voice container
            Container(
              width: 240,
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: widget.isReceived
                    ? AppTheme.bgElevated
                    : AppTheme.accentMuted,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(8),
                  topRight: const Radius.circular(8),
                  bottomLeft: Radius.circular(widget.isReceived ? 4 : 8),
                  bottomRight: Radius.circular(widget.isReceived ? 8 : 4),
                ),
              ),
              child: Row(
                children: [
                  // Play/Pause button
                  GestureDetector(
                    onTap: widget.onPlayPause,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: AppTheme.accent,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        widget.isPlaying ? Icons.pause : Icons.play_arrow,
                        size: 18,
                        color: AppTheme.bgBase,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Waveform
                  Expanded(
                    child: _Waveform(
                      data: _waveformData,
                      progress: widget.progress,
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Duration
                  Text(
                    _formatDuration(widget.duration),
                    style: AppTheme.caption.copyWith(
                      color: AppTheme.textTertiary,
                    ),
                  ),
                ],
              ),
            ),

            // Timestamp + status
            if (widget.timestamp != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatTime(widget.timestamp!),
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
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _Waveform extends StatelessWidget {
  const _Waveform({required this.data, required this.progress});

  final List<double> data;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 24,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(data.length, (i) {
          final fraction = i / data.length;
          final isPlayed = fraction <= progress;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: Container(
                height: data[i] * 24,
                decoration: BoxDecoration(
                  color: isPlayed ? AppTheme.accent : AppTheme.textTertiary,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case 'sending':
        return const Icon(Icons.access_time, size: 12, color: AppTheme.textTertiary);
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
