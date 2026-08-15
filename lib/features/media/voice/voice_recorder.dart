import 'voice_recording.dart';

/// The recorder seam: platform implementations (native audio capture) plug
/// in here; Phase 9 ships the interface + session value only.
///
/// A [VoiceRecorder] never exposes `dart:io` or platform types — the
/// implementation is injected by the app shell.
abstract interface class VoiceRecorder {
  /// Requests recording permissions; returns false when refused.
  Future<bool> ensurePermission();

  /// True when a recording session is currently live.
  bool get isRecording;

  /// Starts a recording session. Returns an error when the platform
  /// cannot record (unsupported, permission, busy).
  Future<ResultStartRecording> start(VoiceRecorderConfig config);

  /// Stops the session and returns the produced artifact.
  Future<StoppedRecording> stop();

  /// Cancels the session and discards partial audio.
  Future<void> cancel();

  /// Peak amplitude samples (0..1), fed by the implementation while
  /// recording — the domain resamples them into a [WaveformData].
  Stream<double> get amplitudeSamples;
}

/// Recording parameters.
final class VoiceRecorderConfig {
  const VoiceRecorderConfig({
    this.sampleRate = 44100,
    this.maxDuration = const Duration(minutes: 15),
    this.mimeType = 'audio/mpeg',
    this.extension = 'm4a',
  });

  final int sampleRate;

  /// Hard cap; exceeding it stops the session automatically.
  final Duration maxDuration;

  final String mimeType;
  final String extension;
}

/// Outcome of [VoiceRecorder.start].
final class ResultStartRecording {
  const ResultStartRecording({this.recording, this.error});

  /// Ready-to-persist recording metadata (path may be null until stop).
  final VoiceRecording? recording;

  /// Machine-readable failure id (`denied`, `busy`, `unsupported`).
  final String? error;

  bool get isOk => recording != null;
}

/// Outcome of [VoiceRecorder.stop].
final class StoppedRecording {
  const StoppedRecording({required this.recording, this.durationMs});

  final VoiceRecording recording;

  /// Actual captured duration (may differ from the metadata default).
  final int? durationMs;
}

/// The playback seam: platform implementations render audio; Phase 9 ships
/// the interface only. Voice notes are stored as ordinary attachments, so
/// playback *could* reuse an attachment player; this contract keeps the
/// voice domain honest.
abstract interface class VoicePlayer {
  Future<bool> play(VoiceRecording recording, {double volume = 1});

  Future<void> pause();

  Future<void> resume();

  Future<void> seek(Duration position);

  Future<void> stop();

  /// `null` when nothing is loaded; position while playing.
  Duration? get position;

  /// `0..1` when playing, else null.
  double? get volume;
}
