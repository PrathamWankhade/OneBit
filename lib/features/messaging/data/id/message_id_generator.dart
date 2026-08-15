import 'dart:math';

/// Generates wire-safe, collision-resistant message ids.
///
/// Format: `MSG-<millis>-<8 hex random bytes>` — the timestamp disambiguates
/// humans and the random suffix provides the entropy; ids are opaque and
/// never parsed.
final class MessageIdGenerator {
  const MessageIdGenerator();

  static final Random _random = Random.secure();

  String next() {
    final millis = DateTime.now().millisecondsSinceEpoch;
    final seed = List<int>.generate(8, (_) => _random.nextInt(256));
    final hex = seed.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return 'MSG-$millis-$hex';
  }

  /// Stable receipt id derivations (idempotency keys).
  static String deliveryReceiptId(String messageId, String node) =>
      'delivery:$messageId:$node';

  static String readReceiptId(String messageId, String node, String? device) =>
      'read:$messageId:$node${device == null ? '' : ':$device'}';
}
