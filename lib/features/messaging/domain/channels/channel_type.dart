/// Kind of a logical conversation channel.
///
/// `private` is the only first-class supported kind in this phase. The
/// remaining kinds are declared contracts the engine already accommodates
/// (recipient geometry, fan-out and policy), so they require no redesign.
enum ChannelType {
  /// 1:1 conversation between two node ids — fully supported.
  private,

  /// Multi-recipient conversation (future; outbox fans out per recipient).
  group,

  /// One-to-many announcement channel (future).
  broadcast,

  /// Life-safety channel that demands delivery (future).
  emergency,

  /// Local developer console channel.
  developer;

  bool get isSupported => this == ChannelType.private;

  /// Stable persistence name (shared vocabulary with the core schema).
  String get wireName => name;

  /// Maps a persisted core-schema name into the domain kind.
  static ChannelType? fromWireName(String name) => switch (name) {
    'direct' => ChannelType.private,
    _ => ChannelType.values.where((t) => t.name == name).firstOrNull,
  };
}
