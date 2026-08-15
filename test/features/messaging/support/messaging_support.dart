import 'dart:async';

import 'package:drift/native.dart';
import 'package:onebit/core/database/database.dart';
import 'package:onebit/core/logger/app_logger.dart';
import 'package:onebit/core/logger/log_filter.dart';
import 'package:onebit/core/logger/log_output.dart';
import 'package:onebit/core/logger/log_record.dart';
import 'package:onebit/features/dtn/domain/dtn_envelope.dart';
import 'package:onebit/features/dtn/domain/dtn_failure.dart';
import 'package:onebit/features/dtn/domain/dtn_queue_snapshot.dart';
import 'package:onebit/features/dtn/domain/dtn_repository.dart';
import 'package:onebit/features/dtn/domain/dtn_statistics.dart';

/// A logger that swallows everything — tests assert on results, not logs.
final AppLogger silentLogger = AppLogger(
  filter: const AllowAllLogFilter(),
  output: _SilentLogOutput(),
);

final class _SilentLogOutput implements LogOutput {
  @override
  void write(LogRecord record) {}

  @override
  void dispose() {}
}

/// Opens a fresh in-memory database with the full 31-table schema.
Future<OneBitDatabase> openInMemoryDb() async =>
    OneBitDatabase(NativeDatabase.memory());

/// A scriptable [DTNRepository] for engine tests.
///
/// `store()` records envelopes into [stored]; `deliver(outbound)` feeds the
/// `observeDelivered` seam so tests can simulate inbound traffic, receipts
/// and typing beacons without a mesh.
final class FakeDtnRepository implements DTNRepository {
  final List<DtnPacket> stored = [];
  final List<DtnPacket> delivered = [];
  final List<String> cancelled = [];

  Completer<DtnPacket>? _waiter;
  bool _closed = false;

  /// Called for every packet handed to `store()` (tests may wire peers).
  void Function(DtnPacket packet)? onStore;

  /// Called when [observeDelivered] is waiting for the next packet.
  void Function()? onWaiting;

  @override
  Future<DtnPacket> store(DtnPacket packet) async {
    stored.add(packet);
    onStore?.call(packet);
    return packet;
  }

  @override
  Future<bool> cancel(String packetId) async {
    cancelled.add(packetId);
    return true;
  }

  @override
  Future<DtnPacket?> statusOf(String packetId) async =>
      stored.where((p) => p.packetId == packetId).firstOrNull;

  @override
  Future<DtnPacket> observeDelivered() {
    if (delivered.isNotEmpty) return Future.value(delivered.removeAt(0));
    if (_closed) {
      return Future.error(DtnFailure.notFound('closed'));
    }
    final completer = Completer<DtnPacket>();
    _waiter = completer;
    onWaiting?.call();
    return completer.future;
  }

  /// Hands a packet to the next `observeDelivered` caller, or queues it
  /// when none is waiting.
  void deliver(DtnPacket packet) {
    final waiter = _waiter;
    if (waiter != null) {
      _waiter = null;
      waiter.complete(packet);
    } else {
      delivered.add(packet);
    }
  }

  /// Releases a pending `observeDelivered` so the inbound pump can exit.
  void close() {
    _closed = true;
    final waiter = _waiter;
    if (waiter != null) {
      _waiter = null;
      waiter.completeError(DtnFailure.notFound('pump stopped'));
    }
  }

  @override
  Stream<DtnQueueSnapshot> queueSnapshots() => const Stream.empty();

  @override
  Stream<DtnStatisticsSnapshot> statisticsSnapshots() => const Stream.empty();

  @override
  DtnStatisticsSnapshot get latestStatistics => DtnStatisticsSnapshot.empty;
}
