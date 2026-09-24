/// I8.4 — Topology advertisement model.
///
/// Represents the topology information that a peer broadcasts to its
/// directly reachable neighbors. Contains only the minimum data
/// needed for a receiver to update its topology knowledge.
///
/// ## Wire Format (big-endian)
///
/// ```
/// [version: 1B][sequence: 8B][sourceIdentity: 64B]
/// [neighborCount: 2B][neighbor1: 64B]...[neighborN: 64B]
/// ```
///
/// - version: protocol version (currently 1)
/// - sequence: monotonic source-scoped freshness counter
/// - sourceIdentity: 64-char hex-encoded Ed25519 public key
/// - neighborCount: number of advertised neighbors (uint16)
/// - neighbors: 64-char hex-encoded PeerIds
///
/// ## Semantics
///
/// An advertisement is a **snapshot** of the source's current direct
/// neighbor set. A newer advertisement fully replaces the previous one
/// for the same source.
library;

/// Protocol version for topology advertisements.
const int topologyAdvertisementVersion = 1;

/// Maximum number of neighbors allowed in a single advertisement.
const int maxAdvertisedNeighbors = 64;

/// Fixed byte length of a hex-encoded PeerId (Ed25519 public key).
const int peerIdByteLength = 64;

/// Fixed byte length of a raw public key (32 bytes from 64-char hex).
const int rawPublicKeyByteLength = 32;

/// Minimum serialized size in bytes (version + sequence + source + count).
/// Wire format uses 32 raw bytes per identity, not 64 hex characters.
const int topologyAdvertisementMinSize =
    1 + 8 + rawPublicKeyByteLength + 2; // 43 bytes

/// A topology advertisement from a directly reachable peer.
///
/// Immutable — once created, fields never change. Equality is based
/// on source identity and sequence number for deduplication.
class TopologyAdvertisement {
  const TopologyAdvertisement({
    required this.sourceIdentity,
    required this.sequence,
    required this.neighborPeerIds,
  });

  /// The peer identity that generated this advertisement.
  ///
  /// Must be a 64-char hex-encoded Ed25519 public key (PeerId).
  final String sourceIdentity;

  /// Monotonic source-scoped sequence number for freshness.
  ///
  /// A receiver uses this to reject older/replayed advertisements.
  /// Values are source-scoped — only meaningful relative to the
  /// same sourceIdentity.
  final int sequence;

  /// The source's current set of direct neighbor PeerIds.
  ///
  /// Each entry is a 64-char hex-encoded Ed25519 public key.
  /// This is a snapshot — a newer advertisement replaces the
  /// entire set.
  final List<String> neighborPeerIds;

  /// Whether this advertisement has the expected structure.
  bool get isValid {
    if (sourceIdentity.length != peerIdByteLength) return false;
    if (sequence < 0) return false;
    if (neighborPeerIds.length > maxAdvertisedNeighbors) return false;
    for (final id in neighborPeerIds) {
      if (id.length != peerIdByteLength) return false;
    }
    return true;
  }

  /// Whether the source advertises itself as its own neighbor (invalid).
  bool get hasSelfLoop => neighborPeerIds.contains(sourceIdentity);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TopologyAdvertisement &&
          runtimeType == other.runtimeType &&
          sourceIdentity == other.sourceIdentity &&
          sequence == other.sequence;

  @override
  int get hashCode => Object.hash(sourceIdentity, sequence);

  @override
  String toString() =>
      'TopologyAdvertisement(source: ${sourceIdentity.substring(0, 8)}..., '
      'seq: $sequence, neighbors: ${neighborPeerIds.length})';
}
