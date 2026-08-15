import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/features/dtn/delivery/dtn_config.dart';
import 'package:onebit/features/dtn/domain/dtn_priority.dart';

import 'support/dtn_test_support.dart';

void main() {
  group('stress: large offline queue survives and drains', () {
    test(
      '2000 envelopes offline for a day survive a restart, then deliver',
      () async {
        final h = DtnHarness(
          config: const DtnEngineConfig(
            batchLimit: 64,
            retryPolicy: DtnRetryPolicy(
              baseDelay: Duration(seconds: 2),
              factor: 1,
              maxDelay: Duration(seconds: 2),
              jitterRatio: 0,
              limit: 12,
            ),
          ),
        );
        h.gateway.reachable = false;

        for (var i = 0; i < 2000; i++) {
          h.store('m$i', ttlSeconds: 3600);
        }
        h.clock.advance(const Duration(hours: 24));

        // Nothing expired after a day.
        expect(h.engine.statistics.snapshot().expired, 0);

        // "Reboot": restore from the same persistence into a fresh engine.
        final persisted = await h.engine.persistence.loadAll();
        expect(persisted, hasLength(2000));

        final h2 = DtnHarness();
        h2.engine.restore(persisted);
        h2.engine.start();

        // Drain while reachable.
        h2.gateway.reachable = true;
        var iterations = 0;
        while (h2.engine.snapshot().live > 0 && iterations < 500) {
          h2.clock.advance(const Duration(seconds: 1));
          h2.tick();
          iterations++;
        }

        expect(h2.engine.statistics.snapshot().delivered, 2000);
        expect(h2.engine.snapshot().live, 0);
      },
    );
  });

  group('Stress', () {
    test('priority storm drains critical first', () {
      final h = DtnHarness(config: const DtnEngineConfig(batchLimit: 8));
      h.gateway.reachable = true;

      for (var i = 0; i < 100; i++) {
        h.store('bg$i', priority: DtnPriority.background);
      }
      for (var i = 0; i < 20; i++) {
        h.store('crit$i', priority: DtnPriority.critical);
      }

      // Drain.
      var iterations = 0;
      while (h.engine.snapshot().live > 0 && iterations < 400) {
        h.clock.advance(const Duration(seconds: 1));
        h.tick();
        iterations++;
      }

      final transmitted = h.gateway.transmitted;
      // No critical packet waited behind a background packet.
      var lastCritical = -1, firstBackground = 1 << 30;
      for (var i = 0; i < transmitted.length; i++) {
        final id = transmitted[i].packetId;
        if (id.startsWith('crit')) {
          lastCritical = i;
        } else if (id.startsWith('bg')) {
          firstBackground = firstBackground < i ? firstBackground : i;
        }
      }
      expect(lastCritical, lessThan(firstBackground));
      expect(h.engine.statistics.snapshot().delivered, 120);
    });
  });
}
