import 'package:shared_preferences/shared_preferences.dart';

const _kOnboardingCompleteKey = 'onboarding_complete';

class OnboardingRepository {
  const OnboardingRepository(this._prefs);

  final SharedPreferences _prefs;

  bool get isComplete => _prefs.getBool(_kOnboardingCompleteKey) ?? false;

  Future<bool> setComplete() => _prefs.setBool(_kOnboardingCompleteKey, true);

  /// Make the stored flag agree with whether an identity actually exists.
  ///
  /// The flag and the `local_identity` row are written by different
  /// subsystems at different times, so either can outlive the other: a
  /// restored preferences backup can arrive without the database, and a
  /// database can be cleared while the flag survives. When they disagree,
  /// the identity row is the fact and the flag is the cache.
  ///
  /// Both directions matter. Without an identity, the flag must clear so
  /// the router lets the user reach onboarding instead of dead-ending on
  /// "No identity found". With an identity, the flag must set so the user
  /// is never shown onboarding — creating a second identity there would
  /// replace the live one and orphan every peer that knows it.
  Future<void> reconcile({required bool hasIdentity}) async {
    if (hasIdentity == isComplete) return;
    if (hasIdentity) {
      await setComplete();
    } else {
      await clear();
    }
  }

  Future<bool> clear() => _prefs.remove(_kOnboardingCompleteKey);
}
