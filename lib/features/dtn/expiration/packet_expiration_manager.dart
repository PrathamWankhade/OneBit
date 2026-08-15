import '../delivery/store_forward_engine.dart';
import '../domain/dtn_envelope.dart';

/// Manages packet expiration: TTL-based, age-based, and cleanup policies.
///
/// Coordinates with [StoreForwardEngine] for sweep operations and provides
/// statistics about the expiration bookkeeping. All time evaluation uses the
/// engine's own clock so tests remain deterministic.
final class PacketExpirationManager {
  PacketExpirationManager({
    required this._engine,
    this.maxAge = const Duration(days: 30),
    this.batchSize = 500,
  });

  final StoreForwardEngine _engine;
  final Duration maxAge;
  final int batchSize;

  /// Sweep for envelopes past their TTL.
  ///
  /// Returns the list of expired envelopes that were removed.
  List<DtnPacket> sweepTtl({DateTime? at}) {
    final now = at ?? _engine.now;
    final due = _engine.expiredDue(now);
    if (due.isNotEmpty) {
      _engine.expireAll(due, at: now);
    }
    return due;
  }

  /// Sweep for envelopes older than [maxAge] regardless of TTL.
  ///
  /// This handles edge cases where TTL was set very long but the envelope
  /// should still be cleaned up after a maximum age.
  List<DtnPacket> sweepMaxAge({DateTime? at}) {
    final now = at ?? _engine.now;
    final cutoff = now.subtract(maxAge);
    final due = _engine.envelopes
        .where((p) => !p.isTerminal && p.createdAt.isBefore(cutoff))
        .toList();
    if (due.isNotEmpty) {
      _engine.expireAll(due, at: now);
    }
    return due;
  }

  /// Combined sweep: TTL first, then max-age.
  List<DtnPacket> sweep({DateTime? at}) {
    final ttlExpired = sweepTtl(at: at);
    final ageExpired = sweepMaxAge(at: at);
    return [...ttlExpired, ...ageExpired];
  }

  /// Get envelopes that will expire soon (within [window]).
  List<DtnPacket> expiringSoon({
    Duration window = const Duration(hours: 1),
    DateTime? at,
  }) {
    final now = at ?? _engine.now;
    final deadline = now.add(window);
    return _engine.envelopes
        .where(
          (p) =>
              !p.isTerminal &&
              p.expiresAt.isBefore(deadline) &&
              p.expiresAt.isAfter(now),
        )
        .toList()
      ..sort((a, b) => a.expiresAt.compareTo(b.expiresAt));
  }

  /// Next absolute expiration time across all live envelopes.
  DateTime? nextExpiration({DateTime? at}) {
    final now = at ?? _engine.now;
    DateTime? next;
    for (final p in _engine.envelopes) {
      if (p.isTerminal) {
        continue;
      }
      if (p.expiresAt.isAfter(now) &&
          (next == null || p.expiresAt.isBefore(next))) {
        next = p.expiresAt;
      }
    }
    return next;
  }

  /// Statistics about expiration state.
  ExpirationStats stats({DateTime? at}) {
    final now = at ?? _engine.now;
    var ttlExpired = 0, ageExpired = 0, expiringSoon = 0;
    for (final p in _engine.envelopes) {
      if (p.isTerminal) continue;
      if (p.expiresAt.isBefore(now)) {
        ttlExpired++;
      } else if (p.createdAt.isBefore(now.subtract(maxAge))) {
        ageExpired++;
      } else if (p.expiresAt.isBefore(now.add(const Duration(hours: 1)))) {
        expiringSoon++;
      }
    }
    return ExpirationStats(
      ttlExpired: ttlExpired,
      ageExpired: ageExpired,
      expiringSoon: expiringSoon,
      nextExpiration: nextExpiration(at: now),
      evaluatedAt: now,
    );
  }
}

/// Snapshot of expiration state.
final class ExpirationStats {
  const ExpirationStats({
    required this.ttlExpired,
    required this.ageExpired,
    required this.expiringSoon,
    required this.nextExpiration,
    required this.evaluatedAt,
  });

  final int ttlExpired;
  final int ageExpired;
  final int expiringSoon;
  final DateTime? nextExpiration;
  final DateTime evaluatedAt;

  @override
  String toString() =>
      'ExpirationStats(ttl:$ttlExpired age:$ageExpired soon:$expiringSoon next:$nextExpiration)';
}
