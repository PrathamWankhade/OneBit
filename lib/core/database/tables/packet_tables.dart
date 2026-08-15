import 'package:drift/drift.dart';

import 'converters.dart';
import 'enums.dart';

/// A BLE mesh packet at rest.
///
/// `encryptedPayload` holds the app-layer ciphertext. Lifecycle is tracked
/// with `status` (spec fields plus lifecycle so relays never re-send
/// consumed packets); expiry drives the retention sweep.
@DataClassName('PacketRow')
@TableIndex(name: 'idx_packets_destination', columns: {#destination})
@TableIndex(name: 'idx_packets_source', columns: {#source})
@TableIndex(name: 'idx_packets_expires', columns: {#expiresAt})
class Packets extends Table {
  TextColumn get packetId => text()();

  TextColumn get packetType => textEnum<PacketType>()();

  TextColumn get source => text()();

  TextColumn get destination => text()();

  IntColumn get ttl => integer()();

  IntColumn get hopCount => integer().withDefault(const Constant(0))();

  IntColumn get fragmentCount => integer().withDefault(const Constant(1))();

  IntColumn get crc => integer().nullable()();

  TextColumn get priority =>
      textEnum<PriorityLevel>().withDefault(const Constant('normal'))();

  IntColumn get createdAt => integer().map(dateTimeMsConverter)();

  IntColumn get expiresAt =>
      integer().map(nullableDateTimeMsConverter).nullable()();

  BlobColumn get encryptedPayload => blob()();

  TextColumn get status =>
      textEnum<PacketStatus>().withDefault(const Constant('pending'))();

  @override
  Set<Column> get primaryKey => {packetId};
}

/// Fragments of a fragmented packet, stored for reassembly.
@DataClassName('PacketFragmentRow')
@TableIndex(name: 'idx_fragments_packet', columns: {#packetId, #sequence})
class PacketFragments extends Table {
  IntColumn get fragmentId => integer().autoIncrement()();

  TextColumn get packetId =>
      text().references(Packets, #packetId, onDelete: KeyAction.cascade)();

  IntColumn get sequence => integer()();

  BlobColumn get payload => blob()();

  BoolColumn get received => boolean().withDefault(const Constant(false))();

  IntColumn get receivedAt =>
      integer().map(nullableDateTimeMsConverter).nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
    <Column>{packetId, sequence},
  ];
}
