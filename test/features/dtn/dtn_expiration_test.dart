import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/features/dtn/expiration/packet_expiration_manager.dart';

import 'support/dtn_test_support.dart';

void main() {
  late DtnHarness h;
  late PacketExpirationManager expiration;

  setUp(() {
    h = DtnHarness();
    expiration = PacketExpirationManager(
      engine: h.engine,
      maxAge: const Duration(days: 30),
    );
  });

  test('sweepTtl removes only envelopes past their TTL', () {
    h.store('fresh', ttlSeconds: 3600);
    h.store('old', ttlSeconds: 10);
    h.clock.advance(const Duration(seconds: 11));

    final expired = expiration.sweepTtl();
    expect(expired.map((p) => p.packetId), ['old']);
    expect(h.engine.statusOf('old'), isNull);
    expect(h.engine.statusOf('fresh'), isNotNull);
  });

  test('sweepMaxAge removes envelopes older than the maximum age', () {
    h.store('ancient');
    h.clock.advance(const Duration(days: 31));
    final expired = expiration.sweepMaxAge();
    expect(expired.map((p) => p.packetId), ['ancient']);
  });

  test('expiringSoon lists envelopes within the window', () {
    h.store('short', ttlSeconds: 60);
    h.store('long', ttlSeconds: 86_400);
    final soon = expiration.expiringSoon(window: const Duration(hours: 1));
    expect(soon.map((p) => p.packetId), ['short']);
  });

  test('nextExpiration finds the closest deadline', () {
    h.store('short', ttlSeconds: 30);
    h.store('later', ttlSeconds: 500);
    final next = expiration.nextExpiration();
    expect(next, h.clock.now.add(const Duration(seconds: 30)));
  });

  test('expired packets count toward engine statistics', () {
    h.store('e1', ttlSeconds: 5);
    h.clock.advance(const Duration(seconds: 6));
    expiration.sweepTtl();
    expect(h.engine.statistics.snapshot().expired, 1);
  });

  test('sweep is a combined TTL + max-age pass', () {
    h.store('ttl-dead', ttlSeconds: 5);
    h.store('age-dead');
    h.clock.advance(const Duration(days: 31));
    final expired = expiration.sweep();
    expect(expired, hasLength(2));
    expect(h.engine.envelopes.where((p) => !p.isTerminal), isEmpty);
  });

  test('stats() surfaces expiration bookkeeping', () {
    h.store('near', ttlSeconds: 1800); // inside 1h window
    final stats = expiration.stats();
    expect(stats.expiringSoon, 1);
    expect(stats.nextExpiration, isNotNull);
  });
}
