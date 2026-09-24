/// Resource bounds for the routing subsystem.
///
/// Every collection and operation in the routing pipeline is bounded by
/// these constants to prevent resource exhaustion from malformed input
/// or malicious topology advertisements.
abstract final class RoutingLimits {
  /// Maximum number of directly connected neighbors.
  static const int maxNeighbors = 64;

  /// Maximum number of remote topology sources retained in memory.
  static const int maxTopologySources = 256;

  /// Maximum number of neighbor IDs per remote topology source.
  static const int maxNeighborsPerSource = 64;

  /// Maximum number of route destinations in the routing table.
  static const int maxRouteDestinations = 512;

  /// Maximum number of candidate routes per destination.
  static const int maxRoutesPerDestination = 8;

  /// Maximum route metric (hop count).
  static const int maxRouteMetric = 255;

  /// Maximum BFS search depth during route discovery.
  static const int maxDiscoveryDepth = 64;

  /// Maximum number of entries in the BFS visited set.
  static const int maxDiscoveryVisited = 1024;

  /// Maximum number of recovering destinations tracked simultaneously.
  static const int maxRecoveryStates = 128;

  /// Maximum number of diagnostic security events retained.
  static const int maxDiagnosticEvents = 200;

  /// Maximum number of entries in the security event log.
  static const int maxSecurityEventLog = 200;

  /// Maximum raw advertisement payload size in bytes.
  static const int maxAdvertisementPayloadSize = 4096;

  /// Valid length of a hex-encoded Ed25519 public key (PeerId).
  static const int peerIdLength = 64;

  /// Maximum number of recovery attempts per destination before giving up.
  static const int maxRecoveryAttempts = 5;

  /// Grace period before stale neighbor entries are evicted.
  static const Duration staleNeighborGracePeriod = Duration(minutes: 5);
}
