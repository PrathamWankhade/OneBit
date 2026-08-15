import 'package:onebit/core/logger/app_logger.dart';
import 'package:onebit/core/logger/log_tags.dart';
import 'package:onebit/features/packet/domain/packet.dart';
import 'package:onebit/features/packet/domain/packet_id.dart';
import 'package:onebit/features/packet/domain/packet_reassembly_result.dart';
import 'package:onebit/features/packet/domain/packet_reassembly_state.dart';
import 'package:onebit/features/packet/fragmentation/packet_reassembler.dart';

/// Bounded, expiring cache of in-progress reassembly sessions.
///
/// Sessions are keyed by `(source, sequence, fragmentId)` so two fragment
/// runs that reuse a sequence never merge. Capacity and timeout are
/// configurable; a session that expires or is evicted is dropped entirely —
/// never delivered, never merged.
final class ReassemblyEngine {
  ReassemblyEngine({
    this.maxSessions = 32,
    this.timeout = const Duration(seconds: 30),
    this.reassembler = const PacketReassembler(),
    this.logger,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;

  /// Upper bound of live sessions.
  final int maxSessions;

  /// How long a session waits for its last fragment.
  final Duration timeout;

  /// Merges complete runs.
  final PacketReassembler reassembler;

  /// Optional logger (pure-Dart friendly).
  final AppLogger? logger;

  /// Clock source (injectable for tests).
  final DateTime Function() now;

  final Map<_SessionKey, ReassemblySession> _sessions = {};

  /// Number of live sessions.
  int get sessionCount => _sessions.length;

  /// Snapshot of live sessions (dev panels). Ordered by insertion; the
  /// values are the engine-owned session objects, read-only by convention.
  List<ReassemblySession> get sessions =>
      List<ReassemblySession>.unmodifiable(_sessions.values);

  /// Feeds [fragment] into its session and returns the outcome.
  ReassemblyOutcome accept(Packet fragment) {
    _sweep();

    final header = fragment.header;
    final key = _SessionKey(
      source: header.source,
      sequence: header.sequence,
      fragmentId: header.fragmentId,
    );

    final session = _sessions[key] ??= _openSession(key, fragment);
    if (header.fragmentIndex == 0) {
      session.firstFragment = fragment;
    }

    final stored = session.store(header.fragmentIndex, fragment.payload.bytes);
    if (!stored) {
      return ReassemblyWaiting(
        fragmentsPresent: session.fragmentsPresent,
        fragmentCount: session.fragmentCount,
      );
    }

    if (session.isComplete) {
      _sessions.remove(key);
      final first = session.firstFragment;
      final payload = session.assembleOrdered();
      if (first == null || payload == null) {
        return ReassemblyExpired(
          packetId: header.packetId,
          fragmentsPresent: session.fragmentsPresent,
          fragmentCount: session.fragmentCount,
        );
      }
      return ReassemblyComplete(reassembler.reassemble(first, payload));
    }

    return ReassemblyWaiting(
      fragmentsPresent: session.fragmentsPresent,
      fragmentCount: session.fragmentCount,
    );
  }

  /// Drops sessions past their timeout; returns how many were dropped.
  int sweepExpired() {
    final before = _sessions.length;
    _sweep();
    return before - _sessions.length;
  }

  ReassemblySession _openSession(_SessionKey key, Packet fragment) {
    final expired = _sessions.values
        .where((session) => session.isExpired)
        .toList();
    if (_sessions.length >= maxSessions && expired.isEmpty) {
      // Evict the strictly-oldest session; ties resolve to the one that was
      // inserted first (map iteration order), never the just-arriving one.
      MapEntry<_SessionKey, ReassemblySession>? oldest;
      for (final entry in _sessions.entries) {
        if (oldest == null ||
            entry.value.expiresAt.isBefore(oldest.value.expiresAt)) {
          oldest = entry;
        }
      }
      _sessions.remove(oldest!.key);
      logger?.warning(
        'reassembly session evicted at capacity (${fragment.header.packetId})',
        tag: LogTags.packet,
      );
    }
    return ReassemblySession(
      packetId: PacketId(
        source: fragment.header.source,
        sequence: fragment.header.sequence,
      ),
      fragmentId: fragment.header.fragmentId,
      fragmentCount: fragment.header.fragmentCount,
      expiresAt: now().add(timeout),
      now: now,
    );
  }

  void _sweep() {
    _sessions.removeWhere((key, session) {
      if (session.isExpired) {
        logger?.warning(
          'reassembly session expired (${session.packetId})',
          tag: LogTags.packet,
        );
        return true;
      }
      return false;
    });
  }
}

final class _SessionKey {
  const _SessionKey({
    required this.source,
    required this.sequence,
    required this.fragmentId,
  });

  final String source;
  final int sequence;
  final int fragmentId;

  @override
  bool operator ==(Object other) =>
      other is _SessionKey &&
      other.source == source &&
      other.sequence == sequence &&
      other.fragmentId == fragmentId;

  @override
  int get hashCode => Object.hash(source, sequence, fragmentId);
}
