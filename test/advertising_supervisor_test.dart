import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/features/ble/advertising_supervisor.dart';

void main() {
  group('shouldAdvertise (pure policy)', () {
    // Baseline: radio up, identity in hand, nothing forbidding it, and the
    // standing preference on with visibility allowed.
    bool call({
      bool operational = true,
      bool identityLoaded = true,
      bool stealth = false,
      bool alwaysAdvertise = true,
      bool discovery = true,
      bool nearbyIntent = false,
    }) =>
        shouldAdvertise(
          operational: operational,
          identityLoaded: identityLoaded,
          stealth: stealth,
          alwaysAdvertise: alwaysAdvertise,
          discovery: discovery,
          nearbyIntent: nearbyIntent,
        );

    test('advertises by default (always-advertise on, visible, reachable)',
        () {
      expect(call(), isTrue);
    });

    test('never advertises until the radio is operational', () {
      expect(call(operational: false), isFalse);
    });

    test('never advertises without a loaded identity', () {
      expect(call(identityLoaded: false), isFalse);
    });

    test('stealth is a hard gate even with every other reason to advertise',
        () {
      expect(call(stealth: true), isFalse);
      // Even an explicit Nearby request loses to stealth.
      expect(call(stealth: true, nearbyIntent: true), isFalse);
    });

    test('always-advertise requires discovery (the visibility switch)', () {
      expect(call(alwaysAdvertise: true, discovery: false), isFalse);
    });

    test('turning always-advertise off stops advertising when Nearby is shut',
        () {
      expect(call(alwaysAdvertise: false, nearbyIntent: false), isFalse);
    });

    test('the Nearby screen keeps the device on the air even with '
        'always-advertise off', () {
      expect(call(alwaysAdvertise: false, nearbyIntent: true), isTrue);
    });

    test('an explicit Nearby request ignores the discovery switch', () {
      // Opening Nearby to be found is an explicit action; the standing
      // visibility preference only gates the persistent (always) path.
      expect(call(discovery: false, nearbyIntent: true), isTrue);
    });

    test('advertise + nearby intent still respects stealth and radio', () {
      expect(
        call(stealth: true, alwaysAdvertise: true, nearbyIntent: true),
        isFalse,
      );
      expect(call(operational: false, nearbyIntent: true), isFalse);
      expect(call(identityLoaded: false, nearbyIntent: true), isFalse);
    });
  });
}
