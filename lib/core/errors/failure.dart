import 'package:flutter/foundation.dart';
import 'package:onebit/core/constants/app_error_codes.dart';

/// The base of the failure hierarchy.
///
/// A [Failure] is a **value**, not an `Exception`. It travels inside a
/// `Result<T>` across repository and use-case boundaries. Exceptions are
/// captured exactly once at platform/data edges and converted into failures
/// via `ExceptionMapper`, so business code never catches raw errors and
/// never needs `try/catch` blocks.
///
/// Adding a new failure type: extend this sealed hierarchy in this file (or
/// a dedicated file) and register its mapping in [ExceptionMapper]. Do not
/// push raw `Exception`s upward — convert them at the boundary.
@immutable
sealed class Failure {
  const Failure({
    required this.kind,
    this.message,
    this.cause,
    this.stackTrace,
  });

  /// Stable category used for logging, diagnostics and UI mapping.
  final AppErrorCode kind;

  /// Human-readable detail, safe to show to a developer in the developer
  /// panel. Never assume end-user consumers will see it.
  final String? message;

  /// The original thrown object, when one exists.
  final Object? cause;

  /// Stack trace captured at the failure site, when available.
  final StackTrace? stackTrace;

  /// True when the failure is caused by an [UnsupportedError]-style gap that
  /// a later phase is expected to close.
  bool get isUnsupported => kind == AppErrorCode.unsupported;

  @override
  String toString() =>
      '${kind.code}${message == null ? '' : ' — $message'}'
              '${stackTrace == null ? '' : ' @ $stackTrace'}'
          .trim();
}

/// A failure outside every recognized category.
@immutable
final class UnexpectedFailure extends Failure {
  const UnexpectedFailure({super.message, super.cause, super.stackTrace})
    : super(kind: AppErrorCode.unexpected);
}

/// Local storage (database, file system) could not satisfy a request.
@immutable
final class StorageFailure extends Failure {
  const StorageFailure({
    super.message,
    super.cause,
    super.stackTrace,
    this.operation,
  }) : super(kind: AppErrorCode.storage);

  /// Short name of the failing storage operation (e.g. `open`, `write`).
  final String? operation;
}

/// The device platform rejected or failed a native invocation.
@immutable
final class PlatformFailure extends Failure {
  const PlatformFailure({
    super.message,
    super.cause,
    super.stackTrace,
    this.method,
  }) : super(kind: AppErrorCode.platform);

  /// Name of the channel/FFI method that failed, when known.
  final String? method;
}

/// A payload could not be parsed or serialized into a model.
@immutable
final class SerializationFailure extends Failure {
  const SerializationFailure({
    super.message,
    super.cause,
    super.stackTrace,
    this.source,
  }) : super(kind: AppErrorCode.serialization);

  /// Describes the offending payload, e.g. `MeshPacket#decode`.
  final String? source;
}

/// Runtime configuration is invalid, contradictory, or incomplete.
@immutable
final class ConfigurationFailure extends Failure {
  const ConfigurationFailure({super.message, super.cause, super.stackTrace})
    : super(kind: AppErrorCode.configuration);
}

/// A requested capability is intentionally not provided in this build.
///
/// Used by bridges that are declared but whose native backing (BLE stack,
/// FFI core) arrives in a later phase. Treating this as an *expected*
/// failure keeps the rest of the system honest instead of fabricating data.
@immutable
final class UnsupportedOperationFailure extends Failure {
  const UnsupportedOperationFailure({
    super.message,
    super.cause,
    super.stackTrace,
    this.feature,
  }) : super(kind: AppErrorCode.unsupported);

  /// Identifier of the feature that is not yet wired (e.g. `bluetooth`).
  final String? feature;
}

/// A long-running asynchronous operation was cancelled by the caller.
@immutable
final class CancelledFailure extends Failure {
  const CancelledFailure({super.message, super.cause, super.stackTrace})
    : super(kind: AppErrorCode.cancellation);
}

/// The decentralized identity is missing, invalid, or not yet created.
///
/// Distinct from [PlatformFailure]: an identity may be absent from *both* the
/// secure key store and the metadata store (fresh install), or contradictory
/// between them (partially restored backup).
@immutable
final class IdentityFailure extends Failure {
  const IdentityFailure({
    super.message,
    super.cause,
    super.stackTrace,
    this.code,
  }) : super(kind: AppErrorCode.identity);

  /// Stable short identifier for tooling, e.g. `identity.not_created`.
  final String? code;
}

/// A cryptographic primitive rejected an input or failed mid-operation.
@immutable
final class CryptoFailure extends Failure {
  const CryptoFailure({
    super.message,
    super.cause,
    super.stackTrace,
    this.operation,
  }) : super(kind: AppErrorCode.crypto);

  /// Short name of the failing operation (e.g. `sign`, `encrypt`).
  final String? operation;
}

/// An encrypted backup document could not be produced or verified.
@immutable
final class BackupFailure extends Failure {
  const BackupFailure({
    super.message,
    super.cause,
    super.stackTrace,
    this.operation,
  }) : super(kind: AppErrorCode.backup);

  /// Short name of the failing phase (e.g. `export`, `import`, `parse`).
  final String? operation;
}

/// A packet-protocol frame violated a named validation rule.
///
/// [rule] is the stable rule id from the protocol spec (`02-protocol-
/// specification.md`, rules 1–14) so diagnostics can point at the exact
/// boundary that failed.
@immutable
final class PacketValidationFailure extends Failure {
  const PacketValidationFailure({
    required this.rule,
    super.message,
    super.cause,
    super.stackTrace,
  }) : super(kind: AppErrorCode.packet);

  /// Name of the violated rule (e.g. `crc32Valid`, `fragmentIndexCovered`).
  final String rule;
}

/// A fragmented packet could not be reassembled (timeout, limit, mismatch).
@immutable
final class PacketReassemblyFailure extends Failure {
  const PacketReassemblyFailure({
    required this.phase,
    super.message,
    super.cause,
    super.stackTrace,
  }) : super(kind: AppErrorCode.packet);

  /// Short phase name (`collect`, `timeout`, `limit`, `merge`).
  final String phase;
}

/// An authenticated packet failed signature verification.
@immutable
final class PacketVerificationFailure extends Failure {
  const PacketVerificationFailure({
    super.message,
    super.cause,
    super.stackTrace,
    this.reason,
  }) : super(kind: AppErrorCode.packet);

  /// Optional detail (e.g. `signatureMissing`, `signatureMismatch`).
  final String? reason;
}

// ---- Messaging engine failures (Phase 8) ---------------------------------

/// A messaging operation was rejected by validation.
///
/// [reason] is a stable machine-readable identifier for tooling.
@immutable
final class MessageValidationFailure extends Failure {
  const MessageValidationFailure({
    required this.reason,
    super.message,
    super.cause,
    super.stackTrace,
  }) : super(kind: AppErrorCode.messaging);

  /// e.g. `emptyBody`, `tooLong`, `unknownChannel`, `unsupportedType`.
  final String reason;
}

/// A message lifecycle transition was refused (status cannot regress).
@immutable
final class MessageTransitionFailure extends Failure {
  const MessageTransitionFailure({
    required this.from,
    required this.to,
    super.message,
  }) : super(kind: AppErrorCode.messaging);

  final String from;
  final String to;
}

/// A messaging operation referenced a message or channel that does not
/// exist (or has already reached a terminal state).
@immutable
final class MessageNotFoundFailure extends Failure {
  const MessageNotFoundFailure({required this.packetId, super.message})
    : super(kind: AppErrorCode.messaging);

  final String packetId;
}

// ---- Media engine failures (Phase 9) -------------------------------------

/// A media operation was rejected by validation.
///
/// [reason] is a stable machine-readable identifier for tooling.
@immutable
final class MediaValidationFailure extends Failure {
  const MediaValidationFailure({
    required this.reason,
    super.message,
    super.cause,
    super.stackTrace,
  }) : super(kind: AppErrorCode.media);

  /// e.g. `tooLarge`, `unsupportedType`, `badExtension`, `corruptInline`.
  final String reason;
}

/// A media operation referenced an attachment, session or recording that
/// does not exist (or has reached a terminal state).
@immutable
final class MediaNotFoundFailure extends Failure {
  const MediaNotFoundFailure({
    required this.id,
    super.message,
    super.cause,
    super.stackTrace,
  }) : super(kind: AppErrorCode.media);

  /// The missing attachment / session / thumbnail / recording id.
  final String id;
}

/// A transfer lifecycle transition was refused (state cannot regress).
@immutable
final class MediaTransitionFailure extends Failure {
  const MediaTransitionFailure({
    required this.from,
    required this.to,
    super.message,
  }) : super(kind: AppErrorCode.media);

  final String from;
  final String to;
}

/// A file-system operation of the media subsystem failed.
@immutable
final class MediaStorageFailure extends Failure {
  const MediaStorageFailure({
    super.message,
    super.cause,
    super.stackTrace,
    this.operation,
  }) : super(kind: AppErrorCode.media);

  /// Short name of the failing operation (e.g. `stage`, `finalize`).
  final String? operation;
}

/// A transfer failed its integrity verification (chunk or whole-file hash).
@immutable
final class MediaIntegrityFailure extends Failure {
  const MediaIntegrityFailure({
    super.message,
    super.cause,
    super.stackTrace,
    this.scope,
  }) : super(kind: AppErrorCode.media);

  /// `chunk` or `file`.
  final String? scope;
}

/// The network edge (DTN store/transmit) rejected a media envelope.
@immutable
final class MediaNetworkFailure extends Failure {
  const MediaNetworkFailure({super.message, super.cause, super.stackTrace})
    : super(kind: AppErrorCode.dtn);
}
