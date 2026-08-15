/// Immutable snapshot of the mesh connectivity perception the DTN engine
/// uses as its delivery gate.
///
/// In this phase the snapshot comes from the `DtnGateway` mesh adapter seam
/// (Phase 4 transport stays a no-op); the semantics already match the future
/// radio monitor: `reachable ==` it may be worth transmitting right now.
final class DtnConnectivitySnapshot {
  const DtnConnectivitySnapshot({
    required this.reachable,
    this.senseAt,
    this.linkName = 'unknown',
    this.signalDbm,
  });

  /// Whether the mesh is reachable at this moment.
  final bool reachable;

  /// When the gateway last evaluated connectivity (may be null before the
  /// first evaluation).
  final DateTime? senseAt;

  /// Human-readable name of the current link (diagnostics only).
  final String linkName;

  /// Signal strength in dBm when the gateway reports it (diagnostics only).
  final int? signalDbm;

  /// The engine's initial state before the first gateway evaluation.
  static const initial = DtnConnectivitySnapshot(reachable: false);

  @override
  String toString() => reachable
      ? 'reachable($linkName${signalDbm != null ? ", ${signalDbm}dBm" : ''})'
      : 'unreachable';
}
