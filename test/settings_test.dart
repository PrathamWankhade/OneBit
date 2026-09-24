import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/features/settings/data/settings_providers.dart';
import 'package:onebit/features/settings/data/settings_repository.dart';
import 'package:onebit/features/settings/presentation/screens/about_screen.dart';
import 'package:onebit/features/settings/presentation/screens/appearance_settings_screen.dart';
import 'package:onebit/features/settings/presentation/screens/settings_main_screen.dart';
import 'package:onebit/features/settings/presentation/widgets/settings_section.dart';
import 'package:onebit/features/settings/presentation/widgets/settings_tile.dart';
import 'package:onebit/features/settings/presentation/widgets/settings_toggle.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SettingsRepository', () {
    test('defaults: themeMode 0, accent 0, fontSize 1', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = SettingsRepository(prefs);
      expect(repo.themeModeIndex, 0);
      expect(repo.accentColorIndex, 0);
      expect(repo.fontSizeIndex, 1);
    });

    test('defaults: all booleans sensible', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = SettingsRepository(prefs);
      expect(repo.showTimestamps, true);
      expect(repo.compactMode, false);
      expect(repo.reducedMotion, false);
      expect(repo.notificationsEnabled, true);
      expect(repo.notificationSound, true);
      expect(repo.notificationVibration, true);
      expect(repo.discoveryEnabled, true);
      expect(repo.relayEnabled, true);
    });

    test('setThemeMode persists value', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = SettingsRepository(prefs);
      await repo.setThemeMode(2);
      expect(prefs.getInt('settings_theme_mode'), 2);
    });

    test('setAccentColor persists value', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = SettingsRepository(prefs);
      await repo.setAccentColor(3);
      expect(prefs.getInt('settings_accent_color'), 3);
    });

    test('setFontSize persists value', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = SettingsRepository(prefs);
      await repo.setFontSize(0);
      expect(prefs.getInt('settings_font_size'), 0);
    });

    test('setShowTimestamps persists value', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = SettingsRepository(prefs);
      await repo.setShowTimestamps(false);
      expect(prefs.getBool('settings_show_timestamps'), false);
    });

    test('setCompactMode persists value', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = SettingsRepository(prefs);
      await repo.setCompactMode(true);
      expect(prefs.getBool('settings_compact_mode'), true);
    });

    test('setReducedMotion persists value', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = SettingsRepository(prefs);
      await repo.setReducedMotion(true);
      expect(prefs.getBool('settings_reduced_motion'), true);
    });

    test('setNotificationsEnabled persists value', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = SettingsRepository(prefs);
      await repo.setNotificationsEnabled(false);
      expect(prefs.getBool('settings_notifications_enabled'), false);
    });

    test('setNotificationSound persists value', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = SettingsRepository(prefs);
      await repo.setNotificationSound(false);
      expect(prefs.getBool('settings_notification_sound'), false);
    });

    test('setNotificationVibration persists value', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = SettingsRepository(prefs);
      await repo.setNotificationVibration(false);
      expect(prefs.getBool('settings_notification_vibration'), false);
    });

    test('setDiscoveryEnabled persists value', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = SettingsRepository(prefs);
      await repo.setDiscoveryEnabled(false);
      expect(prefs.getBool('settings_discovery_enabled'), false);
    });

    test('setRelayEnabled persists value', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = SettingsRepository(prefs);
      await repo.setRelayEnabled(false);
      expect(prefs.getBool('settings_relay_enabled'), false);
    });

    test('read persisted values after restart', () async {
      SharedPreferences.setMockInitialValues({
        'settings_theme_mode': 2,
        'settings_accent_color': 3,
        'settings_font_size': 0,
        'settings_show_timestamps': false,
        'settings_compact_mode': true,
        'settings_reduced_motion': true,
      });
      final prefs = await SharedPreferences.getInstance();
      final repo = SettingsRepository(prefs);
      expect(repo.themeModeIndex, 2);
      expect(repo.accentColorIndex, 3);
      expect(repo.fontSizeIndex, 0);
      expect(repo.showTimestamps, false);
      expect(repo.compactMode, true);
      expect(repo.reducedMotion, true);
    });
  });

  group('AccentColor enum', () {
    test('has 6 values', () {
      expect(AccentColor.values.length, 6);
    });

    test('cyan has correct color and label', () {
      expect(AccentColor.cyan.color, const Color(0xFF00D4AA));
      expect(AccentColor.cyan.label, 'Cyan');
    });

    test('green color is correct', () {
      expect(AccentColor.green.color, const Color(0xFF4CAF50));
    });

    test('blue color is correct', () {
      expect(AccentColor.blue.color, const Color(0xFF2196F3));
    });

    test('purple color is correct', () {
      expect(AccentColor.purple.color, const Color(0xFF9C27B0));
    });

    test('red color is correct', () {
      expect(AccentColor.red.color, const Color(0xFFF44336));
    });

    test('amber color is correct', () {
      expect(AccentColor.amber.color, const Color(0xFFFFC107));
    });

    test('all labels are non-empty', () {
      for (final c in AccentColor.values) {
        expect(c.label.isNotEmpty, true);
      }
    });

    test('all colors are non-null', () {
      for (final c in AccentColor.values) {
        expect(c.color, isA<Color>());
      }
    });
  });

  group('FontSize enum', () {
    test('has 3 values in order', () {
      expect(FontSize.values, [FontSize.small, FontSize.medium, FontSize.large]);
    });
  });

  group('SettingsSection widget', () {
    testWidgets('renders title and children', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SettingsSection(
              title: 'TEST SECTION',
              children: [
                SettingsTile(icon: Icons.star, title: 'Item 1'),
                SettingsTile(icon: Icons.abc, title: 'Item 2'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('TEST SECTION'), findsOneWidget);
      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 2'), findsOneWidget);
    });

    testWidgets('title uses labelSmall style', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SettingsSection(title: 'SECTION', children: []),
          ),
        ),
      );

      final text = tester.widget<Text>(find.text('SECTION'));
      expect(text.style?.fontWeight, FontWeight.w500);
    });
  });

  group('SettingsTile widget', () {
    testWidgets('renders icon, title, and subtitle', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SettingsTile(
              icon: Icons.settings,
              title: 'My Title',
              description: 'My Subtitle',
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.settings), findsOneWidget);
      expect(find.text('My Title'), findsOneWidget);
      expect(find.text('My Subtitle'), findsOneWidget);
    });

    testWidgets('no subtitle when null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SettingsTile(icon: Icons.settings, title: 'Title'),
          ),
        ),
      );

      expect(find.byType(SettingsTile), findsOneWidget);
      expect(find.text('Title'), findsOneWidget);
    });

    testWidgets('onTap callback fires', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsTile(
              icon: Icons.settings,
              title: 'Tap me',
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Tap me'));
      expect(tapped, true);
    });

    testWidgets('trailing widget renders', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SettingsTile(
              icon: Icons.settings,
              title: 'Title',
              trailing: Icon(Icons.arrow_forward),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
    });
  });

  group('SettingsToggle widget', () {
    testWidgets('renders icon, title, and description', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SettingsToggle(
              icon: Icons.vibration,
              title: 'Vibration',
              value: true,
              description: 'Enable vibration',
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.vibration), findsOneWidget);
      expect(find.text('Vibration'), findsOneWidget);
      expect(find.text('Enable vibration'), findsOneWidget);
    });

    testWidgets('switch reflects value', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SettingsToggle(
              icon: Icons.vibration,
              title: 'Vibration',
              value: true,
            ),
          ),
        ),
      );

      expect(find.byType(Switch), findsOneWidget);
      final switchWidget = tester.widget<Switch>(find.byType(Switch));
      expect(switchWidget.value, true);
    });

    testWidgets('onChanged fires with toggle', (tester) async {
      var lastValue = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsToggle(
              icon: Icons.vibration,
              title: 'Vibration',
              value: false,
              onChanged: (v) => lastValue = v,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(Switch));
      expect(lastValue, true);
    });

    testWidgets('no description when null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SettingsToggle(
              icon: Icons.vibration,
              title: 'Vibration',
              value: false,
            ),
          ),
        ),
      );

      expect(find.byType(SettingsToggle), findsOneWidget);
      expect(find.text('Vibration'), findsOneWidget);
    });
  });

  group('Provider defaults with mock repo', () {
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = SettingsRepository(prefs);
      container = ProviderContainer(
        overrides: [settingsRepositoryProvider.overrideWithValue(repo)],
      );
    });

    tearDown(() => container.dispose());

    test('settingsRepositoryProvider throws if not overridden', () {
      final c = ProviderContainer();
      expect(
        () => c.read(settingsRepositoryProvider),
        throwsA(isA<UnimplementedError>()),
      );
      c.dispose();
    });

    test('settingsThemeProvider defaults to 0', () {
      expect(container.read(settingsThemeProvider), 0);
    });

    test('settingsAccentColorProvider defaults to 0', () {
      expect(container.read(settingsAccentColorProvider), 0);
    });

    test('settingsFontSizeProvider defaults to 1', () {
      expect(container.read(settingsFontSizeProvider), 1);
    });

    test('settingsShowTimestampsProvider defaults to true', () {
      expect(container.read(settingsShowTimestampsProvider), true);
    });

    test('settingsCompactModeProvider defaults to false', () {
      expect(container.read(settingsCompactModeProvider), false);
    });

    test('settingsReducedMotionProvider defaults to false', () {
      expect(container.read(settingsReducedMotionProvider), false);
    });

    test('settingsNotificationsEnabledProvider defaults to true', () {
      expect(container.read(settingsNotificationsEnabledProvider), true);
    });

    test('settingsNotificationSoundProvider defaults to true', () {
      expect(container.read(settingsNotificationSoundProvider), true);
    });

    test('settingsNotificationVibrationProvider defaults to true', () {
      expect(container.read(settingsNotificationVibrationProvider), true);
    });

    test('settingsDiscoveryEnabledProvider defaults to true', () {
      expect(container.read(settingsDiscoveryEnabledProvider), true);
    });

    test('settingsRelayEnabledProvider defaults to true', () {
      expect(container.read(settingsRelayEnabledProvider), true);
    });

    test('providers reflect persisted values', () async {
      SharedPreferences.setMockInitialValues({
        'settings_theme_mode': 2,
        'settings_accent_color': 3,
        'settings_font_size': 0,
        'settings_show_timestamps': false,
        'settings_compact_mode': true,
        'settings_reduced_motion': true,
        'settings_notifications_enabled': false,
        'settings_notification_sound': false,
        'settings_notification_vibration': false,
        'settings_discovery_enabled': false,
        'settings_relay_enabled': false,
      });
      final prefs = await SharedPreferences.getInstance();
      final repo = SettingsRepository(prefs);
      final c = ProviderContainer(
        overrides: [settingsRepositoryProvider.overrideWithValue(repo)],
      );
      expect(c.read(settingsThemeProvider), 2);
      expect(c.read(settingsAccentColorProvider), 3);
      expect(c.read(settingsFontSizeProvider), 0);
      expect(c.read(settingsShowTimestampsProvider), false);
      expect(c.read(settingsCompactModeProvider), true);
      expect(c.read(settingsReducedMotionProvider), true);
      expect(c.read(settingsNotificationsEnabledProvider), false);
      expect(c.read(settingsNotificationSoundProvider), false);
      expect(c.read(settingsNotificationVibrationProvider), false);
      expect(c.read(settingsDiscoveryEnabledProvider), false);
      expect(c.read(settingsRelayEnabledProvider), false);
      c.dispose();
    });
  });

  group('SettingsMainScreen', () {
    late SettingsRepository repo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      repo = SettingsRepository(prefs);
    });

    ProviderScope buildApp() {
      return ProviderScope(
        overrides: [settingsRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: SettingsMainScreen()),
      );
    }

    testWidgets('renders Settings title', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();
      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('renders section headers', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.text('IDENTITY'), findsOneWidget);
      expect(find.text('PRIVACY & SECURITY'), findsOneWidget);
    });

    testWidgets('renders settings items', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.text('My Profile'), findsOneWidget);
      expect(find.text('Verification'), findsOneWidget);
    });

    testWidgets('renders version text', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('v1.0.0+1'),
        100,
        scrollable: find.byType(Scrollable),
      );
      expect(find.text('v1.0.0+1'), findsOneWidget);
    });
  });

  group('AppearanceSettingsScreen', () {
    late SettingsRepository repo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      repo = SettingsRepository(prefs);
    });

    ProviderScope buildApp() {
      return ProviderScope(
        overrides: [settingsRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: AppearanceSettingsScreen()),
      );
    }

    testWidgets('renders Appearance title', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();
      expect(find.text('Appearance'), findsOneWidget);
    });

    testWidgets('renders top section titles', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.text('Theme'), findsOneWidget);
      expect(find.text('Accent Color'), findsOneWidget);
    });

    testWidgets('renders theme radio options', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.text('System default'), findsOneWidget);
      expect(find.text('Light'), findsOneWidget);
      expect(find.text('Dark'), findsOneWidget);
    });

    testWidgets('renders font size label', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Font size'),
        100,
        scrollable: find.byType(Scrollable),
      );
      expect(find.text('Font size'), findsOneWidget);
    });

    testWidgets('renders 6 accent color chips', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.byType(GestureDetector), findsWidgets);
    });
  });

  group('AboutScreen', () {
    late SettingsRepository repo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      repo = SettingsRepository(prefs);
    });

    ProviderScope buildApp() {
      return ProviderScope(
        overrides: [settingsRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: AboutScreen()),
      );
    }

    testWidgets('renders About OneBit title in AppBar', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.text('About OneBit'), findsOneWidget);
    });

    testWidgets('renders app name', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.text('OneBit'), findsOneWidget);
    });

    testWidgets('renders version', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.text('1.0.0+1'), findsOneWidget);
    });

    testWidgets('renders description text', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.textContaining('decentralized'), findsOneWidget);
    });

    testWidgets('renders Licenses tile', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.text('Licenses'), findsOneWidget);
    });

    testWidgets('renders Version tile', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.text('Version'), findsOneWidget);
    });
  });
}
