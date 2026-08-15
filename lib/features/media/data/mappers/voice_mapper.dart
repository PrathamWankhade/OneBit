import 'package:drift/drift.dart';
import 'package:onebit/core/database/database.dart';
import 'package:onebit/features/media/voice/voice_recording.dart';
import 'package:onebit/features/media/voice/waveform.dart';

/// Row ↔ domain mapping for voice recordings.
abstract final class VoiceMapper {
  const VoiceMapper._();

  static VoiceRecording fromRow(VoiceRecordingRow row) => VoiceRecording(
    voiceNoteId: row.voiceNoteId,
    messageId: row.messageId,
    fileName: row.fileName,
    mimeType: row.mimeType,
    sizeBytes: row.sizeBytes,
    durationMs: row.durationMs,
    sampleRate: row.sampleRate,
    waveform:
        VoiceRecording.waveformFromJson(row.waveformJson) ??
        WaveformData.fromSamples(const <double>[]),
    localPath: row.localPath,
    createdAt: row.createdAt,
  );

  static VoiceRecordingsCompanion toRow(VoiceRecording recording) =>
      VoiceRecordingsCompanion(
        voiceNoteId: Value(recording.voiceNoteId),
        messageId: Value(recording.messageId),
        fileName: Value(recording.fileName),
        mimeType: Value(recording.mimeType),
        sizeBytes: Value(recording.sizeBytes),
        durationMs: Value(recording.durationMs),
        sampleRate: Value(recording.sampleRate),
        waveformJson: Value(recording.waveformJson),
        localPath: Value(recording.localPath),
        createdAt: Value(recording.createdAt),
      );
}
