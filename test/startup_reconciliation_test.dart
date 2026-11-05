import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/app/app.dart';
import 'package:onebit/data/database/app_database.dart';
import 'package:onebit/data/preferences/onboarding_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A database that fails the one question startup asks.
class _FailingDatabase extends AppDatabase {
  _FailingDatabase()
      : super.test(DatabaseConnection(NativeDatabase.memory()));

  @override
  Future<LocalIdentityData?> getLocalIdentity() async {
    throw StateError('database unavailable');
  }
}

/// The onboarding flag and the identity row are two sources of truth for
/// one question. These tests pin what startup does when they disagree.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  ProviderContainer? container;

  setUp(() {
    db = AppDatabase.test(DatabaseConnection(NativeDatabase.memory()));
  });

  tearDown(() async {
    container?.dispose();
    container = null;
    await db.close();
  });

  /// Build the app's startup providers over [prefs] and a database, run
  /// the router-notifier provider (the thing that reconciles), and hand
  /// back the repository whose flag the router will read.
  Future<OnboardingRepository> start({
    required bool flagComplete,
    required bool withIdentity,
    AppDatabase? database,
  }) async {
    final target = database ?? db;
    SharedPreferences.setMockInitialValues({
      if (flagComplete) 'onboarding_complete': true,
    });
    final prefs = await SharedPreferences.getInstance();

    if (withIdentity) {
      await target.createLocalIdentity(
        displayName: 'Alice',
        publicKey: 'ab' * 32,
      );
    }

    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWith((ref) async => prefs),
        databaseProvider.overrideWithValue(target),
      ],
    );
    await container!.read(routerNotifierProvider.future);
    return OnboardingRepository(prefs);
  }

  group('startup reconciliation', () {
    test('a stale complete flag with no identity sends the user to onboarding',
        () async {
      final repo = await start(flagComplete: true, withIdentity: false);

      expect(repo.isComplete, false);
    });

    test('an identity without the flag keeps the user out of onboarding',
        () async {
      final repo = await start(flagComplete: false, withIdentity: true);

      expect(repo.isComplete, true);
    });

    test('a complete flag with an identity is left alone', () async {
      final repo = await start(flagComplete: true, withIdentity: true);

      expect(repo.isComplete, true);
    });

    test('an empty install is left alone', () async {
      final repo = await start(flagComplete: false, withIdentity: false);

      expect(repo.isComplete, false);
    });

    test('a database that cannot answer leaves the flag untouched', () async {
      // "No answer" must not be read as "no identity" — that would push a
      // working install into onboarding, where creating a second identity
      // would replace the live one.
      final failing = _FailingDatabase();

      final repo = await start(
        flagComplete: true,
        withIdentity: false,
        database: failing,
      );

      expect(repo.isComplete, true);
      await failing.close();
    });
  });
}
