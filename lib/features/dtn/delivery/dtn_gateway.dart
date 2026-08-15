import '../domain/dtn_connectivity.dart';
import '../domain/dtn_envelope.dart';

/// Outcome of one transmit attempt.
final class DtnGatewayOutcome {
  const DtnGatewayOutcome({
    required this.ok,
    this.errorMessage,
    this.permanent = false,
    this.willAck = false,
  });

  /// True when the gateway accepted the packet for transmission.
  final bool ok;

  /// Reason for a failed attempt (from the gateway).
  final String? errorMessage;

  /// When true, retrying is pointless: the gateway refused the packet for
  /// good (unknown destination, permanent policy). The engine fails the
  /// envelope instead of scheduling a retry.
  final bool permanent;

  /// Whether this node should expect a logical acknowledgement for the
  /// envelope (false for fire-and-forget or relay forwards).
  final bool willAck;

  static const rejected = DtnGatewayOutcome(ok: false, permanent: true);
  static const needRetry = DtnGatewayOutcome(
    ok: false,
    permanent: false,
    errorMessage: 'gateway busy',
  );
  static const accepted = DtnGatewayOutcome(ok: true, willAck: true);
  static const acceptedNoAck = DtnGatewayOutcome(ok: true, willAck: false);
}

/// The mesh seam every transport (Phase 4-6) implements.
///
/// The engine depends only on this contract, so a simulated transport, a
/// real radio transport and a test transport are equivalent.
abstract interface class DtnGateway {
  /// Whether the mesh appears reachable right now.
  DtnConnectivitySnapshot connectivity();

  /// Attempt to transmit [packet].
  ///
  /// The transport decides final delivery. Direction `relay` means the
  /// packet is passing through this node; the transport decides what that
  /// means for a specific protocol.
  DtnGatewayOutcome transmit(DtnPacket packet);

  /// Start background transport duties (if any). Idempotent.
  Future<void> start();

  /// Stop background transport duties. Idempotent.
  Future<void> stop();

  /// Notified when the DTN layer parks/unparks envelopes (statistics).
  void onLayerEvent(String event);
}

/// Default "no transport wired" gateway — offline but never an error.
final class NoopDtnGateway implements DtnGateway {
  const NoopDtnGateway();

  @override
  DtnConnectivitySnapshot connectivity() => DtnConnectivitySnapshot.initial;

  @override
  DtnGatewayOutcome transmit(DtnPacket packet) => DtnGatewayOutcome.needRetry;

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}

  @override
  void onLayerEvent(String event) {}
}
