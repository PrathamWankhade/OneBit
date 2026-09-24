import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/app/router_notifier.dart';
import 'package:onebit/data/preferences/onboarding_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('RouterNotifier', () {
    test('completeOnboarding marks onboarding as done', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = OnboardingRepository(prefs);
      final notifier = RouterNotifier(repo);

      expect(repo.isComplete, false);

      await notifier.completeOnboarding();

      expect(repo.isComplete, true);
    });

    test('notifyListeners is called after completion', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = OnboardingRepository(prefs);
      final notifier = RouterNotifier(repo);
      var notified = false;
      notifier.addListener(() => notified = true);

      await notifier.completeOnboarding();

      expect(notified, true);
    });
  });
}
