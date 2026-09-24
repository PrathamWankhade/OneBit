/// Transport-level transfer ID — an 8-bit counter that wraps at 256.
///
/// Transfer IDs only need to distinguish the current transfer from
/// previous ones within the retry window. They are NOT message IDs.
class TransferId {
  TransferId([this._value = 0]);

  int _value;

  /// Current value (0–255).
  int get value => _value;

  /// Increment and return the next ID.
  int next() {
    _value = (_value + 1) & 0xFF;
    return _value;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransferId && _value == other._value;

  @override
  int get hashCode => _value.hashCode;

  @override
  String toString() => 'TransferId($_value)';
}

/// State of a reliable transfer.
enum TransferState {
  /// Transfer created but not yet sent.
  pending,

  /// Bytes sent, waiting for ACK.
  waitingForAck,

  /// ACK timed out, will retry.
  retrying,

  /// ACK received — delivery confirmed.
  delivered,

  /// All retries exhausted or channel failed.
  failed,

  /// Transfer cancelled by caller or disposal.
  cancelled,
}

/// Outcome of a sendReliable() call.
enum TransferResult {
  /// ACK received within retry budget.
  delivered,

  /// Retries exhausted or channel error.
  failed,

  /// Transfer cancelled by caller or disposal.
  cancelled,
}

/// Minimal reliability envelope.
///
/// Wire format (sent over the communication characteristic):
/// ```
/// [0] type:     0x01 = DATA, 0x02 = ACK
/// [1] transferId:  8-bit counter
/// [2..] payload:   (DATA only, absent in ACK)
/// ```
///
/// This is intentionally small and replaceable by the formal
/// packet protocol in I3.4.
class TransferEnvelope {
  const TransferEnvelope({
    required this.type,
    required this.transferId,
    this.payload = const [],
  });

  /// Envelope type marker.
  final int type;
  final int transferId;
  final List<int> payload;

  static const int dataType = 0x01;
  static const int ackType = 0x02;

  bool get isData => type == dataType;
  bool get isAck => type == ackType;

  /// Encode to bytes for transmission.
  List<int> encode() => [type, transferId, ...payload];

  /// Decode from raw bytes. Returns null if malformed.
  static TransferEnvelope? decode(List<int> bytes) {
    if (bytes.length < 2) return null;
    final type = bytes[0];
    if (type != dataType && type != ackType) return null;
    return TransferEnvelope(
      type: type,
      transferId: bytes[1],
      payload: bytes.sublist(2),
    );
  }
}
