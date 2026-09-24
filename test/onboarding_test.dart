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
  });
}
