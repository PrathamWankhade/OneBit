import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/app/router_notifier.dart';
import 'package:onebit/data/preferences/onboarding_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('RouterNotifier', () {
    test('redirect forces onboarding when not complete', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = OnboardingRepository(prefs);
      final notifier = RouterNotifier(repo);

      expect(repo.isComplete, false);
      expect(notifier.redirect, isNotNull);
    });

    test('redirect allows onboarding after completion', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = OnboardingRepository(prefs);
      final notifier = RouterNotifier(repo);

      await notifier.completeOnboarding();
      expect(repo.isComplete, true);
    });

    test('completeOnboarding marks onboarding as done', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = OnboardingRepository(prefs);
      final notifier = RouterNotifier(repo);

      expect(repo.isComplete, false);

      await notifier.completeOnboarding();

      expect(repo.isComplete, true);
    });

    test('notifyListeners is called after completion', () async {
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
