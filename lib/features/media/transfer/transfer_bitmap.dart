import 'dart:math';
import 'dart:typed_data';

/// The authoritative "what did we get" record of a transfer.
///
/// Bit *i* set ⇔ chunk *i* acknowledged (sender) or received + verified
/// (receiver). The bitmap is persisted as packed bytes after every change
/// (crash-safe resume), and it is the only record the scheduler reads when
/// deciding what to transmit next — nothing else tracks chunk progress.
///
/// Pure domain: no I/O, no drift, fully unit-testable.
final class TransferBitmap {
  TransferBitmap._(this._bits) : _setBits = _countSet(_bits);

  /// A bitmap with no chunk acknowledged.
  factory TransferBitmap.empty(int totalChunks) {
    if (totalChunks < 1) {
      throw ArgumentError.value(totalChunks, 'totalChunks', 'must be >= 1');
    }
    return TransferBitmap._(Uint8List(totalChunks));
  }

  /// Decodes a packed bitmap. [bytes] may be shorter than a full packing for
  /// old or truncated rows; missing bits count as unset. Trailing bytes that
  /// exceed [totalChunks] are ignored (defense against corrupt rows).
  factory TransferBitmap.fromBytes(List<int> bytes, int totalChunks) {
    if (totalChunks < 1) {
      throw ArgumentError.value(totalChunks, 'totalChunks', 'must be >= 1');
    }
    final bits = Uint8List(totalChunks);
    for (
      var byteIndex = 0;
      byteIndex < bytes.length && byteIndex << 3 < totalChunks;
      byteIndex++
    ) {
      final byte = bytes[byteIndex];
      final base = byteIndex << 3;
      final count = min(8, totalChunks - base);
      for (var bit = 0; bit < count; bit++) {
        if (byte & (1 << (7 - bit)) != 0) {
          bits[base + bit] = 1;
        }
      }
    }
    return TransferBitmap._(bits);
  }

  /// One byte per chunk (0/1) — the in-memory working form.
  final Uint8List _bits;

  /// Precomputed count of set bits (avoids repeated scans).
  final int _setBits;

  /// Number of chunks tracked by this bitmap.
  int get totalChunks => _bits.length;

  /// Number of acknowledged chunks.
  int get acknowledgedCount => _setBits;

  /// True when [index] is within range and acknowledged.
  bool acknowledged(int index) =>
      index >= 0 && index < _bits.length && _bits[index] == 1;

  /// True when every chunk is acknowledged.
  bool get isComplete => _setBits == _bits.length;

  /// Progress as a 0..1 fraction (0 when the file has no chunks).
  double get progress => _bits.isEmpty ? 0 : _setBits / _bits.length;

  /// A copy of this bitmap with [index] marked acknowledged (idempotent).
  TransferBitmap markAcknowledged(int index) {
    if (index < 0 || index >= _bits.length) {
      throw RangeError.index(index, _bits, 'index', null, totalChunks);
    }
    if (_bits[index] == 1) {
      return this;
    }
    final next = Uint8List.fromList(_bits);
    next[index] = 1;
    return TransferBitmap._(next);
  }

  /// Indices of every unacknowledged chunk, ascending (the scheduler's
  /// queue). A fraction of the whole — allocation is bounded by missing
  /// count, never by totalChunks.
  List<int> missing() => [
    for (var i = 0; i < _bits.length; i++)
      if (_bits[i] == 0) i,
  ];

  /// Packed big-endian form (MSB of byte 0 = bit 0): `ceil(n / 8)` bytes.
  ///
  /// Never null-pads beyond the ceil — `fromBytes` accepts any length.
  Uint8List toBytes() {
    final bytes = Uint8List((_bits.length + 7) >> 3);
    for (var i = 0; i < _bits.length; i++) {
      if (_bits[i] == 1) {
        bytes[i >> 3] |= 1 << (7 - (i & 7));
      }
    }
    return bytes;
  }

  static int _countSet(Uint8List bits) {
    var count = 0;
    for (final bit in bits) {
      if (bit == 1) count++;
    }
    return count;
  }

  @override
  bool operator ==(Object other) =>
      other is TransferBitmap &&
      other._bits.length == _bits.length &&
      _bitsEquals(other._bits);

  @override
  int get hashCode => Object.hashAll(_bits);

  bool _bitsEquals(Uint8List other) {
    for (var i = 0; i < _bits.length; i++) {
      if (_bits[i] != other[i]) return false;
    }
    return true;
  }

  @override
  String toString() => 'TransferBitmap($acknowledgedCount/$totalChunks acked)';
}
