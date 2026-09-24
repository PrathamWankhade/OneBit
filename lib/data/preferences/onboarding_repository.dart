import 'package:shared_preferences/shared_preferences.dart';

const _kOnboardingCompleteKey = 'onboarding_complete';

class OnboardingRepository {
  const OnboardingRepository(this._prefs);

  final SharedPreferences _prefs;

  bool get isComplete => _prefs.getBool(_kOnboardingCompleteKey) ?? false;

  Future<bool> setComplete() => _prefs.setBool(_kOnboardingCompleteKey, true);
}
