/// Stable machine-readable identifiers for every failure category.
///
/// Codes are written to logs and surfaced in diagnostics so support and
/// CI can correlate failures without depending on human-readable messages.
enum AppErrorCode {
  /// A failure outside every known category.
  unexpected('OB-UX-0001'),

  /// Local storage (database/file) could not be read or written.
  storage('OB-ST-0002'),

  /// The device platform rejected a native invocation.
  platform('OB-PL-0003'),

  /// A payload could not be parsed or serialized.
  serialization('OB-SZ-0004'),

  /// The runtime configuration is invalid or inconsistent.
  configuration('OB-CF-0005'),

  /// A capability is not wired up in this build (reserved for later phases).
  unsupported('OB-UN-0006'),

  /// An asynchronous operation was cancelled.
  cancellation('OB-CN-0007'),

  /// The local identity is missing, corrupted, or not yet created.
  identity('OB-ID-0008'),

  /// A cryptographic operation failed or produced invalid material.
  crypto('OB-CR-0009'),

  /// An encrypted backup could not be produced or restored.
  backup('OB-BK-0010'),

  /// A packet protocol frame failed validation, reassembly or verification.
  packet('OB-PK-0011'),

  /// The delay-tolerant networking layer rejected a store, delivery,
  /// persistence or recovery operation.
  dtn('OB-DT-0012'),

  /// The messaging layer rejected a composition, transition, receipt or
  /// channel operation.
  messaging('OB-MS-0013'),

  /// The media layer rejected an attachment, transfer, compression,
  /// thumbnail, preview or caching operation.
  media('OB-MD-0014');

  const AppErrorCode(this.code);

  /// Stable, human-unfriendly identifier (safe for logs and bug reports).
  final String code;
}
