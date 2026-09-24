/// I9.1 — Message delivery result types.
///
/// Defines the outcomes of a delivery attempt. The result answers
/// the immediate operation without pretending that delivery has
/// completed end-to-end.
///
/// ## Important: Accepted ≠ Delivered
///
/// If the delivery service accepts a message for delivery, that
/// does NOT mean the destination received it. End-to-end delivery
/// confirmation belongs to later increments.
library;

import 'package:onebit/features/message/models/message_id.dart';

/// The status of a delivery attempt.
enum DeliveryStatus {
  /// Message accepted for delivery processing.
  ///
  /// This does NOT mean delivered — it means the delivery service
  /// has accepted the request and will attempt delivery.
  accepted,

  /// No route to destination.
  noRoute,

  /// Message failed validation.
  invalid,

  /// Security or trust check failed.
  rejected,

  /// Message exceeded size limits.
  tooLarge,

  /// Message expired before delivery could begin.
  expired,

  /// Delivery service is disposed or unavailable.
  unavailable,
}

/// Result of submitting a message for delivery.
///
/// Contains enough information for the caller to know whether
/// the delivery service accepted the message for processing.
class MessageDeliveryResult {
  /// Message accepted for delivery.
  const MessageDeliveryResult.accepted(this.messageId)
      : status = DeliveryStatus.accepted,
        failureReason = null;

  /// No route to destination.
  const MessageDeliveryResult.noRoute(this.messageId)
      : status = DeliveryStatus.noRoute,
        failureReason = null;

  /// Message failed validation.
  const MessageDeliveryResult.invalid(this.messageId, String reason)
      : status = DeliveryStatus.invalid,
        failureReason = reason;

  /// Security or trust check failed.
  const MessageDeliveryResult.rejected(this.messageId, String reason)
      : status = DeliveryStatus.rejected,
        failureReason = reason;

  /// Message exceeded size limits.
  const MessageDeliveryResult.tooLarge(this.messageId)
      : status = DeliveryStatus.tooLarge,
        failureReason = null;

  /// Message expired before delivery could begin.
  const MessageDeliveryResult.expired(this.messageId)
      : status = DeliveryStatus.expired,
        failureReason = null;

  /// Delivery service is disposed or unavailable.
  const MessageDeliveryResult.unavailable(this.messageId)
      : status = DeliveryStatus.unavailable,
        failureReason = null;

  /// The message that was submitted.
  final MessageId messageId;

  /// The delivery status.
  final DeliveryStatus status;

  /// Human-readable failure reason, if applicable.
  final String? failureReason;

  /// Whether the message was accepted for delivery.
  bool get isAccepted => status == DeliveryStatus.accepted;

  /// Whether the delivery failed for a recoverable reason.
  bool get isRetryable =>
      status == DeliveryStatus.noRoute ||
      status == DeliveryStatus.unavailable;

  @override
  String toString() =>
      'MessageDeliveryResult(msg=${messageId.value.substring(0, 8)}..., '
      'status=${status.name}'
      '${failureReason != null ? ', reason=$failureReason' : ''})';
}
