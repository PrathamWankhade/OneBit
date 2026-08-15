import 'package:drift/drift.dart';
import 'package:onebit/core/database/dao/media_dao.dart';
import 'package:onebit/core/database/repository/result_guards.dart';
import 'package:onebit/core/logger/app_logger.dart';
import 'package:onebit/core/result/result.dart';
import 'package:onebit/features/media/data/mappers/voice_mapper.dart';
import 'package:onebit/features/media/voice/voice_recording.dart';
import 'package:onebit/features/media/voice/voice_repository.dart';

/// Drift-backed [VoiceRepository] over [MediaDao].
final class SqliteVoiceRepository implements VoiceRepository {
  SqliteVoiceRepository({required this.dao, required this.logger});

  final MediaDao dao;
  final AppLogger logger;

  @override
  Future<Result<VoiceRecording>> save(VoiceRecording recording) =>
      ResultGuards.guard(logger, 'voice.save', () async {
        final row = await dao.voiceRecordingRow(recording.voiceNoteId);
        if (row == null) {
          await dao.insertVoiceRecording(VoiceMapper.toRow(recording));
        } else {
          await dao.updateVoiceRecording(
            row
                .toCompanion(true)
                .copyWith(
                  sizeBytes: Value(recording.sizeBytes),
                  durationMs: Value(recording.durationMs),
                  sampleRate: Value(recording.sampleRate),
                  waveformJson: Value(recording.waveformJson),
                  localPath: Value(recording.localPath),
                ),
          );
        }
        return recording;
      });

  @override
  Future<Result<VoiceRecording?>> get(String voiceNoteId) =>
      ResultGuards.guard(logger, 'voice.get', () async {
        final row = await dao.voiceRecordingRow(voiceNoteId);
        return row == null ? null : VoiceMapper.fromRow(row);
      });

  @override
  Future<Result<List<VoiceRecording>>> listByMessage(String messageId) =>
      ResultGuards.guard(logger, 'voice.listByMessage', () async {
        final rows = await dao.voiceRecordingsForMessage(messageId);
        return rows.map(VoiceMapper.fromRow).toList();
      });

  @override
  Future<Result<void>> delete(String voiceNoteId) =>
      ResultGuards.guard(logger, 'voice.delete', () async {
        await dao.deleteVoiceRecording(voiceNoteId);
      });

  @override
  Future<Result<void>> updatePath(String voiceNoteId, String path) =>
      ResultGuards.guard(logger, 'voice.updatePath', () async {
        final row = await dao.voiceRecordingRow(voiceNoteId);
        if (row == null) return;
        await dao.updateVoiceRecording(
          row.toCompanion(true).copyWith(localPath: Value(path)),
        );
      });

  @override
  Stream<Result<VoiceRecording?>> watch(String voiceNoteId) =>
      ResultGuards.guardWatch(
        logger,
        'voice.watch',
        dao
            .watchVoiceRecording(voiceNoteId)
            .map((row) => row == null ? null : VoiceMapper.fromRow(row)),
      );
}
