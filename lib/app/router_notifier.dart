import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:onebit/data/preferences/onboarding_repository.dart';

const _kOnboardingPath = '/';
const _kHomePath = '/home';

class RouterNotifier extends ChangeNotifier {
  RouterNotifier(this._onboardingRepo);

  final OnboardingRepository _onboardingRepo;

  bool get _isOnboardingComplete => _onboardingRepo.isComplete;

  String? redirect(BuildContext context, GoRouterState state) {
    final location = state.uri.path;
    final onboardingDone = _isOnboardingComplete;

    // If onboarding is not complete, force user to onboarding
    if (!onboardingDone && location != _kOnboardingPath) {
      return _kOnboardingPath;
    }

    // If onboarding is complete and user is on onboarding, send to home
    if (onboardingDone && location == _kOnboardingPath) {
      return _kHomePath;
    }

    return null;
  }

  Future<void> completeOnboarding() async {
    await _onboardingRepo.setComplete();
    notifyListeners();
  }
}
