import 'dtn_envelope.dart';

/// Detailed step marker explaining why an envelope's state changed.
///
/// These are appended to [DtnEnvelope.debugHistory] and into the
/// diagnostics ring buffer; each event carries a stable kind (machine
/// readable) plus human text, both of which feed dev screens and logs.
final class DtnDiagnosticEvent {
  const DtnDiagnosticEvent({
    required this.kind,
    required this.packetId,
    required this.when,
    this.message,
    this.details = const {},
  });

  final DtnDiagnosticEventKind kind;
  final String? packetId;
  final DateTime when;
  final String? message;
  final Map<String, Object?> details;
}

/// Stable categories for one transition.
enum DtnDiagnosticEventKind {
  stored,
  attempt,
  fail,
  delivered,
  acked,
  expired,
  retried,
  forwarded,
  recovered,
  parked,
  unparked,
  ackRequest,
  ackTimeout,
  relayCandidate,
  connectivityChanged,
  sweepPruned,
  queueOverflow,
  rejectedPermanently,
}

/// A bounded ring of the latest diagnostic events (dev monitors only).
class DtnDiagnosticsRing {
  DtnDiagnosticsRing({this.capacity = 200});

  final int capacity;
  final List<DtnDiagnosticEvent> _events = [];
  int _total = 0;

  /// Total events ever recorded, regardless of the ring size.
  int get total => _total;

  int get length => _events.length;

  List<DtnDiagnosticEvent> get events =>
      List.unmodifiable(_events.reversed.toList());

  void log(DtnDiagnosticEvent event) {
    _total++;
    _events.add(event);
    if (_events.length > capacity) {
      _events.removeRange(0, _events.length - capacity);
    }
  }

  void logTransition(
    DtnDiagnosticEventKind kind,
    DtnPacket packet, {
    String? message,
    Map<String, Object?> details = const {},
  }) {
    log(
      DtnDiagnosticEvent(
        kind: kind,
        packetId: packet.packetId,
        when: DateTime.now(),
        message: message,
        details: details,
      ),
    );
  }
}
