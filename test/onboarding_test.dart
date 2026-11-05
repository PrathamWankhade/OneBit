import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/data/preferences/onboarding_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('OnboardingRepository', () {
    test('isComplete returns false by default', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = OnboardingRepository(prefs);
      expect(repo.isComplete, false);
    });

    test('setComplete marks onboarding as done', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = OnboardingRepository(prefs);

      await repo.setComplete();

      expect(repo.isComplete, true);
    });

    test('isComplete persists across instances', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo1 = OnboardingRepository(prefs);
      await repo1.setComplete();

      final repo2 = OnboardingRepository(prefs);
      expect(repo2.isComplete, true);
    });

    group('reconcile', () {
      test('clears a stale flag when no identity exists', () async {
        final prefs = await SharedPreferences.getInstance();
        final repo = OnboardingRepository(prefs);
        await repo.setComplete();

        await repo.reconcile(hasIdentity: false);

        expect(repo.isComplete, false);
        expect(prefs.getBool('onboarding_complete'), isNull);
      });

      test('sets the flag when an identity exists without it', () async {
        final prefs = await SharedPreferences.getInstance();
        final repo = OnboardingRepository(prefs);

        await repo.reconcile(hasIdentity: true);

        expect(repo.isComplete, true);
        expect(prefs.getBool('onboarding_complete'), true);
      });

      test('leaves a matching flag untouched', () async {
        final prefs = await SharedPreferences.getInstance();
        final repo = OnboardingRepository(prefs);

        await repo.reconcile(hasIdentity: false);
        expect(repo.isComplete, false);

        await repo.setComplete();
        await repo.reconcile(hasIdentity: true);
        expect(repo.isComplete, true);
      });
    });
  });
}
