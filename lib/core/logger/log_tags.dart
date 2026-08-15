/// Standard log tags used across the application.
///
/// Tags keep log records searchable and groupable. Subsystems should use a
/// lettercase name; per-feature value that starts with the feature name
/// (e.g. `mesh.boot`, `storage.schema`).
abstract final class LogTags {
  /// General application lifecycle (bootstrap, shutdown, errors).
  static const String app = 'app';

  /// Configuration / environment resolution.
  static const String config = 'config';

  /// Platform bridges (method channels, FFI).
  static const String platform = 'platform';

  /// Local persistence layer (reserved for later phases).
  static const String storage = 'storage';

  /// Decentralized identity (creation, signing, backup, trust).
  static const String identity = 'identity';

  /// Mesh networking (discovery, routing, relay, topology).
  static const String mesh = 'mesh';

  /// Packet protocol (serialization, fragmentation, validation, engine).
  static const String packet = 'packet';

  /// Delay-tolerant store-and-forward layer (envelopes, queues, retry, ack).
  static const String dtn = 'dtn';

  /// Messaging engine (composer, outbox, ordering, receipts, typing,
  /// notifications, search).
  static const String messaging = 'messaging';

  /// Media engine (attachments, transfers, chunks, compression, thumbnails,
  /// previews, voice, cache).
  static const String media = 'media';

  /// Native C++ core (reserved for later phases).
  static const String native = 'native';

  const LogTags._();
}
