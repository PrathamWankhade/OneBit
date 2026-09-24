/// I8.4 — Binary codec for topology advertisements.
///
/// Encodes/decodes [TopologyAdvertisement] to/from bytes following
/// the OneBit binary protocol conventions (big-endian, length-prefixed).
///
/// ## Wire Format
///
/// ```
/// [version: 1B][sequence: 8B][sourceIdentity: 64B]
/// [neighborCount: 2B][neighbor1: 64B]...[neighborN: 64B]
/// ```
///
/// Total size: 75 + (neighborCount × 64) bytes.
/// Maximum payload: 255 bytes (OneBit packet limit).
/// Maximum neighbors per packet: 2.
library;

import 'dart:typed_data';

import 'package:onebit/features/routing/topology_advertisement.dart';

/// Errors specific to topology advertisement codec.
enum TopologyCodecError {
  /// The encoded data is too short.
  tooShort,

  /// The protocol version is unsupported.
  unsupportedVersion,

  /// The source identity has invalid length.
  invalidSourceIdentity,

  /// A neighbor PeerId has invalid length.
  invalidNeighborId,

  /// Too many neighbors for the payload.
  tooManyNeighbors,

  /// Trailing bytes after the expected data.
  trailingBytes,

  /// The neighbor count field is malformed.
  invalidNeighborCount,
}

/// Exception thrown when decoding a malformed advertisement.
class TopologyDecodeException implements Exception {
  const TopologyDecodeException(this.reason);

  final TopologyCodecError reason;

  @override
  String toString() => 'TopologyDecodeException: $reason';
}

/// Binary codec for [TopologyAdvertisement].
///
/// Follows the same static-method pattern as [MessageCodec].
class TopologyAdvertisementCodec {
  TopologyAdvertisementCodec._();

  // ── Encoding ──────────────────────────────────────────────

  /// Encode a [TopologyAdvertisement] to its binary representation.
  ///
  /// Throws [ArgumentError] if the advertisement structure is invalid.
  static Uint8List encode(TopologyAdvertisement ad) {
    if (!ad.isValid) {
      throw ArgumentError('Invalid advertisement: ${ad.toString()}');
    }

    final sourceBytes = _hexToBytes(ad.sourceIdentity);
    final bytes = Uint8List(
      1 + 8 + sourceBytes.length + 2 + (ad.neighborPeerIds.length * peerIdByteLength ~/ 2),
    );
    var offset = 0;

    // Version (1 byte).
    bytes[offset++] = topologyAdvertisementVersion;

    // Sequence (8 bytes, big-endian int64).
    final seq = ByteData(8);
    seq.setInt64(0, ad.sequence, Endian.big);
    bytes.setAll(offset, seq.buffer.asUint8List());
    offset += 8;

    // Source identity (32 raw bytes from 64-char hex).
    bytes.setAll(offset, sourceBytes);
    offset += sourceBytes.length;

    // Neighbor count (2 bytes, big-endian uint16).
    bytes[offset++] = (ad.neighborPeerIds.length >> 8) & 0xFF;
    bytes[offset++] = ad.neighborPeerIds.length & 0xFF;

    // Neighbor IDs (32 raw bytes each).
    for (final neighborId in ad.neighborPeerIds) {
      final neighborBytes = _hexToBytes(neighborId);
      bytes.setAll(offset, neighborBytes);
      offset += neighborBytes.length;
    }

    return bytes.sublist(0, offset);
  }

  // ── Decoding ──────────────────────────────────────────────

  /// Decode a binary buffer into a [TopologyAdvertisement].
  ///
  /// Throws [TopologyDecodeException] if the data is malformed,
  /// has an unsupported version, or fails validation.
  static TopologyAdvertisement decode(Uint8List bytes) {
    if (bytes.length < topologyAdvertisementMinSize) {
      throw const TopologyDecodeException(TopologyCodecError.tooShort);
    }

    var offset = 0;

    // Version.
    final version = bytes[offset++];
    if (version != topologyAdvertisementVersion) {
      throw const TopologyDecodeException(
        TopologyCodecError.unsupportedVersion,
      );
    }

    // Sequence (8 bytes, big-endian int64).
    final seqData = ByteData(8);
    seqData.buffer.asUint8List().setAll(0, bytes.sublist(offset, offset + 8));
    final sequence = seqData.getInt64(0, Endian.big);
    offset += 8;

    // Source identity (32 raw bytes → 64-char hex).
    final sourceBytes = bytes.sublist(offset, offset + 32);
    offset += 32;
    final sourceIdentity = _bytesToHex(sourceBytes);

    // Neighbor count (2 bytes, big-endian uint16).
    if (offset + 2 > bytes.length) {
      throw const TopologyDecodeException(
        TopologyCodecError.invalidNeighborCount,
      );
    }
    final neighborCount = (bytes[offset] << 8) | bytes[offset + 1];
    offset += 2;

    if (neighborCount > maxAdvertisedNeighbors) {
      throw const TopologyDecodeException(TopologyCodecError.tooManyNeighbors);
    }

    // Expected size check.
    final expectedSize = topologyAdvertisementMinSize + (neighborCount * 32);
    if (bytes.length < expectedSize) {
      throw const TopologyDecodeException(TopologyCodecError.tooShort);
    }

    // Neighbor IDs (32 raw bytes each → 64-char hex).
    final neighbors = <String>[];
    for (var i = 0; i < neighborCount; i++) {
      final neighborBytes = bytes.sublist(offset, offset + 32);
      offset += 32;
      neighbors.add(_bytesToHex(neighborBytes));
    }

    // Reject trailing bytes.
    if (offset != bytes.length) {
      throw const TopologyDecodeException(TopologyCodecError.trailingBytes);
    }

    return TopologyAdvertisement(
      sourceIdentity: sourceIdentity,
      sequence: sequence,
      neighborPeerIds: neighbors,
    );
  }

  // ── Hex utilities ─────────────────────────────────────────

  static final _hexChars = '0123456789abcdef'.codeUnits;

  /// Convert a 64-char hex string to 32 raw bytes.
  static Uint8List _hexToBytes(String hex) {
    if (hex.length != 64) {
      throw ArgumentError('Invalid hex string length: ${hex.length}');
    }
    final bytes = Uint8List(32);
    for (var i = 0; i < 32; i++) {
      final hi = _hexCharValue(hex.codeUnitAt(i * 2));
      final lo = _hexCharValue(hex.codeUnitAt(i * 2 + 1));
      bytes[i] = (hi << 4) | lo;
    }
    return bytes;
  }

  /// Convert 32 raw bytes to a 64-char hex string.
  static String _bytesToHex(Uint8List bytes) {
    final buf = StringBuffer();
    for (final b in bytes) {
      buf.writeCharCode(_hexChars[(b >> 4) & 0x0F]);
      buf.writeCharCode(_hexChars[b & 0x0F]);
    }
    return buf.toString();
  }

  static int _hexCharValue(int codeUnit) {
    if (codeUnit >= 48 && codeUnit <= 57) return codeUnit - 48; // 0-9
    if (codeUnit >= 97 && codeUnit <= 102) return codeUnit - 87; // a-f
    if (codeUnit >= 65 && codeUnit <= 70) return codeUnit - 55; // A-F
    throw ArgumentError('Invalid hex character: ${String.fromCharCode(codeUnit)}');
  }
}
