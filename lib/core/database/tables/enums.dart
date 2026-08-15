/// Shared enum vocabulary for the OneBit persistence schema.
///
/// Enums are stored as stable name strings (`textEnum`) rather than ordinals
/// so reordering values never invalidates stored rows. Values must never be
/// renamed once released — add new values, keep old ones.
library;

/// Trust posture of a known peer node.
enum TrustStatus { pending, trusted, verified, blocked }

/// How a peer's identity was verified.
enum VerificationMethod { none, manual, qr, outOfBand }

/// Kind of a logical channel.
enum ChannelType {
  /// 1:1 private conversation (Phase 8 messaging — first-class).
  private,
  direct,
  group,
  broadcast,
  emergency,
  developer,
}

/// High-level content kind of a stored message.
enum MessageType {
  text,
  markdown,
  system,
  notification,
  identity,
  handshake,
  receipt,
  developer,
  attachment,
  voiceNote,
  media,
  voice,
  file,
  control,
}

/// Lifecycle state of a message.
enum MessageStatus {
  pending,
  created,
  queued,
  waiting,
  routing,
  relayed,
  sent,
  delivered,
  verified,
  read,
  failed,
  expired,
  deleted,
}

/// Priority used for outbound ordering (messages and packets).
enum PriorityLevel { low, normal, high, urgent }

/// Attachment content category.
enum AttachmentKind { file, image, voice }

/// Media family of an attachment (Phase 9). Maps to the supported
/// file-type families; drives probing, compression dispatch and storage
/// layout.
enum MediaCategory {
  image,
  video,
  audio,
  voice,
  document,
  archive,
  binary,
  custom,
}

/// Lifecycle state of an attachment in the media catalog.
enum AttachmentStatus {
  staging,
  ready,
  transferring,
  downloading,
  complete,
  failed,
  purged,
}

/// Lifecycle state of a transfer session (persisted; never rename values).
enum TransferState {
  queued,
  transferring,
  paused,
  resuming,
  verifying,
  completed,
  failed,
  cancelled,
  expired;

  /// Persisted names of every terminal state (sweep filters).
  static const List<String> terminalNames = [
    'completed',
    'failed',
    'cancelled',
    'expired',
  ];
}

/// Which side of the wire a transfer session represents at this node.
enum TransferDirection { send, receive }

/// State of one chunk inside a transfer session ledger.
enum ChunkState { pending, inFlight, acknowledged, failed }

/// Rendering kind of a thumbnail.
enum ThumbnailKind { raster, probe }

/// Preview family of an attachment.
enum PreviewKind { image, video, document, audio, voice, binary }

/// Storage tier of a cache entry.
enum CacheKind { memory, disk, thumbnail, attachment }

/// Kind of a mesh packet.
enum PacketType { data, control, handshake, discovery, routeUpdate, ack }

/// Lifecycle state of a packet.
enum PacketStatus { pending, relayed, delivered, failed, expired }

/// Lifecycle state of a ratchet session.
enum SessionState { active, expired, closed }

/// Direction of a ratchet key relative to the local node.
enum SessionKeyDirection { outbound, inbound }

/// Presence state of a directly-observed neighbor.
enum NeighborStatus { discovered, connecting, connected, stale, lost }

/// State of an item in a processing queue.
enum QueueState { queued, processing, succeeded, failed }

/// State of a relay entry.
enum RelayState { queued, inFlight, relayed, dropped, expired }

/// Progress of a typing indicator event.
enum TypingKind { started, active, paused, stopped, timeout, idle }

/// Lifecycle of a delivery-receipt envelope as seen by its owner node.
enum ReceiptState { queued, sent, relayed, delivered, read, failed, duplicate }

/// How a `statistics` row is interpreted.
enum StatisticKind { counter, gauge }
