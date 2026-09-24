import 'dart:typed_data';

/// Bounded replay window for detecting duplicate sequence numbers.
///
/// Uses a sliding window relative to the highest seen sequence number.
/// Messages with sequence numbers older than the window are rejected.
/// Messages with sequence numbers already seen within the window are rejected.
///
/// ## Window Semantics
///
/// Given `highestSeen` and `windowSize`:
/// - Accepted range: `[highestSeen - windowSize + 1, highestSeen]`
/// - Below range: rejected as old
/// - Above range: accepted and advances window
/// - Within range but already seen: rejected as duplicate
class ReplayWindow {
  ReplayWindow({this.windowSize = 64});

  /// Number of recent sequence numbers to remember.
  final int windowSize;

  /// Highest sequence number accepted so far, or -1 if none.
  int highestSeen = -1;

  /// Bitset tracking which sequence numbers in the current window have been
  /// seen. Bit `i` corresponds to sequence `highestSeen - i`.
  int _bitset = 0;

  /// Check whether [sequence] is acceptable.
  ///
  /// Returns true if the sequence is new and within the window, and advances
  /// the window if necessary.
  ///
  /// Returns false if the sequence is a duplicate, too old, or malformed.
  bool accept(int sequence) {
    if (sequence < 0) return false;

    if (highestSeen == -1) {
      // First message
      highestSeen = sequence;
      _bitset = 1; // Mark bit 0 (current highest)
      return true;
    }

    if (sequence > highestSeen) {
      // New high — advance window
      final shift = sequence - highestSeen;
      if (shift >= windowSize) {
        // Jumped past the entire window
        _bitset = 0;
      } else {
        _bitset <<= shift;
      }
      highestSeen = sequence;
      _bitset |= 1; // Mark the new highest
      return true;
    }

    // sequence <= highestSeen
    final offset = highestSeen - sequence;
    if (offset >= windowSize) {
      // Too old — outside window
      return false;
    }

    // Check if already seen
    final bit = 1 << offset;
    if (_bitset & bit != 0) {
      // Duplicate
      return false;
    }

    // New within window
    _bitset |= bit;
    return true;
  }

  /// Check whether [sequence] has been accepted without mutating state.
  bool contains(int sequence) {
    if (sequence < 0 || highestSeen == -1) return false;
    final offset = highestSeen - sequence;
    if (offset < 0 || offset >= windowSize) return false;
    return _bitset & (1 << offset) != 0;
  }

  /// Reset the window to empty state.
  void reset() {
    highestSeen = -1;
    _bitset = 0;
  }
}

/// Monotonically increasing send counter for outgoing messages.
///
/// Each call to [next] returns the next sequence number. The counter
/// never decreases within a session.
class SendCounter {
  SendCounter({this._value = 0});

  int _value;

  /// Current sequence number.
  int get value => _value;

  /// Next sequence number for an outgoing message.
  ///
  /// Throws [CounterExhaustedException] if the counter has reached
  /// the safe maximum value.
  int next() {
    if (_value >= maxSafeSequence) {
      throw const CounterExhaustedException();
    }
    _value++;
    return _value;
  }
}

/// Maximum safe sequence number (2^53 - 1, safe for all JS/dart integer ops).
const int maxSafeSequence = 9007199254740991;

/// Thrown when a send counter has exhausted its safe range.
class CounterExhaustedException implements Exception {
  const CounterExhaustedException();

  @override
  String toString() => 'CounterExhaustedException: sequence counter exhausted';
}

/// Canonical binary encoding of a sequence number for AAD.
///
/// Encodes as 8-byte big-endian, platform-independent.
Uint8List encodeSequenceForAad(int sequence) {
  if (sequence < 0 || sequence > maxSafeSequence) {
    throw ArgumentError('Sequence out of range: $sequence');
    }
  final bytes = ByteData(8);
  bytes.setInt64(0, sequence, Endian.big);
  return bytes.buffer.asUint8List();
}

/// Exception for replay protection failures.
class ReplayException implements Exception {
  const ReplayException(this.message);
  final String message;

  @override
  String toString() => 'ReplayException: $message';
}
