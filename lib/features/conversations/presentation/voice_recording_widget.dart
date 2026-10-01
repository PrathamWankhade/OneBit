import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:onebit/core/theme/app_theme.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// WhatsApp-style voice recording UI, backed by a real microphone.
///
/// Bars track the live amplitude stream; the timer tracks the
/// recorder, not a guess. Recording stops itself at [maxDuration —
/// anything longer would not fit the transport — and the finished
/// file goes out through [onSend]. When the microphone is unavailable
/// the widget says so instead of performing a recording.
class VoiceRecordingWidget extends StatefulWidget {
  const VoiceRecordingWidget({
    required this.onCancel,
    required this.onSend,
    super.key,
  });

  final VoidCallback onCancel;

  /// The finished recording and how long it runs.
  final void Function(File file, Duration duration) onSend;

  /// Longest note we will send: past this the slices outnumber
  /// patience and the radio. Recording stops itself here.
  static const Duration maxDuration = Duration(seconds: 60);

  @override
  State<VoiceRecordingWidget> createState() => _VoiceRecordingWidgetState();
}

class _VoiceRecordingWidgetState extends State<VoiceRecordingWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Timer? _timer;
  StreamSubscription<Amplitude>? _amplitudeSub;
  final AudioRecorder _recorder = AudioRecorder();

  Duration _elapsed = Duration.zero;
  bool _isPaused = false;
  bool _isCancelled = false;
  bool _sending = false;

  /// Microphone refused or recorder failed: an explanation, not a show.
  String? _error;

  /// Last twenty live levels, oldest first. Flat until the first
  /// amplitude event — silence drawn as silence.
  final List<double> _levels = List.filled(20, 0.05);

  double _slideOffset = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    )..repeat();
    _begin();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _amplitudeSub?.cancel();
    _controller.dispose();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _begin() async {
    final permitted = await _recorder.hasPermission();
    if (!permitted) {
      if (mounted) {
        setState(() => _error = 'Microphone unavailable — nothing recorded.');
      }
      return;
    }

    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    try {
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 32000,
          sampleRate: 22050,
          numChannels: 1,
        ),
        path: path,
      );
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not start recording.');
      }
      return;
    }

    _timer = Timer.periodic(const Duration(seconds: 1), _onTick);
    _amplitudeSub = _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 200))
        .listen(_onAmplitude);
  }

  void _onTick(Timer timer) {
    if (_isPaused || !mounted) return;
    setState(() => _elapsed += const Duration(seconds: 1));
    if (_elapsed >= VoiceRecordingWidget.maxDuration) _send();
  }

  void _onAmplitude(Amplitude amplitude) {
    if (_isPaused || !mounted) return;
    // dBFS below −60 is room tone; 0 is full scale.
    final level = ((amplitude.current + 60) / 60).clamp(0.0, 1.0);
    setState(() {
      _levels.removeAt(0);
      _levels.add(0.05 + 0.95 * level);
    });
  }

  void _togglePause() {
    if (_error != null) return;
    setState(() => _isPaused = !_isPaused);
    if (_isPaused) {
      _recorder.pause();
    } else {
      _recorder.resume();
    }
  }

  void _cancel() {
    setState(() => _isCancelled = true);
    _recorder.cancel().ignore();
    widget.onCancel();
  }

  Future<void> _send() async {
    if (_sending || _error != null) return;
    setState(() => _sending = true);
    _timer?.cancel();
    await _amplitudeSub?.cancel();

    final path = await _recorder.stop();
    if (path == null) {
      if (mounted) setState(() => _error = 'Recording was empty.');
      return;
    }
    widget.onSend(File(path), _elapsed);
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    if (_isCancelled) return const SizedBox.shrink();

    if (_error != null) {
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
            GestureDetector(
              onTap: _cancel,
              child: Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: AppTheme.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delete_outline,
                  size: 22,
                  color: AppTheme.brightWhite,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(_error!, style: AppTheme.bodyMedium),
            ),
          ],
        ),
      );
    }

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
                          data: _levels,
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
