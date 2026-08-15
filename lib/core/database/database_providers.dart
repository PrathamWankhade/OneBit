import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/core/config/app_config_provider.dart';
import 'package:onebit/core/database/backup/backup_service.dart';
import 'package:onebit/core/database/cache/channel_cache.dart';
import 'package:onebit/core/database/cache/identity_cache.dart';
import 'package:onebit/core/database/cache/neighbor_cache.dart';
import 'package:onebit/core/database/cache/route_cache.dart';
import 'package:onebit/core/database/cache/settings_cache.dart';
import 'package:onebit/core/database/cache/trust_cache.dart';
import 'package:onebit/core/database/config/database_config.dart';
import 'package:onebit/core/database/connection/connection_factory.dart';
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
import 'package:onebit/core/database/repository/repository_factory.dart';
import 'package:onebit/core/database/repository/route_repository.dart';
import 'package:onebit/core/database/repository/session_repository.dart';
import 'package:onebit/core/database/repository/settings_repository.dart';
import 'package:onebit/core/database/repository/statistics_repository.dart';
import 'package:onebit/core/logger/logger_providers.dart';

/// Swappable connection seam (tests replace this with the in-memory factory).
final Provider<ConnectionFactory> databaseConnectionFactoryProvider =
    Provider<ConnectionFactory>((ref) => const DriftFlutterConnectionFactory());

/// The application's [OneBitDatabase].
///
/// The file is named after the active flavor so dev/beta/prod never share a
/// database; the connection stays lazy until the first query.
final Provider<OneBitDatabase> databaseProvider = Provider<OneBitDatabase>((
  ref,
) {
  final config = ref.watch(appConfigProvider);
  final factory = ref.watch(databaseConnectionFactoryProvider);
  final database = OneBitDatabase(
    factory.open(DatabaseConfig(name: 'onebit_${config.flavor.rawName}')),
  );
  ref.onDispose(database.close);
  return database;
});

/// The complete persistence graph (DAOs, caches, repositories) for the
/// active database. All granular providers below expose its instances.
final Provider<RepositoryFactory> repositoryFactoryProvider =
    Provider<RepositoryFactory>(
      (ref) => RepositoryFactory(
        database: ref.watch(databaseProvider),
        logger: ref.watch(appLoggerProvider),
      ),
    );

// ---- DAOs ----------------------------------------------------------------------

final Provider<IdentityDao> identityDaoProvider = Provider<IdentityDao>(
  (ref) => ref.watch(repositoryFactoryProvider).identityDao,
);
final Provider<ChannelDao> channelDaoProvider = Provider<ChannelDao>(
  (ref) => ref.watch(repositoryFactoryProvider).channelDao,
);
final Provider<MessageDao> messageDaoProvider = Provider<MessageDao>(
  (ref) => ref.watch(repositoryFactoryProvider).messageDao,
);
final Provider<PacketDao> packetDaoProvider = Provider<PacketDao>(
  (ref) => ref.watch(repositoryFactoryProvider).packetDao,
);
final Provider<RouteDao> routeDaoProvider = Provider<RouteDao>(
  (ref) => ref.watch(repositoryFactoryProvider).routeDao,
);
final Provider<NeighborDao> neighborDaoProvider = Provider<NeighborDao>(
  (ref) => ref.watch(repositoryFactoryProvider).neighborDao,
);
final Provider<SessionDao> sessionDaoProvider = Provider<SessionDao>(
  (ref) => ref.watch(repositoryFactoryProvider).sessionDao,
);
final Provider<QueueDao> queueDaoProvider = Provider<QueueDao>(
  (ref) => ref.watch(repositoryFactoryProvider).queueDao,
);
final Provider<SettingsDao> settingsDaoProvider = Provider<SettingsDao>(
  (ref) => ref.watch(repositoryFactoryProvider).settingsDao,
);
final Provider<StatisticsDao> statisticsDaoProvider = Provider<StatisticsDao>(
  (ref) => ref.watch(repositoryFactoryProvider).statisticsDao,
);
final Provider<MediaDao> mediaDaoProvider = Provider<MediaDao>(
  (ref) => ref.watch(repositoryFactoryProvider).mediaDao,
);

// ---- Caches --------------------------------------------------------------------

final Provider<IdentityCache> identityCacheProvider = Provider<IdentityCache>(
  (ref) => ref.watch(repositoryFactoryProvider).identityCache,
);
final Provider<TrustCache> trustCacheProvider = Provider<TrustCache>(
  (ref) => ref.watch(repositoryFactoryProvider).trustCache,
);
final Provider<ChannelCache> channelCacheProvider = Provider<ChannelCache>(
  (ref) => ref.watch(repositoryFactoryProvider).channelCache,
);
final Provider<NeighborCache> neighborCacheProvider = Provider<NeighborCache>(
  (ref) => ref.watch(repositoryFactoryProvider).neighborCache,
);
final Provider<RouteCache> routeCacheProvider = Provider<RouteCache>(
  (ref) => ref.watch(repositoryFactoryProvider).routeCache,
);
final Provider<SettingsCache> settingsCacheProvider = Provider<SettingsCache>(
  (ref) => ref.watch(repositoryFactoryProvider).settingsCache,
);

// ---- Repositories ---------------------------------------------------------------

final Provider<IdentityRepository> identityRepositoryProvider =
    Provider<IdentityRepository>(
      (ref) => ref.watch(repositoryFactoryProvider).identity,
    );
final Provider<ChannelRepository> channelRepositoryProvider =
    Provider<ChannelRepository>(
      (ref) => ref.watch(repositoryFactoryProvider).channel,
    );
final Provider<MessageRepository> messageRepositoryProvider =
    Provider<MessageRepository>(
      (ref) => ref.watch(repositoryFactoryProvider).message,
    );
final Provider<PacketRepository> packetRepositoryProvider =
    Provider<PacketRepository>(
      (ref) => ref.watch(repositoryFactoryProvider).packet,
    );
final Provider<RouteRepository> routeRepositoryProvider =
    Provider<RouteRepository>(
      (ref) => ref.watch(repositoryFactoryProvider).route,
    );
final Provider<NeighborRepository> neighborRepositoryProvider =
    Provider<NeighborRepository>(
      (ref) => ref.watch(repositoryFactoryProvider).neighbor,
    );
final Provider<SessionRepository> sessionRepositoryProvider =
    Provider<SessionRepository>(
      (ref) => ref.watch(repositoryFactoryProvider).session,
    );
final Provider<SettingsRepository> settingsRepositoryProvider =
    Provider<SettingsRepository>(
      (ref) => ref.watch(repositoryFactoryProvider).settings,
    );
final Provider<StatisticsRepository> statisticsRepositoryProvider =
    Provider<StatisticsRepository>(
      (ref) => ref.watch(repositoryFactoryProvider).statistics,
    );

// ---- Reactive settings ------------------------------------------------------------

/// Live key→value snapshot of all settings, kept in sync with the database.
///
/// Emits the current setting map on every change and after each write;
/// transient read errors fall back to the last known values.
final StreamProvider<Map<String, String>> settingsProvider =
    StreamProvider<Map<String, String>>((ref) {
      final stream = ref.watch(settingsRepositoryProvider).watchAllSettings();
      return stream.map(
        (result) => result.fold(
          (rows) => <String, String>{
            for (final row in rows) row.key: row.value,
          },
          (_) => const <String, String>{},
        ),
      );
    });

final Provider<DatabaseBackupService> databaseBackupServiceProvider =
    Provider<DatabaseBackupService>(
      (ref) => DatabaseBackupService(
        db: ref.watch(databaseProvider),
        logger: ref.watch(appLoggerProvider),
      ),
    );
