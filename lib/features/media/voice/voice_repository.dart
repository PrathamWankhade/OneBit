import 'package:onebit/core/result/result.dart';

import 'voice_recording.dart';

/// Contract for voice-note persistence.
abstract interface class VoiceRepository {
  Future<Result<VoiceRecording>> save(VoiceRecording recording);

  Future<Result<VoiceRecording?>> get(String voiceNoteId);

  Future<Result<List<VoiceRecording>>> listByMessage(String messageId);

  Future<Result<void>> delete(String voiceNoteId);

  Future<Result<void>> updatePath(String voiceNoteId, String path);

  Stream<Result<VoiceRecording?>> watch(String voiceNoteId);
}
