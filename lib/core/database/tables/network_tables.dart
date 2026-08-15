import 'package:drift/drift.dart';

import 'converters.dart';
import 'enums.dart';

/// A route to a destination node via a next hop.
@DataClassName('RouteRow')
@TableIndex(name: 'idx_routes_next_hop', columns: {#nextHop})
@TableIndex(name: 'idx_routes_quality', columns: {#quality})
class Routes extends Table {
  TextColumn get destination => text()();

  /// Neighbor node id the packet is handed to next.
  TextColumn get nextHop => text()();

  IntColumn get hopCount => integer()();

  /// 0.0..1.0 route quality estimate.
  RealColumn get quality => real()();

  IntColumn get lastUpdated => integer().map(dateTimeMsConverter)();

  IntColumn get expiration =>
      integer().map(nullableDateTimeMsConverter).nullable()();

  @override
  Set<Column> get primaryKey => {destination};
}

/// A directly-observed neighbor on the mesh.
@DataClassName('NeighborRow')
@TableIndex(name: 'idx_neighbors_last_seen', columns: {#lastSeen})
@TableIndex(name: 'idx_neighbors_status', columns: {#status})
class Neighbors extends Table {
  TextColumn get node => text()();

  IntColumn get rssi => integer().nullable()();

  IntColumn get lastSeen => integer().map(dateTimeMsConverter)();

  BlobColumn get advertisement => blob().nullable()();

  IntColumn get distance => integer().nullable()();

  TextColumn get status =>
      textEnum<NeighborStatus>().withDefault(const Constant('discovered'))();

  @override
  Set<Column> get primaryKey => {node};
}
