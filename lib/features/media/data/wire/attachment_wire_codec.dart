import 'dart:convert';

import 'package:onebit/core/errors/failure.dart';
import 'package:onebit/core/result/result.dart';

import '../../transfer/transfer_envelope.dart';

/// The production wire codec of media transfer envelopes.
///
/// Compact JSON, keys: v(sion) k(ind) s(ession) d(irection) a(ttachmentId)
/// f(ileName) m(ime) c(ategory) n(totalSize) h(sha256) i(chunkIndex)
/// o(ffset) l(ength) x(data b64) ok r(eason) b(bitmap b64). Unknown keys
/// are ignored on decode; malformed payloads → [SerializationFailure].
final class AttachmentWireCodec implements MediaEnvelopeCodec {
  const AttachmentWireCodec();

  static const int wireVersion = 1;

  /// Safety bound against decompression-bomb style payloads.
  static const int maxDecodedBytes = 2 * 1024 * 1024;

  @override
  List<int> encode(MediaEnvelope envelope) {
    final map = <String, Object?>{
      'v': wireVersion,
      'k': envelope.kind.wireName,
      's': envelope.sessionId,
    };
    void put(String key, Object? value) {
      if (value != null) map[key] = value;
    }

    put('d', envelope.direction);
    put('a', envelope.attachmentId);
    put('f', envelope.fileName);
    put('m', envelope.mimeType);
    put('c', envelope.category);
    put('n', envelope.totalSize);
    put('h', envelope.sha256);
    put('i', envelope.chunkIndex);
    put('o', envelope.offset);
    put('l', envelope.byteLength);
    if (envelope.data != null) {
      map['x'] = base64Encode(envelope.data!);
    }
    map['ok'] = envelope.ok;
    put('r', envelope.reason);
    if (envelope.bitmap != null && envelope.bitmap!.isNotEmpty) {
      map['b'] = base64Encode(envelope.bitmap!);
    }
    return utf8.encode(jsonEncode(map));
  }

  @override
  Result<MediaEnvelope> decode(List<int> payload) {
    if (payload.length > maxDecodedBytes) {
      return const Err(
        SerializationFailure(
          source: 'mediaWire',
          message: 'envelope exceeds the $maxDecodedBytes byte bound',
        ),
      );
    }
    Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(payload, allowMalformed: false));
    } catch (error, stackTrace) {
      return Err(
        SerializationFailure(
          source: 'mediaWire',
          message: 'payload is not JSON',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
    if (decoded is! Map<String, Object?>) {
      return const Err(
        SerializationFailure(
          source: 'mediaWire',
          message: 'envelope root must be a JSON object',
        ),
      );
    }
    final kindName = decoded['k'] as String? ?? '';
    final kind = MediaEnvelopeKind.fromWireName(kindName);
    final sessionId = decoded['s'] as String? ?? '';
    if (kind == null || sessionId.isEmpty) {
      return const Err(
        SerializationFailure(
          source: 'mediaWire',
          message: 'envelope missing kind or sessionId',
        ),
      );
    }
    try {
      return Ok(
        MediaEnvelope(
          kind: kind,
          sessionId: sessionId,
          direction: decoded['d'] as String?,
          attachmentId: decoded['a'] as String?,
          fileName: decoded['f'] as String?,
          mimeType: decoded['m'] as String?,
          category: decoded['c'] as String?,
          totalSize: (decoded['n'] as num?)?.toInt(),
          sha256: decoded['h'] as String?,
          chunkIndex: (decoded['i'] as num?)?.toInt(),
          offset: (decoded['o'] as num?)?.toInt(),
          byteLength: (decoded['l'] as num?)?.toInt(),
          data: _decodeBase64(decoded['x']),
          ok: decoded['ok'] as bool? ?? true,
          reason: decoded['r'] as String?,
          bitmap: _decodeBase64(decoded['b']),
        ),
      );
    } catch (error, stackTrace) {
      return Err(
        SerializationFailure(
          source: 'mediaWire',
          message: 'envelope decode failed',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  List<int>? _decodeBase64(Object? value) {
    if (value is! String || value.isEmpty) return null;
    final bytes = base64Decode(value);
    if (bytes.length > maxDecodedBytes) return null;
    return bytes;
  }

  @override
  List<int>? encodeBytes(String tag, List<int> bytes) => null;
}
