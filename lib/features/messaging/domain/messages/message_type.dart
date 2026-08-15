/// Content kind of a message.
///
/// The enum is deliberately wider than the supported set: media, voice and
/// file are declared contracts that later phases fill in without touching
/// the messaging engine's shape.
enum MessageType {
  /// Plain text.
  text,

  /// Markdown-formatted text (rendered by the UI).
  markdown,

  /// System messages (channel events rendered inline).
  system,

  /// Internal notification payloads.
  notification,

  /// Identity card exchange payload.
  identity,

  /// Key-exchange / ratchet handshake payload.
  handshake,

  /// Delivery or read receipt payload.
  receipt,

  /// Developer-console traffic.
  developer,

  /// Future: media payloads.
  media,

  /// Future: voice payloads.
  voice,

  /// Future: file payloads.
  file;

  /// Stable persistence name (shared vocabulary with the core schema).
  String get wireName => name;

  /// Maps a persisted core-schema name into the domain kind.
  static MessageType? fromWireName(String name) => switch (name) {
    'attachment' => MessageType.media,
    'voiceNote' => MessageType.voice,
    'control' => MessageType.system,
    _ => MessageType.values.where((t) => t.name == name).firstOrNull,
  };
}
