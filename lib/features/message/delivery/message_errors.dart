/// I9.1 — Message delivery error types.
///
/// Small, meaningful error categories for message operations.
/// Each error represents a specific failure mode that callers
/// can handle appropriately.
library;

/// Base class for message delivery errors.
///
/// All message errors carry a human-readable [message] and
/// an optional [code] for programmatic handling.
class MessageError implements Exception {
  const MessageError(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => 'MessageError($message)';
}

/// Message structure is malformed.
class InvalidMessageError extends MessageError {
  const InvalidMessageError(super.message, {super.code});
}

/// Destination PeerId is invalid or empty.
class InvalidDestinationError extends MessageError {
  const InvalidDestinationError(super.message)
      : super(code: 'INVALID_DESTINATION');
}

/// Source PeerId is invalid or empty.
class InvalidSourceError extends MessageError {
  const InvalidSourceError(super.message) : super(code: 'INVALID_SOURCE');
}

/// No route exists to the destination.
class NoRouteError extends MessageError {
  const NoRouteError(super.message) : super(code: 'NO_ROUTE');
}

/// Message protocol version is not supported.
class UnsupportedVersionError extends MessageError {
  const UnsupportedVersionError(super.message)
      : super(code: 'UNSUPPORTED_VERSION');
}

/// Message payload exceeds size limits.
class MessageTooLargeError extends MessageError {
  const MessageTooLargeError(super.message) : super(code: 'MESSAGE_TOO_LARGE');
}

/// Message failed security or trust validation.
class SecurityRejectedError extends MessageError {
  const SecurityRejectedError(super.message)
      : super(code: 'SECURITY_REJECTED');
}
