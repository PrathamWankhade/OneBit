import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/app/router.dart';
import 'package:onebit/app/router_notifier.dart';
import 'package:onebit/data/preferences/onboarding_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('createRouter returns a GoRouter', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = OnboardingRepository(prefs);
    final notifier = RouterNotifier(repo);

    final router = createRouter(notifier);

    expect(router, isNotNull);
  });
}
