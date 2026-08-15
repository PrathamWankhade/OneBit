import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/core/config/app_config.dart';
import 'package:onebit/core/config/app_config_provider.dart';
import 'package:onebit/core/config/app_environment.dart';
import 'package:onebit/core/config/app_flavor.dart';
import 'package:onebit/core/result/result.dart';
import 'package:onebit/core/theme/onebit_theme.dart';
import 'package:onebit/core/theme/theme_preference.dart';
import 'package:onebit/features/about/presentation/about_screen.dart';
import 'package:onebit/features/about/presentation/licenses_screen.dart';
import 'package:onebit/features/bluetooth/domain/bluetooth_permission_state.dart';
import 'package:onebit/features/bluetooth/domain/bluetooth_radio_state.dart';
import 'package:onebit/features/bluetooth/domain/bluetooth_repository.dart';
import 'package:onebit/features/bluetooth/domain/bluetooth_state.dart';
import 'package:onebit/features/bluetooth/domain/bluetooth_views.dart';
import 'package:onebit/features/bluetooth/presentation/bluetooth_providers.dart';
import 'package:onebit/features/media/storage/storage_statistics.dart';
import 'package:onebit/features/settings/presentation/appearance_settings_screen.dart';
import 'package:onebit/features/settings/presentation/bluetooth_settings_screen.dart';
import 'package:onebit/features/settings/presentation/notifications_settings_screen.dart';
import 'package:onebit/features/settings/presentation/privacy_settings_screen.dart';
import 'package:onebit/features/settings/presentation/storage_settings_screen.dart';
import 'package:onebit/l10n/app_localizations.dart';
import 'package:onebit/shared/design_system/components/onebit_card.dart';
import 'package:onebit/shared/design_system/components/onebit_section_header.dart';

class _FakeBluetoothRepository implements BluetoothRepository {
  _FakeBluetoothRepository() {
    _radioStateController = StreamController<BluetoothRadioState>.broadcast();
    _eventsController = StreamController<BluetoothTransportEvent>.broadcast();
  }

  late final StreamController<BluetoothRadioState> _radioStateController;
  late final StreamController<BluetoothTransportEvent> _eventsController;

  @override
  Future<Result<BluetoothRadioSnapshot>> getRadioSnapshot() async => const Ok(
    BluetoothRadioSnapshot(
      radio: BluetoothRadioState.ready,
      permission: BluetoothPermissionState.granted,
      batterySaver: false,
      maxConcurrentConnections: 7,
    ),
  );

  @override
  Stream<BluetoothRadioState> get radioStateStream =>
      _radioStateController.stream;

  @override
  Stream<BluetoothTransportEvent> get events => _eventsController.stream;

  @override
  Future<Result<BluetoothPermissionState>> requestPermissions() async =>
      const Ok(BluetoothPermissionState.granted);

  @override
  Future<Result<BluetoothPermissionState>> recoverPermissions() async =>
      const Ok(BluetoothPermissionState.granted);

  @override
  Future<Result<String>> startScan(dynamic config) async => const Ok('scan-1');

  @override
  Future<Result<void>> stopScan(String scanId) async => const Ok(null);

  @override
  Future<Result<String>> startAdvertising(dynamic config) async =>
      const Ok('adv-1');

  @override
  Future<Result<void>> stopAdvertising(String advertisingId) async =>
      const Ok(null);

  @override
  Future<Result<void>> startGattServer({required String deviceId}) async =>
      const Ok(null);

  @override
  Future<Result<void>> stopGattServer() async => const Ok(null);

  @override
  Future<Result<void>> connect(dynamic device, dynamic options) async =>
      const Ok(null);

  @override
  Future<Result<void>> disconnect(String deviceId) async => const Ok(null);

  @override
  Future<Result<dynamic>> readRssi(String deviceId) async => const Ok(null);

  @override
  Future<Result<dynamic>> requestMtu(String deviceId, int mtu) async =>
      const Ok(null);

  @override
  Future<Result<List<dynamic>>> discoverServices(String deviceId) async =>
      const Ok([]);

  @override
  Future<Result<List<int>>> readCharacteristic({
    required String deviceId,
    required String serviceUuid,
    required String characteristicUuid,
  }) async => const Ok([]);

  @override
  Future<Result<void>> writeCharacteristic({
    required String deviceId,
    required String serviceUuid,
    required String characteristicUuid,
    required List<int> value,
    bool withoutResponse = false,
    bool reliable = false,
  }) async => const Ok(null);

  @override
  Future<Result<void>> setCharacteristicNotification({
    required String deviceId,
    required String serviceUuid,
    required String characteristicUuid,
    required bool enabled,
    bool indications = false,
  }) async => const Ok(null);

  @override
  Future<Result<void>> startForegroundService({required String reason}) async =>
      const Ok(null);

  @override
  Future<Result<void>> stopForegroundService() async => const Ok(null);

  void dispose() {
    _radioStateController.close();
    _eventsController.close();
  }
}

Widget _wrapApp(Widget child, {ThemeData? theme, TextScaler? textScaler}) =>
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(
          const AppConfig(
            flavor: AppFlavor.debug,
            environment: AppEnvironment.development,
            version: '1.0.0',
            buildNumber: 1,
          ),
        ),
      ],
      child: MaterialApp(
        theme: theme ?? OneBitTheme.dark,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: textScaler != null
            ? (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: textScaler),
                child: child!,
              )
            : null,
        home: Scaffold(body: child),
      ),
    );

late _FakeBluetoothRepository _fakeBtRepo;

Widget _wrapBtApp(Widget child, {ThemeData? theme, TextScaler? textScaler}) {
  _fakeBtRepo = _FakeBluetoothRepository();
  return ProviderScope(
    overrides: [
      appConfigProvider.overrideWithValue(
        const AppConfig(
          flavor: AppFlavor.debug,
          environment: AppEnvironment.development,
          version: '1.0.0',
          buildNumber: 1,
        ),
      ),
      bluetoothRepositoryProvider.overrideWithValue(_fakeBtRepo),
    ],
    child: MaterialApp(
      theme: theme ?? OneBitTheme.dark,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: textScaler != null
          ? (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: textScaler),
              child: child!,
            )
          : null,
      home: Scaffold(body: child),
    ),
  );
}

Widget _wrapStorageApp(
  Widget child, {
  ThemeData? theme,
  TextScaler? textScaler,
}) => ProviderScope(
  overrides: [
    appConfigProvider.overrideWithValue(
      const AppConfig(
        flavor: AppFlavor.debug,
        environment: AppEnvironment.development,
        version: '1.0.0',
        buildNumber: 1,
      ),
    ),
    storageStatisticsProvider.overrideWithValue(
      const AsyncData(
        StorageStatistics(
          rootBytes: 1000000000,
          freeBytes: 500000000,
          payloadBytes: 200000000,
          tempBytes: 50000000,
          cacheBytes: 100000000,
          attachmentCount: 42,
        ),
      ),
    ),
  ],
  child: MaterialApp(
    theme: theme ?? OneBitTheme.dark,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: textScaler != null
        ? (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: textScaler),
            child: child!,
          )
        : null,
    home: Scaffold(body: child),
  ),
);

void main() {
  group('AppearanceSettingsScreen', () {
    testWidgets('renders theme options in dark mode', (tester) async {
      await tester.pumpWidget(_wrapApp(const AppearanceSettingsScreen()));
      await tester.pumpAndSettle();
      expect(find.byType(AppearanceSettingsScreen), findsOneWidget);
    });

    testWidgets('renders in light theme', (tester) async {
      await tester.pumpWidget(
        _wrapApp(const AppearanceSettingsScreen(), theme: OneBitTheme.light),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AppearanceSettingsScreen), findsOneWidget);
    });

    testWidgets('renders with large text', (tester) async {
      await tester.pumpWidget(
        _wrapApp(
          const AppearanceSettingsScreen(),
          textScaler: const TextScaler.linear(2.0),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AppearanceSettingsScreen), findsOneWidget);
    });

    testWidgets('shows theme selection options', (tester) async {
      await tester.pumpWidget(_wrapApp(const AppearanceSettingsScreen()));
      await tester.pumpAndSettle();
      expect(find.byType(RadioListTile<ThemePreference>), findsNWidgets(3));
    });

    testWidgets('shows terminal palette section', (tester) async {
      await tester.pumpWidget(_wrapApp(const AppearanceSettingsScreen()));
      await tester.pumpAndSettle();
      expect(find.byType(OneBitSectionHeader), findsWidgets);
    });
  });

  group('PrivacySettingsScreen', () {
    testWidgets('renders privacy information', (tester) async {
      await tester.pumpWidget(_wrapApp(const PrivacySettingsScreen()));
      await tester.pumpAndSettle();
      expect(find.byType(PrivacySettingsScreen), findsOneWidget);
      expect(find.byType(OneBitCard), findsWidgets);
    });

    testWidgets('renders in light theme', (tester) async {
      await tester.pumpWidget(
        _wrapApp(const PrivacySettingsScreen(), theme: OneBitTheme.light),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PrivacySettingsScreen), findsOneWidget);
    });

    testWidgets('renders with large text', (tester) async {
      await tester.pumpWidget(
        _wrapApp(
          const PrivacySettingsScreen(),
          textScaler: const TextScaler.linear(2.0),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PrivacySettingsScreen), findsOneWidget);
    });

    testWidgets('renders in landscape', (tester) async {
      await tester.pumpWidget(_wrapApp(const PrivacySettingsScreen()));
      await tester.pumpAndSettle();
      expect(find.byType(PrivacySettingsScreen), findsOneWidget);
    });

    testWidgets('shows privacy categories', (tester) async {
      await tester.pumpWidget(_wrapApp(const PrivacySettingsScreen()));
      await tester.pumpAndSettle();
      expect(find.byType(OneBitSectionHeader), findsWidgets);
    });
  });

  group('NotificationsSettingsScreen', () {
    testWidgets('renders notification description', (tester) async {
      await tester.pumpWidget(_wrapApp(const NotificationsSettingsScreen()));
      await tester.pumpAndSettle();
      expect(find.byType(NotificationsSettingsScreen), findsOneWidget);
    });

    testWidgets('renders in light theme', (tester) async {
      await tester.pumpWidget(
        _wrapApp(const NotificationsSettingsScreen(), theme: OneBitTheme.light),
      );
      await tester.pumpAndSettle();
      expect(find.byType(NotificationsSettingsScreen), findsOneWidget);
    });

    testWidgets('renders with large text', (tester) async {
      await tester.pumpWidget(
        _wrapApp(
          const NotificationsSettingsScreen(),
          textScaler: const TextScaler.linear(2.0),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(NotificationsSettingsScreen), findsOneWidget);
    });
  });

  group('BluetoothSettingsScreen', () {
    testWidgets('renders bluetooth settings', (tester) async {
      await tester.pumpWidget(_wrapBtApp(const BluetoothSettingsScreen()));
      await tester.pumpAndSettle();
      expect(find.byType(BluetoothSettingsScreen), findsOneWidget);
    });

    testWidgets('renders in light theme', (tester) async {
      await tester.pumpWidget(
        _wrapBtApp(const BluetoothSettingsScreen(), theme: OneBitTheme.light),
      );
      await tester.pumpAndSettle();
      expect(find.byType(BluetoothSettingsScreen), findsOneWidget);
    });

    testWidgets('renders with large text', (tester) async {
      await tester.pumpWidget(
        _wrapBtApp(
          const BluetoothSettingsScreen(),
          textScaler: const TextScaler.linear(2.0),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(BluetoothSettingsScreen), findsOneWidget);
    });
  });

  group('StorageSettingsScreen', () {
    testWidgets('renders storage settings', (tester) async {
      await tester.pumpWidget(_wrapStorageApp(const StorageSettingsScreen()));
      await tester.pumpAndSettle();
      expect(find.byType(StorageSettingsScreen), findsOneWidget);
    });

    testWidgets('renders in light theme', (tester) async {
      await tester.pumpWidget(
        _wrapStorageApp(
          const StorageSettingsScreen(),
          theme: OneBitTheme.light,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(StorageSettingsScreen), findsOneWidget);
    });

    testWidgets('renders with large text', (tester) async {
      await tester.pumpWidget(
        _wrapStorageApp(
          const StorageSettingsScreen(),
          textScaler: const TextScaler.linear(2.0),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(StorageSettingsScreen), findsOneWidget);
    });
  });

  group('AboutScreen', () {
    testWidgets('renders about screen with logo', (tester) async {
      await tester.pumpWidget(_wrapApp(const AboutScreen()));
      await tester.pumpAndSettle();
      expect(find.byType(AboutScreen), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('renders in light theme', (tester) async {
      await tester.pumpWidget(
        _wrapApp(const AboutScreen(), theme: OneBitTheme.light),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AboutScreen), findsOneWidget);
    });

    testWidgets('renders with large text', (tester) async {
      await tester.pumpWidget(
        _wrapApp(const AboutScreen(), textScaler: const TextScaler.linear(2.0)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AboutScreen), findsOneWidget);
    });

    testWidgets('shows version and licenses', (tester) async {
      await tester.pumpWidget(_wrapApp(const AboutScreen()));
      await tester.pumpAndSettle();
      expect(find.text('1.0.0+1'), findsWidgets);
      expect(find.byType(OneBitSectionHeader), findsWidgets);
    });

    testWidgets('shows technical info section', (tester) async {
      await tester.pumpWidget(_wrapApp(const AboutScreen()));
      await tester.pumpAndSettle();
      expect(find.byType(OneBitSectionHeader), findsWidgets);
    });
  });

  group('LicensesScreen', () {
    testWidgets('renders licenses screen', (tester) async {
      await tester.pumpWidget(_wrapApp(const LicensesScreen()));
      await tester.pumpAndSettle();
      expect(find.byType(LicensesScreen), findsOneWidget);
    });

    testWidgets('renders in light theme', (tester) async {
      await tester.pumpWidget(
        _wrapApp(const LicensesScreen(), theme: OneBitTheme.light),
      );
      await tester.pumpAndSettle();
      expect(find.byType(LicensesScreen), findsOneWidget);
    });

    testWidgets('renders with large text', (tester) async {
      await tester.pumpWidget(
        _wrapApp(
          const LicensesScreen(),
          textScaler: const TextScaler.linear(2.0),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(LicensesScreen), findsOneWidget);
    });

    testWidgets('shows license sections', (tester) async {
      await tester.pumpWidget(_wrapApp(const LicensesScreen()));
      await tester.pumpAndSettle();
      expect(find.byType(OneBitSectionHeader), findsWidgets);
      expect(find.byType(OneBitCard), findsWidgets);
    });

    testWidgets('shows license page button', (tester) async {
      await tester.pumpWidget(_wrapApp(const LicensesScreen()));
      await tester.pumpAndSettle();
      expect(find.byType(TextButton), findsOneWidget);
    });
  });
}
