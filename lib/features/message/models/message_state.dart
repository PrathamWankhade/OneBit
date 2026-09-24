/// I9.1 — Message lifecycle state machine.
///
/// Defines the finite set of states a message can occupy during
/// its delivery lifecycle. State transitions are deterministic and
/// produce new state rather than mutating identity fields.
///
/// ## Lifecycle
///
/// ```text
///           CREATE
///             │
///             ▼
///          CREATED
///             │
///             ▼
///           QUEUED
///             │
///             ▼
///       ROUTE_LOOKUP
///         │       │
///      route    no route
///         │       │
///         ▼       ▼
///       READY   NO_ROUTE
///         │
///         ▼
///    TRANSMITTING
///         │
///      ┌──┴──┐
///      │     │
///    local  remote
///      │     │
///      ▼     ▼
///  DELIVERED RELAYING
///                │
///                ▼
///            next hop
/// ```
///
/// ## Failure States
///
/// - `NO_ROUTE` — no route available (may recover)
/// - `FAILED` — delivery cannot continue
/// - `EXPIRED` — message exceeded allowed lifetime
/// - `REJECTED` — failed validation or security check
library;

/// The lifecycle state of a OneBit message.
///
/// Each value represents a distinct phase in the delivery pipeline.
/// State transitions are managed by the delivery service — messages
/// do not transition themselves.
enum MessageState {
  /// Message has been constructed locally but not yet submitted.
  created,

  /// Message is waiting for delivery processing.
  ///
  /// In I9.1 this is conceptual — no persistent queue is implemented.
  queued,

  /// Delivery layer is requesting route information from I8.
  routeLookup,

  /// A usable route/next hop has been identified.
  ready,

  /// Message is being handed to the transport layer.
  ///
  /// Actual transmission belongs to later increments.
  transmitting,

  /// An intermediate node is processing a message not destined
  /// for itself. Relay implementation belongs to I9.5.
  relaying,

  /// The destination has successfully accepted the message.
  ///
  /// In I9.1, "delivered" means accepted by the transport —
  /// end-to-end delivery confirmation belongs to later increments.
  delivered,

  /// No currently usable route exists.
  ///
  /// This is distinct from [failed] — a no-route message may
  /// recover when topology changes (important for store-and-forward).
  noRoute,

  /// Delivery attempt cannot continue for a non-routing reason.
  failed,

  /// Message exceeded its allowed lifetime.
  expired,

  /// Message failed validation or security checks.
  rejected,
}
