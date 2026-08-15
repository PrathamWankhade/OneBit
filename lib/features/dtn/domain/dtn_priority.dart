/// Delivery priority of a DTN envelope.
///
/// Five levels, strictly ordered. Priority decides the order in which the
/// scheduler drains the outgoing queue; it is persisted per envelope as a
/// stable name string, so levels can never shift meaning across releases.
enum DtnPriority {
  /// Life-safety / operator traffic. The only level that may pre-empt the
  /// connectivity park: critical packets are attempted even on a degraded
  /// link because waiting may be worse than trying.
  critical,

  /// Important traffic that should leave at the next opportunity.
  high,

  /// Default for ordinary traffic.
  normal,

  /// Bulk traffic that yields to anything above it.
  low,

  /// Best-effort traffic; only attempted when the delivery budget has room.
  background;

  /// Total order rank used for sorting (higher = earlier delivery).
  int get rank => index;

  /// Stable persistence name.
  String get wireName => name;
}
