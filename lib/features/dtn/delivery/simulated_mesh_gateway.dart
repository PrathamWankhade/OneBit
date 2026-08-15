import '../domain/dtn_connectivity.dart';
import '../domain/dtn_envelope.dart';
import 'dtn_gateway.dart';

/// A controllable gateway for development screens and tests.
///
/// The mesh does not exist yet (Phase 4+), so the default gateway reports
/// unreachable and nothing transmits. Flip [reachable] (and the per-call
/// [acceptance]) from the dev console or a test to watch the DTN layer work
/// end to end without a radio.
final class SimulatedMeshGateway implements DtnGateway {
  SimulatedMeshGateway({
    this.reachable = false,
    this.accepts = true,
    this.transientFailures = 0,
  });

  /// Whether the mesh appears reachable right now.
  bool reachable;

  /// When false, every transmit is refused permanently (gateway rejects).
  bool accepts;

  /// Number of upcoming transmits to fail *transiently* (retryable) before
  /// normal acceptance resumes. Simulates a flapping radio link.
  int transientFailures;

  /// Total accepted transmits (statistics fodder).
  int transmittedCount = 0;

  /// Records of the last transmissions (id → destination), dev inspection.
  final List<({String packetId, String destination})> history = [];

  @override
  DtnConnectivitySnapshot connectivity() => DtnConnectivitySnapshot(
    reachable: reachable,
    senseAt: DateTime.now(),
    linkName: 'simulated',
    signalDbm: reachable ? -60 : null,
  );

  @override
  DtnGatewayOutcome transmit(DtnPacket packet) {
    if (!reachable) {
      return DtnGatewayOutcome.needRetry;
    }
    if (!accepts) {
      return DtnGatewayOutcome.rejected;
    }
    if (transientFailures > 0) {
      transientFailures--;
      return DtnGatewayOutcome.needRetry;
    }
    transmittedCount++;
    history.add((packetId: packet.packetId, destination: packet.destination));
    // Simulated mesh delivers instantly; no logical ack is expected, so the
    // envelope reaches `delivered` fire-and-forget (relay packets pass on).
    return DtnGatewayOutcome.acceptedNoAck;
  }

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}

  @override
  void onLayerEvent(String event) {}
}
