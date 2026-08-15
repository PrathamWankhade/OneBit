/// Lifecycle of the local [MeshEngine].
enum MeshEngineState {
  /// Not started; no subscriptions, no timers.
  stopped,

  /// `start()` called; transport wiring in progress.
  starting,

  /// Fully operational: discovery, routing, relaying.
  running,

  /// The radio is unavailable (Bluetooth off); tables are preserved and
  /// recovery is automatic once the radio returns.
  degraded,
}

/// Reachability of the radio as reported by the transport.
enum MeshRadioState {
  /// Radio is on and usable.
  on,

  /// Radio is off or unsupported.
  off,

  /// State not yet observed.
  unknown,
}

/// Connection lifecycle of a neighbor link.
enum MeshLinkState {
  /// Seen via advertisement only; no connection.
  advertising,

  /// A connection attempt is in flight.
  connecting,

  /// Connected (GATT link up).
  connected,

  /// A disconnect is in flight.
  disconnecting,

  /// The link dropped.
  disconnected,
}

/// Static capabilities a neighbor advertises.
///
/// Capabilities gate participation in future phases without changing the
/// engine's routing core: e.g. only nodes with `storeForward` may hold
/// undelivered traffic for later delivery.
enum MeshCapability {
  /// The node relays third-party traffic.
  relay,

  /// The node maintains and answers routes.
  router,

  /// The node can store and forward undelivered traffic (future phase).
  storeForward,
}

/// Trust classification of a neighbor.
///
/// Reserved for the identity phase: `unknown` today, `trusted`/`blocked`
/// once identity attestation exists. The engine never blocks relaying on
/// trust yet — it only exposes the field for future gating.
enum MeshTrustStatus {
  /// No identity evidence seen.
  unknown,

  /// Identity verified (future phase).
  trusted,

  /// Explicitly excluded from relaying (future phase).
  blocked,
}
