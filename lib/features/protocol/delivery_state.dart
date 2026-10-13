/// What the thread may say about one outgoing message — the single
/// vocabulary for delivery in this app (I9.14.a).
///
/// Every value is earned from a fact the backend already knows: the
/// row's durable status, an attempt on the wire right now, or the
/// retry schedule the outbox keeps in memory. Nothing here is
/// inferred from time passing or guessed from optimism, so a state
/// shown in the thread is a claim the code can back.
enum DeliveryState {
  /// Written to the outbox and never attempted: no road has been
  /// tried yet.
  queued,

  /// An attempt is on the wire right now.
  transmitting,

  /// Left this device — the neighbour's radio took it, or a relay
  /// did. The recipient's handset has not confirmed anything.
  relayed,

  /// The recipient's handset confirmed it arrived.
  delivered,

  /// The recipient's owner opened the conversation it landed in.
  read,

  /// The last attempt failed on something a retry can fix, and one
  /// is scheduled under the backoff.
  retrying,

  /// Shed from the outbox before the recipient ever saw it.
  expired,

  /// Retired for good: no retry could fix this, and none is coming.
  failed,
}

/// The one place a row's facts become the thread's words.
///
/// [status] is the durable row status; [transmitting] and
/// [retryAttempts] are the in-memory facts only the transport holds,
/// because the database is never asked to lie for the few
/// milliseconds an attempt takes.
DeliveryState deliveryStateOf({
  required String status,
  required bool transmitting,
  required int retryAttempts,
}) {
  switch (status) {
    case 'expired':
      return DeliveryState.expired;
    case 'failed':
      return DeliveryState.failed;
    case 'read':
      return DeliveryState.read;
    case 'delivered':
      return DeliveryState.delivered;
    case 'sent':
      // The bytes left this device: a relay or the neighbour's radio
      // took them. Handing off is not arriving.
      return DeliveryState.relayed;
    case 'queued':
      if (transmitting) return DeliveryState.transmitting;
      if (retryAttempts > 0) return DeliveryState.retrying;
      return DeliveryState.queued;
    default:
      // A status this contract does not know — an incoming row, say,
      // which never asks — reads as plain queued. Never as delivered:
      // doubt is the honest direction to be wrong in.
      return DeliveryState.queued;
  }
}

/// The words shown under the bubble for [state], or null where the
/// icon alone is enough of an answer: the checks are read the same
/// way everywhere, and a caption on every delivered message would be
/// noise rather than truth.
String? deliveryLabelOf(DeliveryState state) {
  switch (state) {
    case DeliveryState.queued:
      return 'Queued';
    case DeliveryState.transmitting:
      return 'Sending…';
    case DeliveryState.retrying:
      return 'Retrying';
    case DeliveryState.expired:
      return 'Expired — never reached recipient';
    case DeliveryState.failed:
      return 'Failed';
    case DeliveryState.relayed:
    case DeliveryState.delivered:
    case DeliveryState.read:
      return null;
  }
}
