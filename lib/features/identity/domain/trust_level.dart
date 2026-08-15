/// How strongly this device trusts a known peer node.
enum TrustLevel {
  /// Contact exists on this device but no verification has happened.
  known,

  /// Identity was verified out-of-band (matching QR verification code).
  verified,

  /// The peer is deliberately blocked; mesh traffic is rejected.
  blocked;

  /// Stable, primary machine identifier (safe for persistence).
  String get key => name;
}
