import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/core/database/cache/channel_cache.dart';
import 'package:onebit/core/database/cache/memory_cache.dart';
import 'package:onebit/core/database/database.dart';
import 'package:onebit/core/database/tables/enums.dart';

ChannelRow fakeChannelRow(String id) => ChannelRow(
  channelId: id,
  type: ChannelType.direct,
  createdAt: DateTime(2024),
  updatedAt: DateTime(2024),
  unreadCount: 0,
  archived: false,
  pinned: false,
  muted: false,
  lastSequence: 0,
  notificationPreference: 'all',
);

void main() {
  group('MemoryCache', () {
    test('getOrLoad caches and returns cached value', () async {
      final cache = MemoryCache<String, int>();
      var loads = 0;
      Future<int?> load() async {
        loads++;
        return 42;
      }

      expect(await cache.getOrLoad('a', load), 42);
      expect(await cache.getOrLoad('a', load), 42);
      expect(loads, 1);
    });

    test('single-flight: concurrent misses share one loader', () async {
      final cache = MemoryCache<String, int>();
      var loads = 0;
      final completer = Completer<int?>();

      Future<int?> loader() {
        loads++;
        return completer.future;
      }

      final a = cache.getOrLoad('a', loader);
      final b = cache.getOrLoad('a', loader);
      expect(loads, 1);

      completer.complete(7);
      expect(await a, 7);
      expect(await b, 7);
    });

    test('evicts least-recently-used entries', () async {
      final cache = MemoryCache<String, int>(maxEntries: 2);
      await cache.getOrLoad('a', () async => 1);
      await cache.getOrLoad('b', () async => 2);
      await cache.getOrLoad('c', () async => 3); // evicts least-recently-used
      expect(cache.get('a'), isNull);
      expect(cache.get('b'), 2);
      expect(cache.get('c'), 3);
    });

    test('TTL expires entries', () async {
      final cache = MemoryCache<String, int>(
        ttl: const Duration(milliseconds: 50),
      );
      cache.put('a', 1);
      expect(cache.get('a'), 1);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(cache.get('a'), isNull);
    });

    test('invalidate and clear', () async {
      final cache = MemoryCache<String, int>();
      cache.put('a', 1);
      cache.put('b', 2);
      cache.invalidate('a');
      expect(cache.get('a'), isNull);
      cache.invalidateWhere((k) => k == 'b');
      expect(cache.isEmpty, isTrue);

      cache.put('c', 3);
      cache.clear();
      expect(cache.isEmpty, isTrue);
    });

    test('null loader results are not cached', () async {
      final cache = MemoryCache<String, int>();
      var loads = 0;
      expect(
        await cache.getOrLoad('a', () async {
          loads++;
          return null;
        }),
        isNull,
      );
      expect(
        await cache.getOrLoad('a', () async {
          loads++;
          return null;
        }),
        isNull,
      );
      expect(loads, 2);
    });
  });

  group('typed caches', () {
    test('ChannelCache uses ChannelRow values', () async {
      final cache = ChannelCache();
      cache.put(fakeChannelRow('ch-1'));
      expect(cache.get('ch-1'), isNotNull);
      expect(await cache.getOrLoad('ch-1', () async => null), isNotNull);
      cache.invalidate('ch-1');
      expect(cache.get('ch-1'), isNull);
    });
  });
}
