import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:onebit/app/router.dart';
import 'package:onebit/app/router_notifier.dart';
import 'package:onebit/core/theme/app_theme.dart';
import 'package:onebit/core/version/app_version.dart';
import 'package:onebit/data/database/app_database.dart';
import 'package:onebit/data/preferences/onboarding_repository.dart';
import 'package:onebit/features/ble/ble_lifecycle_observer.dart';
import 'package:onebit/features/ble/ble_providers.dart';
import 'package:onebit/features/identity/identity_providers.dart';
import 'package:onebit/features/peer_registry/peer_connection_providers.dart';
import 'package:onebit/features/protocol/message_transport.dart';
import 'package:onebit/features/message/application/message_relay_service.dart';
import 'package:onebit/features/message/providers/message_providers.dart';
import 'package:onebit/features/settings/application/app_update_watcher.dart';
import 'package:onebit/features/settings/data/settings_repository.dart';
import 'package:onebit/features/settings/data/settings_providers.dart';
import 'package:onebit/features/routing/providers/routing_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

final sharedPreferencesProvider = FutureProvider<SharedPreferences>(
  (ref) => SharedPreferences.getInstance(),
);

final settingsRepositoryInitProvider = FutureProvider<SettingsRepository>(
  (ref) async {
    final prefs = await ref.watch(sharedPreferencesProvider.future);
    return SettingsRepository(prefs);
  },
);

final onboardingRepositoryProvider = FutureProvider<OnboardingRepository>(
  (ref) async {
    final prefs = await ref.watch(sharedPreferencesProvider.future);
    return OnboardingRepository(prefs);
  },
);

final routerNotifierProvider = FutureProvider<RouterNotifier>(
  (ref) async {
    final repo = await ref.watch(onboardingRepositoryProvider.future);
    return RouterNotifier(repo);
  },
);

final routerProvider = FutureProvider<GoRouter>(
  (ref) async {
    final notifier = await ref.watch(routerNotifierProvider.future);
    return createRouter(notifier);
  },
);

/// App-scoped relay service for multi-hop message forwarding.
final messageRelayServiceProvider = Provider<MessageRelayService?>((ref) {
  final transmissionService = ref.watch(messageTransmissionServiceProvider);
  if (transmissionService == null) return null;
  final localPeerId = ref.watch(localPeerIdForMessageProvider);
  return MessageRelayService(
    localPeerId: localPeerId,
    transmissionService: transmissionService,
    forwardingAllowed: () {
      try {
        return ref.read(settingsRelayEnabledProvider);
      } catch (_) {
        return true;
      }
    },
  );
});

/// App-scoped message transport bridging DB ↔ BLE.
///
/// Also hands the transport the routing/identity lookups it needs to
/// decide between a mesh send and a direct one, plus the two events that
/// tell its outbox that a message stuck waiting may have a next hop now.
final messageTransportProvider = Provider<MessageTransport>((ref) {
  final bleService = ref.watch(bleServiceProvider);
  final db = ref.watch(databaseProvider);
  final relayService = ref.watch(messageRelayServiceProvider);
  final localPeerId = ref.watch(localPeerIdForMessageProvider);
  final transmissionService = ref.watch(messageTransmissionServiceProvider);
  final routingTable = ref.watch(routingTableProvider);
  final connectionManager = ref.watch(peerConnectionManagerProvider);
  final resolver = ref.watch(bleIdentityResolverProvider);
  final meshRouter = ref.watch(meshRouterProvider);

  // Encryption material comes from the identity, not the transport:
  // the seed never leaves IdentityService except through these two
  // closures, and both throw while no identity is loaded — which the
  // transport reads as "send plaintext".
  final identityService = ref.watch(identityServiceProvider);

  final transport = MessageTransport(
    bleService: bleService,
    database: db,
    relayService: relayService,
    localPeerId: localPeerId,
    identityForDevice: (deviceId) => resolver.deviceToPeerId[deviceId],
    deviceForPeer: connectionManager.deviceForPeer,
    routeLookup: routingTable.bestRoute,
    transmissionService: transmissionService,
    routeEvents: meshRouter.routesChanged,
    connectionEvents: connectionManager.connectionStream,
    localKeyAgreement: identityService.keyAgreementKeyPair,
    localSign: identityService.signBytes,
  );
  transport.startListening();
  ref.onDispose(() => transport.dispose());
  return transport;
});

class OneBitApp extends ConsumerWidget {
  const OneBitApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routerAsync = ref.watch(routerProvider);
    final settingsAsync = ref.watch(settingsRepositoryInitProvider);

    return routerAsync.when(
      loading: () => MaterialApp(
        home: Scaffold(
          body: Center(
            child: SvgPicture.asset(
              'assets/icons/OneBitLogo.svg',
              width: 160,
              height: 160,
            ),
          ),
        ),
      ),
      error: (e, _) => MaterialApp(
        home: Scaffold(body: Center(child: Text('Error: $e'))),
      ),
      data: (router) => settingsAsync.when(
        loading: () => MaterialApp(
          home: Scaffold(
            body: Center(
              child: SvgPicture.asset(
                'assets/icons/OneBitLogo.svg',
                width: 80,
                height: 80,
              ),
            ),
          ),
        ),
        error: (e, _) => MaterialApp(
          home: Scaffold(body: Center(child: Text('Error: $e'))),
        ),
        data: (settingsRepo) => ProviderScope(
          overrides: [
            settingsRepositoryProvider.overrideWithValue(settingsRepo),
          ],
          child: _OneBitAppBody(
            router: router,
            settingsRepo: settingsRepo,
          ),
        ),
      ),
    );
  }
}

class _OneBitAppBody extends ConsumerStatefulWidget {
  const _OneBitAppBody({required this.router, required this.settingsRepo});

  final GoRouter router;
  final SettingsRepository settingsRepo;

  @override
  ConsumerState<_OneBitAppBody> createState() => _OneBitAppBodyState();
}

class _OneBitAppBodyState extends ConsumerState<_OneBitAppBody> {
  /// Shared with the [MaterialApp] below so the automatic update check can
  /// raise a SnackBar without a context from the wrong side of the router.
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    // Fire and forget: nothing awaits the platform's version, so a slow or
    // missing plugin cannot hold up the first frame. Screens render the
    // pubspec fallback meanwhile, and the automatic check below awaits it
    // properly before comparing anything.
    AppVersion.load();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(bleLifecycleObserverProvider);
    // Lazy providers are never built until something watches them.
    // The mesh only routes if this is held alive for the app's life.
    ref.watch(meshRouterProvider);

    return AppUpdateWatcher(
      scaffoldMessengerKey: _scaffoldMessengerKey,
      onOpenUpdate: () => widget.router.push('/settings/update'),
      child: MaterialApp.router(
        title: 'OneBit',
        debugShowCheckedModeBanner: false,
        scaffoldMessengerKey: _scaffoldMessengerKey,
        theme: AppTheme.dark(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.dark,
        routerConfig: widget.router,
      ),
    );
  }
}
