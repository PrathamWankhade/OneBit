import '../../../core/constants/app_error_codes.dart';

/// A structured failure of a DTN operation.
///
/// Mirror of the Phase 4–6 `AppException` convention but kept separate so
/// the DTN layer never leaks generic plumbing into application-code
/// contract failures: `appErrorCode` is always `AppErrorCode.dtn` unless the
/// failure is a persistence problem.
final class DtnFailure implements Exception {
  const DtnFailure({
    required this.kind,
    this.code = AppErrorCode.dtn,
    this.message,
    this.cause,
    this.details,
  });

  /// Root cause category (data, persistence, transport, routing).
  final AppErrorCode code;

  /// DTN-layer failure kind (see [DtnFailureKind]).
  final DtnFailureKind kind;

  /// Human-readable detail.
  final String? message;

  /// The underlying exception, when one exists.
  final Object? cause;

  /// Machine-readable diagnostic payload (e.g. the offending packet id).
  final Map<String, Object?>? details;

  static DtnFailure queueOverflow(int limit) => DtnFailure(
    kind: DtnFailureKind.queueOverflow,
    message: 'DTN live envelope limit reached ($limit)',
  );

  static DtnFailure notFound(String packetId) => DtnFailure(
    kind: DtnFailureKind.notFound,
    message: 'No DTN envelope with id $packetId',
    details: {'packetId': packetId},
  );

  static DtnFailure alreadyTerminal(String packetId) => DtnFailure(
    kind: DtnFailureKind.alreadyTerminal,
    message: 'Packet $packetId is already in a terminal state',
    details: {'packetId': packetId},
  );

  static DtnFailure invalidRequest(String packetId, String reason) =>
      DtnFailure(
        kind: DtnFailureKind.invalidRequest,
        message: reason,
        details: {'packetId': packetId},
      );

  static DtnFailure transport(Object cause) => DtnFailure(
    kind: DtnFailureKind.transportError,
    message: 'Mesh transport rejected the attempt',
    cause: cause,
  );

  static DtnFailure persistenceError(Object cause, [String? context]) =>
      DtnFailure(
        kind: DtnFailureKind.persistenceFailed,
        message: context ?? 'Persisting DTN state failed',
        cause: cause,
      );

  @override
  String toString() =>
      'DtnFailure(${code.code}:${kind.name})${message != null ? ': $message' : ''}';
}

/// Precise category of a DTN-layer failure.
enum DtnFailureKind {
  /// `store()` was denied because the live envelope cap was reached.
  queueOverflow,

  /// The referenced packet does not exist.
  notFound,

  /// The packet is `delivered`/`expired`/`failed` and cannot change state.
  alreadyTerminal,

  /// The caller violated a contract (bad id, bad TTL, wrong-role ack).
  invalidRequest,

  /// The mesh layer rejected a transmit.
  transportError,

  /// The packet store could not fulfil a read/write.
  persistenceFailed,
}
