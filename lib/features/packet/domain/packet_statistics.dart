/// Immutable snapshot of packet-layer counters, for the developer screen.
final class PacketStatistics {
  const PacketStatistics({
    this.packetsCreated = 0,
    this.packetsSent = 0,
    this.bytesSent = 0,
    this.packetsDelivered = 0,
    this.packetsRejected = 0,
    this.fragmentsAccepted = 0,
    this.fragmentsCompleted = 0,
    this.fragmentsExpired = 0,
    this.errorsLogged = 0,
    this.activeAssemblies = 0,
  });

  /// Logical packets built by this node.
  final int packetsCreated;

  /// Logical packets handed to the mesh layer.
  final int packetsSent;

  /// Total payload bytes serialized.
  final int bytesSent;

  /// Complete packets delivered up after decode.
  final int packetsDelivered;

  /// Frames dropped by validation.
  final int packetsRejected;

  /// Buffered fragment frames.
  final int fragmentsAccepted;

  /// Fully reassembled runs.
  final int fragmentsCompleted;

  /// Reassembly runs that timed out or were evicted.
  final int fragmentsExpired;

  /// Errors logged by the engine.
  final int errorsLogged;

  /// Live reassembly sessions.
  final int activeAssemblies;
}
