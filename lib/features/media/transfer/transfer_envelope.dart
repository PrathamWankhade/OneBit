import 'package:flutter/foundation.dart';
import 'package:onebit/core/result/result.dart';

/// Wire kinds of one media transfer envelope.
enum MediaEnvelopeKind {
  /// Announcement (sender → receiver): file metadata before any chunk.
  announce,

  /// Chunk payload (sender → receiver).
  chunk,

  /// Acknowledgement (receiver → sender): chunk verified.
  ack,

  /// Request (receiver → sender): (re)send a specific chunk index.
  request,

  /// Pause (either side): schedule a stop; both sides keep state.
  pause,

  /// Complete (sender → receiver): all chunks acked, file verification.
  complete,

  /// Cancel (either side): abort the transfer, purge temp files.
  cancel;

  String get wireName => name;

  static MediaEnvelopeKind? fromWireName(String name) => switch (name) {
    'announce' => MediaEnvelopeKind.announce,
    'chunk' => MediaEnvelopeKind.chunk,
    'ack' => MediaEnvelopeKind.ack,
    'request' => MediaEnvelopeKind.request,
    'pause' => MediaEnvelopeKind.pause,
    'complete' => MediaEnvelopeKind.complete,
    'cancel' => MediaEnvelopeKind.cancel,
    _ => null,
  };
}

/// One media transfer envelope (payload-agnostic shape).
///
/// Every field is optional except [kind] + [sessionId]; codecs encode only
/// the fields a kind needs. [data] carries chunk bytes (bounded by the
/// engine's chunk size); [bitmap] carries the packed transfer bitmap in
/// cancel/complete/request outcomes.
@immutable
final class MediaEnvelope {
  const MediaEnvelope({
    required this.kind,
    required this.sessionId,
    this.direction,
    this.attachmentId,
    this.fileName,
    this.mimeType,
    this.category,
    this.totalSize,
    this.sha256,
    this.chunkIndex,
    this.offset,
    this.byteLength,
    this.data,
    this.ok = true,
    this.reason,
    this.bitmap,
  });

  final MediaEnvelopeKind kind;
  final String sessionId;
  final String? direction;

  // ---- announce / complete ----------------------------------------------
  final String? attachmentId;
  final String? fileName;
  final String? mimeType;
  final String? category;

  /// Whole-file size in bytes.
  final int? totalSize;

  /// Whole-file SHA-256 (hex) — the file-level integrity anchor.
  final String? sha256;

  // ---- chunk / request / ack --------------------------------------------
  final int? chunkIndex;
  final int? offset;
  final int? byteLength;

  /// Chunk payload bytes (only for `chunk`).
  final List<int>? data;

  final bool ok;
  final String? reason;

  /// Packed bitmap (request outcomes at cancel/complete).
  final List<int>? bitmap;

  MediaEnvelope copyWith({bool? ok, String? reason, List<int>? data}) =>
      MediaEnvelope(
        kind: kind,
        sessionId: sessionId,
        direction: direction,
        attachmentId: attachmentId,
        fileName: fileName,
        mimeType: mimeType,
        category: category,
        totalSize: totalSize,
        sha256: sha256,
        chunkIndex: chunkIndex,
        offset: offset,
        byteLength: byteLength,
        data: data ?? this.data,
        ok: ok ?? this.ok,
        reason: reason ?? this.reason,
        bitmap: bitmap,
      );

  @override
  bool operator ==(Object other) =>
      other is MediaEnvelope &&
      other.kind == kind &&
      other.sessionId == sessionId &&
      other.chunkIndex == chunkIndex;

  @override
  int get hashCode => Object.hash(kind, sessionId, chunkIndex);

  @override
  String toString() =>
      'MediaEnvelope($kind $sessionId '
      'chunk=$chunkIndex ok=$ok${reason == null ? '' : ' ($reason)'})';
}

/// The wire-format seam of media transfers.
///
/// Pure shape conversions — the data layer implements the DTN interop; the
/// engine never sees transport bytes.
abstract interface class MediaEnvelopeCodec {
  /// Encodes [envelope] into wire bytes (never throws).
  List<int> encode(MediaEnvelope envelope);

  /// Decodes wire bytes; `Err(SerializationFailure)` on malformed payloads.
  Result<MediaEnvelope> decode(List<int> payload);

  /// Escape hatch for tiny payloads (must decode back to the same byte
  /// sequence when non-null).
  List<int>? encodeBytes(String tag, List<int> bytes);
}
