/// Delivery priority of an outgoing message.
///
/// Maps onto the DTN priority ladder at the outbox boundary:
/// urgent→critical, high→high, normal→normal, low→low.
enum MessagePriority {
  low,
  normal,
  high,
  urgent;

  String get wireName => name;
}
