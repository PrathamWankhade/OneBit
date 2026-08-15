import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/core/extensions/build_context_extensions.dart';
import 'package:onebit/features/media/voice/voice_recorder.dart';
import 'package:onebit/features/media/voice/voice_recording.dart';
import 'package:onebit/features/media/voice/waveform.dart';
import 'package:onebit/shared/design_system/components/onebit_button.dart';
import 'package:onebit/shared/design_system/icons/onebit_icons.dart';
import 'package:onebit/shared/design_system/spacing/onebit_radius.dart';
import 'package:onebit/shared/design_system/spacing/onebit_spacing.dart';

/// The recorder seam for the composer. Production platforms inject their
/// native implementation; this default reports `unsupported` so the UI can
/// degrade gracefully. Tests override this provider with a fake recorder.
final recorderProvider = Provider<VoiceRecorder>(
  (ref) => UnsupportedVoiceRecorder(),
);

/// Placeholder recorder used until a native capture implementation lands.
final class UnsupportedVoiceRecorder implements VoiceRecorder {
  @override
  Stream<double> get amplitudeSamples => const Stream<double>.empty();

  @override
  bool get isRecording => false;

  @override
  Future<void> cancel() async {}

  @override
  Future<bool> ensurePermission() async => false;

  @override
  Future<ResultStartRecording> start(VoiceRecorderConfig config) async =>
      const ResultStartRecording(error: 'unsupported');

  @override
  Future<StoppedRecording> stop() async =>
      throw StateError('recorder is unsupported on this platform');
}

/// Opens the voice note recorder sheet and returns the recorded note, or
/// `null` when discarded / cancelled.
Future<VoiceRecording?> showVoiceRecorderSheet(BuildContext context) {
  return showModalBottomSheet<VoiceRecording>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => const _VoiceRecorderSheet(),
  );
}

final class _VoiceRecorderSheet extends ConsumerStatefulWidget {
  const _VoiceRecorderSheet();

  @override
  ConsumerState<_VoiceRecorderSheet> createState() =>
      _VoiceRecorderSheetState();
}

enum _RecordPhase {
  permission,
  idle,
  recording,
  stopping,
  reviewing,
  unavailable,
}

final class _VoiceRecorderSheetState
    extends ConsumerState<_VoiceRecorderSheet> {
  final List<double> _amplitudes = [];
  StreamSubscription<double>? _amplitudesSub;
  Timer? _ticker;
  DateTime? _startedAt;
  _RecordPhase _phase = _RecordPhase.permission;
  VoiceRecording? _recording;
  Duration _elapsed = Duration.zero;

  VoiceRecorder get _recorder => ref.read(recorderProvider);

  @override
  void dispose() {
    _amplitudesSub?.cancel();
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _requestPermission() async {
    final granted = await _recorder.ensurePermission();
    if (!mounted) return;
    if (granted) {
      setState(() => _phase = _RecordPhase.idle);
    } else {
      setState(() => _phase = _RecordPhase.unavailable);
    }
  }

  Future<void> _start() async {
    final result = await _recorder.start(const VoiceRecorderConfig());
    if (!mounted) return;
    if (!result.isOk) {
      setState(() => _phase = _RecordPhase.unavailable);
      return;
    }
    setState(() {
      _phase = _RecordPhase.recording;
      _startedAt = DateTime.now();
      _amplitudes.clear();
    });
    _amplitudesSub = _recorder.amplitudeSamples.listen((sample) {
      if (mounted && _phase == _RecordPhase.recording) {
        if (_amplitudes.length >= WaveformData.maxBuckets) return;
        setState(() => _amplitudes.add(sample.clamp(0.0, 1.0)));
      }
    });
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted) return;
      setState(
        () =>
            _elapsed = DateTime.now().difference(_startedAt ?? DateTime.now()),
      );
    });
  }

  Future<void> _stop() async {
    _ticker?.cancel();
    setState(() => _phase = _RecordPhase.stopping);
    try {
      final stopped = await _recorder.stop();
      final waveform = WaveformData.fromSamples(_amplitudes, bucketCount: 64);
      final note = stopped.recording.copyWith(
        waveform: waveform,
        durationMs: stopped.durationMs ?? stopped.recording.durationMs,
      );
      if (!mounted) return;
      setState(() {
        _recording = note;
        _phase = _RecordPhase.reviewing;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _phase = _RecordPhase.unavailable);
    } finally {
      await _amplitudesSub?.cancel();
      _amplitudesSub = null;
    }
  }

  Future<void> _discard() async {
    _ticker?.cancel();
    await _recorder.cancel();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          OneBitSpacing.m,
          OneBitSpacing.xs,
          OneBitSpacing.m,
          OneBitSpacing.m,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.composeVoiceRecordingTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: OneBitSpacing.m),
            switch (_phase) {
              _RecordPhase.permission => Column(
                children: [
                  Icon(OneBitIcons.mic, size: 48, color: scheme.primary),
                  const SizedBox(height: OneBitSpacing.m),
                  Text(
                    l10n.composeVoiceUnavailable,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: OneBitSpacing.m),
                  OneBitButton(
                    label: l10n.composeVoiceRecordStart,
                    icon: OneBitIcons.mic,
                    onPressed: _requestPermission,
                  ),
                ],
              ),
              _RecordPhase.unavailable => Column(
                children: [
                  Icon(OneBitIcons.mic, size: 48, color: scheme.error),
                  const SizedBox(height: OneBitSpacing.m),
                  Text(
                    l10n.composeVoiceUnavailable,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
              _RecordPhase.idle => OneBitButton(
                label: l10n.composeVoiceRecordingHint,
                icon: OneBitIcons.mic,
                onPressed: _start,
              ),
              _RecordPhase.recording => _RecordingView(
                elapsed: _elapsed,
                amplitudes: _amplitudes,
                onStop: _stop,
              ),
              _RecordPhase.stopping => const Padding(
                padding: EdgeInsets.all(OneBitSpacing.m),
                child: CircularProgressIndicator(),
              ),
              _RecordPhase.reviewing => _ReviewView(
                recording: _recording!,
                onAttach: () => Navigator.of(context).pop(_recording),
                onDiscard: _discard,
              ),
            },
          ],
        ),
      ),
    );
  }
}

final class _RecordingView extends StatelessWidget {
  const _RecordingView({
    required this.elapsed,
    required this.amplitudes,
    required this.onStop,
  });

  final Duration elapsed;
  final List<double> amplitudes;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(OneBitIcons.mic, size: 20, color: scheme.error),
            const SizedBox(width: OneBitSpacing.s),
            Text(
              _formatDuration(elapsed),
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        ),
        const SizedBox(height: OneBitSpacing.m),
        _WaveformBars(amplitudes: amplitudes, height: 48),
        const SizedBox(height: OneBitSpacing.m),
        OneBitButton(
          label: context.l10n.composeVoiceRecordStop,
          icon: OneBitIcons.stop,
          onPressed: onStop,
        ),
      ],
    );
  }

  static String _formatDuration(Duration d) {
    final minutes = d.inMinutes.toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

final class _ReviewView extends StatelessWidget {
  const _ReviewView({
    required this.recording,
    required this.onAttach,
    required this.onDiscard,
  });

  final VoiceRecording recording;
  final VoidCallback onAttach;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _WaveformBars(amplitudes: recording.waveform.buckets, height: 56),
        const SizedBox(height: OneBitSpacing.s),
        Text(
          '${recording.durationMs ~/ 1000} s',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: OneBitSpacing.m),
        Row(
          children: [
            Expanded(
              child: OneBitButton(
                label: l10n.composeVoiceRecordDiscard,
                variant: OneBitButtonVariant.secondary,
                icon: OneBitIcons.delete,
                onPressed: onDiscard,
              ),
            ),
            const SizedBox(width: OneBitSpacing.m),
            Expanded(
              child: OneBitButton(
                label: l10n.commonSend,
                icon: OneBitIcons.check,
                onPressed: onAttach,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Live/review waveform bars (presentation-only rendering).
final class _WaveformBars extends StatelessWidget {
  const _WaveformBars({required this.amplitudes, required this.height});

  final List<double> amplitudes;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final values = amplitudes.isEmpty ? const <double>[0.05] : amplitudes;
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (final value in values)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: Container(
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(OneBitRadius.xs),
                  ),
                  margin: EdgeInsets.symmetric(
                    vertical: height * (1 - value.clamp(0.05, 1.0)) / 2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
