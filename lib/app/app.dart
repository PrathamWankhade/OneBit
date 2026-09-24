import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:onebit/app/router.dart';
import 'package:onebit/app/router_notifier.dart';
import 'package:onebit/core/theme/app_theme.dart';
import 'package:onebit/data/database/app_database.dart';
import 'package:onebit/data/preferences/onboarding_repository.dart';
import 'package:onebit/features/ble/ble_lifecycle_observer.dart';
import 'package:onebit/features/ble/ble_providers.dart';
import 'package:onebit/features/protocol/message_transport.dart';
import 'package:onebit/features/message/application/message_relay_service.dart';
import 'package:onebit/features/message/providers/message_providers.dart';
import 'package:onebit/features/settings/data/settings_repository.dart';
import 'package:onebit/features/settings/data/settings_providers.dart';
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
  );
});

/// App-scoped message transport bridging DB ↔ BLE.
final messageTransportProvider = Provider<MessageTransport>((ref) {
  final bleService = ref.watch(bleServiceProvider);
  final db = ref.watch(databaseProvider);
  final relayService = ref.watch(messageRelayServiceProvider);
  final transport = MessageTransport(
    bleService: bleService,
    database: db,
    relayService: relayService,
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

class _OneBitAppBody extends ConsumerWidget {
  const _OneBitAppBody({required this.router, required this.settingsRepo});

  final GoRouter router;
  final SettingsRepository settingsRepo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(bleLifecycleObserverProvider);

    return MaterialApp.router(
      title: 'OneBit',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.dark,
      routerConfig: router,
    );
  }
}
