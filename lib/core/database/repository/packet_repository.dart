import 'package:onebit/core/database/dao/packet_dao.dart';
import 'package:onebit/core/database/database.dart';
import 'package:onebit/core/database/repository/result_guards.dart';
import 'package:onebit/core/database/tables/enums.dart';
import 'package:onebit/core/logger/app_logger.dart';
import 'package:onebit/core/result/result.dart';

/// Repository for packets and their fragments.
final class PacketRepository {
  PacketRepository({required this._dao, required this._logger});

  final PacketDao _dao;
  final AppLogger _logger;

  static const _tag = 'packet.dao';

  /// Inserts a packet and its fragments in one transaction.
  Future<Result<void>> insertPacketWithFragments(
    PacketRow packet,
    List<PacketFragmentRow> fragments,
  ) => ResultGuards.guard(
    _logger,
    '$_tag.insertPacketWithFragments',
    () => _dao.insertPacketWithFragments(packet, fragments),
  );

  Future<Result<PacketRow?>> getPacket(String packetId) => ResultGuards.guard(
    _logger,
    '$_tag.getPacket',
    () => _dao.getPacket(packetId),
  );

  Future<Result<int>> insertPacket(PacketRow row) => ResultGuards.guard(
    _logger,
    '$_tag.insertPacket',
    () => _dao.insertPacket(row),
  );

  Future<Result<int>> updatePacketStatus(
    String packetId,
    PacketStatus status,
  ) => ResultGuards.guard(
    _logger,
    '$_tag.updatePacketStatus',
    () => _dao.updatePacketStatus(packetId, status),
  );

  /// Packets due for transmission, highest priority first.
  Future<Result<List<PacketRow>>> pendingPackets({
    int limit = 100,
    DateTime? now,
  }) => ResultGuards.guard(
    _logger,
    '$_tag.pendingPackets',
    () => _dao.pendingPackets(limit: limit, now: now),
  );

  /// Packets whose TTL expired (returns them; the caller deletes).
  Future<Result<List<PacketRow>>> expirePackets({
    DateTime? now,
    int limit = 500,
  }) => ResultGuards.guard(
    _logger,
    '$_tag.expirePackets',
    () => _dao.expirePackets(now: now, limit: limit),
  );

  Future<Result<int>> deletePackets(List<String> packetIds) =>
      ResultGuards.guard(
        _logger,
        '$_tag.deletePackets',
        () => _dao.deletePackets(packetIds),
      );

  Future<Result<int>> countPackets({PacketStatus? status}) =>
      ResultGuards.guard(
        _logger,
        '$_tag.countPackets',
        () => _dao.countPackets(status: status),
      );

  // ---- Fragments -----------------------------------------------------------------

  Future<Result<List<PacketFragmentRow>>> fragmentsFor(String packetId) =>
      ResultGuards.guard(
        _logger,
        '$_tag.fragmentsFor',
        () => _dao.fragmentsFor(packetId),
      );

  Future<Result<int>> markFragmentReceived(int fragmentId) =>
      ResultGuards.guard(
        _logger,
        '$_tag.markFragmentReceived',
        () => _dao.markFragmentReceived(fragmentId),
      );

  Future<Result<int>> countMissingFragments(String packetId) =>
      ResultGuards.guard(
        _logger,
        '$_tag.countMissingFragments',
        () => _dao.countMissingFragments(packetId),
      );
}
