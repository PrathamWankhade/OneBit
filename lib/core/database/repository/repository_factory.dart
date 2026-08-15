import 'package:onebit/core/database/cache/channel_cache.dart';
import 'package:onebit/core/database/cache/identity_cache.dart';
import 'package:onebit/core/database/cache/neighbor_cache.dart';
import 'package:onebit/core/database/cache/route_cache.dart';
import 'package:onebit/core/database/cache/settings_cache.dart';
import 'package:onebit/core/database/cache/trust_cache.dart';
import 'package:onebit/core/database/dao/channel_dao.dart';
import 'package:onebit/core/database/dao/identity_dao.dart';
import 'package:onebit/core/database/dao/media_dao.dart';
import 'package:onebit/core/database/dao/message_dao.dart';
import 'package:onebit/core/database/dao/neighbor_dao.dart';
import 'package:onebit/core/database/dao/packet_dao.dart';
import 'package:onebit/core/database/dao/queue_dao.dart';
import 'package:onebit/core/database/dao/route_dao.dart';
import 'package:onebit/core/database/dao/session_dao.dart';
import 'package:onebit/core/database/dao/settings_dao.dart';
import 'package:onebit/core/database/dao/statistics_dao.dart';
import 'package:onebit/core/database/database.dart';
import 'package:onebit/core/database/repository/channel_repository.dart';
import 'package:onebit/core/database/repository/identity_repository.dart';
import 'package:onebit/core/database/repository/message_repository.dart';
import 'package:onebit/core/database/repository/neighbor_repository.dart';
import 'package:onebit/core/database/repository/packet_repository.dart';
import 'package:onebit/core/database/repository/route_repository.dart';
import 'package:onebit/core/database/repository/session_repository.dart';
import 'package:onebit/core/database/repository/settings_repository.dart';
import 'package:onebit/core/database/repository/statistics_repository.dart';
import 'package:onebit/core/logger/app_logger.dart';

/// Builds the complete persistence graph for one database connection.
///
/// This is the single construction site for DAOs, caches and repositories:
/// Riverpod providers expose these instances (`repositoryFactoryProvider`),
/// tests build the same graph over an in-memory database, and swapping
/// storage engines never touches this class.
final class RepositoryFactory {
  RepositoryFactory({required this._database, required this._logger});

  final OneBitDatabase _database;
  final AppLogger _logger;

  // ---- DAOs -------------------------------------------------------------------

  late final IdentityDao identityDao = IdentityDao(_database);
  late final ChannelDao channelDao = ChannelDao(_database);
  late final MessageDao messageDao = MessageDao(_database);
  late final PacketDao packetDao = PacketDao(_database);
  late final RouteDao routeDao = RouteDao(_database);
  late final NeighborDao neighborDao = NeighborDao(_database);
  late final SessionDao sessionDao = SessionDao(_database);
  late final QueueDao queueDao = QueueDao(_database);
  late final SettingsDao settingsDao = SettingsDao(_database);
  late final StatisticsDao statisticsDao = StatisticsDao(_database);
  late final MediaDao mediaDao = MediaDao(_database);

  // ---- Caches -------------------------------------------------------------------

  late final IdentityCache identityCache = IdentityCache();
  late final TrustCache trustCache = TrustCache();
  late final ChannelCache channelCache = ChannelCache();
  late final NeighborCache neighborCache = NeighborCache();
  late final RouteCache routeCache = RouteCache();
  late final SettingsCache settingsCache = SettingsCache();

  // ---- Repositories ---------------------------------------------------------------

  late final IdentityRepository identity = IdentityRepository(
    dao: identityDao,
    identityCache: identityCache,
    trustCache: trustCache,
    logger: _logger,
  );
  late final ChannelRepository channel = ChannelRepository(
    dao: channelDao,
    cache: channelCache,
    logger: _logger,
  );
  late final MessageRepository message = MessageRepository(
    dao: messageDao,
    logger: _logger,
  );
  late final PacketRepository packet = PacketRepository(
    dao: packetDao,
    logger: _logger,
  );
  late final RouteRepository route = RouteRepository(
    dao: routeDao,
    cache: routeCache,
    logger: _logger,
  );
  late final NeighborRepository neighbor = NeighborRepository(
    dao: neighborDao,
    cache: neighborCache,
    logger: _logger,
  );
  late final SessionRepository session = SessionRepository(
    dao: sessionDao,
    logger: _logger,
  );
  late final SettingsRepository settings = SettingsRepository(
    dao: settingsDao,
    cache: settingsCache,
    logger: _logger,
  );
  late final StatisticsRepository statistics = StatisticsRepository(
    dao: statisticsDao,
    logger: _logger,
  );
}
