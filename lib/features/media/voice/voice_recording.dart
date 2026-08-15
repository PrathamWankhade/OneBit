import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'waveform.dart';

/// A stored voice note.
@immutable
final class VoiceRecording {
  const VoiceRecording({
    required this.voiceNoteId,
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
    required this.durationMs,
    required this.waveform,
    required this.createdAt,
    this.messageId,
    this.sampleRate,
    this.localPath,
  });

  final String voiceNoteId;
  final String? messageId;
  final String fileName;
  final String mimeType;
  final int sizeBytes;
  final int durationMs;
  final int? sampleRate;
  final WaveformData waveform;
  final String? localPath;
  final DateTime createdAt;

  /// JSON form of the waveform (stored in `waveformJson`).
  String get waveformJson => jsonEncode(waveform.toJson());

  static WaveformData? waveformFromJson(String? json) {
    if (json == null) return null;
    try {
      final decoded = jsonDecode(json);
      if (decoded is List<Object?>) return WaveformData.fromJson(decoded);
    } on Object {
      return null;
    }
    return null;
  }

  VoiceRecording copyWith({
    String? messageId,
    String? fileName,
    String? mimeType,
    int? sizeBytes,
    int? durationMs,
    int? sampleRate,
    WaveformData? waveform,
    String? localPath,
  }) => VoiceRecording(
    voiceNoteId: voiceNoteId,
    messageId: messageId ?? this.messageId,
    fileName: fileName ?? this.fileName,
    mimeType: mimeType ?? this.mimeType,
    sizeBytes: sizeBytes ?? this.sizeBytes,
    durationMs: durationMs ?? this.durationMs,
    sampleRate: sampleRate ?? this.sampleRate,
    waveform: waveform ?? this.waveform,
    localPath: localPath ?? this.localPath,
    createdAt: createdAt,
  );

  @override
  bool operator ==(Object other) =>
      other is VoiceRecording && other.voiceNoteId == voiceNoteId;

  @override
  int get hashCode => voiceNoteId.hashCode;

  @override
  String toString() =>
      'VoiceRecording($voiceNoteId '
      '$durationMs ms, ${waveform.bucketCount} buckets)';
}
