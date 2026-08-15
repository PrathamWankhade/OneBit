import 'voice_recorder.dart';

/// Playback seam re-export — see [VoicePlayer].
///
/// The player contract in Phase 9 is the interface only (native
/// implementations land with the audio engine); keeping the file separate
/// mirrors the recorder split so imports stay small.
export 'voice_recorder.dart' show VoicePlayer;
