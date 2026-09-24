import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:onebit/core/theme/app_theme.dart';

/// WhatsApp-style voice recording UI.
///
/// Shows waveform, timer, slide-to-cancel, pause/resume, delete, send.
class VoiceRecordingWidget extends StatefulWidget {
  const VoiceRecordingWidget({
    required this.onCancel,
    required this.onSend,
    super.key,
  });

  final VoidCallback onCancel;
  final ValueChanged<Duration> onSend;

  @override
  State<VoiceRecordingWidget> createState() => _VoiceRecordingWidgetState();
}

class _VoiceRecordingWidgetState extends State<VoiceRecordingWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Timer _timer;
  Duration _elapsed = Duration.zero;
  bool _isPaused = false;
  bool _isCancelled = false;
  late List<double> _waveformData;
  double _slideOffset = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    )..repeat();
    _timer = Timer.periodic(const Duration(seconds: 1), _onTick);
    _waveformData = _generateWaveform();
  }

  @override
  void dispose() {
    _timer.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onTick(Timer timer) {
    if (!_isPaused && mounted) {
      setState(() {
        _elapsed += const Duration(seconds: 1);
        _waveformData = _generateWaveform();
      });
    }
  }

  List<double> _generateWaveform() {
    final random = Random(_elapsed.inSeconds);
    return List.generate(20, (_) => 0.2 + random.nextDouble() * 0.8);
  }

  void _togglePause() {
    setState(() => _isPaused = !_isPaused);
  }

  void _cancel() {
    setState(() => _isCancelled = true);
    widget.onCancel();
  }

  void _send() {
    widget.onSend(_elapsed);
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    if (_isCancelled) return const SizedBox.shrink();

    return Container(
      height: 80,
      padding: EdgeInsets.only(
        left: 8,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.bgBase,
        border: Border(
          top: BorderSide(color: AppTheme.divider, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // Delete button
          GestureDetector(
            onTap: _cancel,
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: AppTheme.red,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_outline, size: 22, color: AppTheme.brightWhite),
            ),
          ),
          const SizedBox(width: 8),

          // Waveform + timer area
          Expanded(
            child: GestureDetector(
              onHorizontalDragUpdate: (details) {
                setState(() {
                  _slideOffset += details.delta.dx;
                  if (_slideOffset < -80) {
                    _cancel();
                  }
                });
              },
              onHorizontalDragEnd: (_) {
                setState(() => _slideOffset = 0);
              },
              child: Transform.translate(
                offset: Offset(_slideOffset * 0.5, 0),
                child: Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.bgElevated,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Row(
                    children: [
                      // Timer
                      SizedBox(
                        width: 50,
                        child: Text(
                          _formatDuration(_elapsed),
                          style: AppTheme.technical.copyWith(
                            color: AppTheme.accent,
                            fontSize: 14,
                          ),
                        ),
                      ),

                      // Waveform
                      Expanded(
                        child: _LiveWaveform(
                          data: _waveformData,
                          controller: _controller,
                        ),
                      ),

                      // Slide to cancel hint
                      if (_slideOffset < -20)
                        Text(
                          'Slide to cancel',
                          style: AppTheme.caption.copyWith(
                            color: AppTheme.textTertiary,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Pause/Resume button
          GestureDetector(
            onTap: _togglePause,
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: AppTheme.bgElevated,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isPaused ? Icons.play_arrow : Icons.pause,
                size: 24,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Send button
          GestureDetector(
            onTap: _send,
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: AppTheme.accent,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send, size: 20, color: AppTheme.bgBase),
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveWaveform extends StatelessWidget {
  const _LiveWaveform({
    required this.data,
    required this.controller,
  });

  final List<double> data;
  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return RepaintBoundary(
          child: SizedBox(
            height: 24,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(data.length, (i) {
                final height = data[i] * 24 * (0.8 + 0.2 * sin(controller.value * 2 * pi + i * 0.5));
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: Container(
                      height: max(2, height),
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        );
      },
    );
  }
}
