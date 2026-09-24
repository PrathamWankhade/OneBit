import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/app/app.dart';
import 'package:onebit/data/database/app_database.dart';
import 'package:onebit/features/settings/data/settings_repository.dart';
import 'package:onebit/features/settings/data/settings_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

AppDatabase createTestDb() => AppDatabase.test(DatabaseConnection(NativeDatabase.memory()));

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  ProviderScope buildApp(AppDatabase db) {
    final settingsRepo = SettingsRepository(prefs);
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        settingsRepositoryProvider.overrideWithValue(settingsRepo),
        settingsRepositoryInitProvider.overrideWith(
          (ref) async => settingsRepo,
        ),
      ],
      child: const OneBitApp(),
    );
  }

  testWidgets('OneBitApp shows onboarding on fresh start', (tester) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final db = createTestDb();
    await tester.pumpWidget(buildApp(db));
    for (var i = 0; i < 45; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.textContaining('OneBit'), findsWidgets);
    expect(find.text('\$ run'), findsOneWidget);

    await db.close();
  });

  testWidgets('Onboarding steps are navigable', (tester) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final db = createTestDb();
    await tester.pumpWidget(buildApp(db));
    for (var i = 0; i < 45; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // Step 1: Welcome
    expect(find.text('Welcome to OneBit'), findsOneWidget);
    await tester.tap(find.text('\$ run'));

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    // Step 2: How it works
    expect(find.text('How OneBit works'), findsOneWidget);
    await tester.tap(find.text('Continue'));

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    // Step 3: Create identity
    expect(find.text('Create your identity'), findsOneWidget);

    await db.close();
  });

  testWidgets('App root widget exists', (_) async {
    const app = OneBitApp();
    expect(app, isA<Widget>());
  });
}
