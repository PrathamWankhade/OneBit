import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/core/logging/app_logger.dart';
import 'package:onebit/features/ble/ble_providers.dart';
import 'package:onebit/features/ble/ble_state.dart';
import 'package:onebit/features/identity/identity_providers.dart';
import 'package:onebit/features/settings/data/settings_providers.dart';

/// Whether the Nearby screen wants the device on the air right now.
///
/// Nearby sets this to true when it opens and when the user manually
/// starts advertising, and false when the user stops or the screen
/// closes. It is only a *request*: the [AdvertisingSupervisor] is the
/// single thing that actually starts or stops the radio, so closing
/// Nearby can no longer kill an advertisement the app wants to keep
/// running under "Advertise continuously".
final nearbyAdvertisingIntentProvider = StateProvider<bool>((_) => false);

/// The whole advertising policy in one pure, testable function.
///
/// The radio goes on the air when the transport can carry it
/// ([operational]), the identity has settled so the advertisement can carry
/// a key ([identityLoaded]), and nothing forbids it ([stealth]). It then
/// stays up for either of two reasons: the standing "advertise
/// continuously" preference (which also requires [discovery], the user's
/// visibility switch), or the Nearby screen actively asking to be found
/// ([nearbyIntent] — an explicit action on the discovery screen, so it
/// does not re-consult [discovery]).
///
/// [identityLoaded] means the local identity has *finished loading*, not
/// that it is necessarily non-null: a device that has settled on "no
/// identity yet" still advertises (anonymously), exactly as it did before
/// the supervisor existed — it just never advertises on a key that is
/// still in flight.
bool shouldAdvertise({
  required bool operational,
  required bool identityLoaded,
  required bool stealth,
  required bool alwaysAdvertise,
  required bool discovery,
  required bool nearbyIntent,
}) =>
    operational &&
    identityLoaded &&
    !stealth &&
    ((alwaysAdvertise && discovery) || nearbyIntent);

/// The single owner of BLE advertising.
///
/// Watches the settings, the radio, the identity and the Nearby screen's
/// intent, and reconciles the radio to match [shouldAdvertise]. Because it
/// is the only caller of start/stop, there is exactly one place where the
/// "is advertising" state can drift — and [BleService.startAdvertising] is
/// idempotent, so a redundant reconcile is a no-op rather than a second
/// session.
class AdvertisingSupervisor {
  AdvertisingSupervisor(this._ref) {
    _ref.listen<bool>(
      settingsAlwaysAdvertiseProvider,
      (_, _) => _reconcile(),
    );
    _ref.listen<bool>(settingsStealthEnabledProvider, (_, _) => _reconcile());
    _ref.listen<bool>(
      settingsDiscoveryEnabledProvider,
      (_, _) => _reconcile(),
    );
    _ref.listen<bool>(nearbyAdvertisingIntentProvider, (_, _) => _reconcile());
    // The advertisement carries the local public key, so an identity that
    // arrives late re-triggers a reconcile rather than leaving the device
    // anonymously on the air.
    _ref.listen(localIdentityProvider, (_, _) => _reconcile());
    _ref.listen<BleState>(bleStateProvider, (_, next) {
      if (next.isOperational) _reconcile();
    });
    _reconcile();
  }

  final Ref _ref;

  /// Re-entrancy guard: a setting that flips mid-reconcile queues one
  /// follow-up pass rather than racing a second against the first.
  bool _reconciling = false;

  /// The advertising state the policy currently asks for.
  ///
  /// Reads defensively: before the settings repo or the radio has
  /// answered, the answer is "off" — a cold start never puts the device
  /// on the air by accident.
  bool get _desired {
    try {
      final ble = _ref.read(bleStateProvider);
      return shouldAdvertise(
        operational: ble.isOperational,
        // `hasValue` (not `valueOrNull != null`): advertise once the
        // identity has *settled*, even to null — a device with no identity
        // yet still goes on the air (anonymously), it just never does so
        // on a key that is still loading.
        identityLoaded: _ref.read(localIdentityProvider).hasValue,
        stealth: _ref.read(settingsStealthEnabledProvider),
        alwaysAdvertise: _ref.read(settingsAlwaysAdvertiseProvider),
        discovery: _ref.read(settingsDiscoveryEnabledProvider),
        nearbyIntent: _ref.read(nearbyAdvertisingIntentProvider),
      );
    } catch (_) {
      // No settings repo (as in a bare test container) — stay off.
      return false;
    }
  }

  Future<void> _reconcile() async {
    if (_reconciling) return;
    _reconciling = true;
    try {
      final notifier = _ref.read(bleStateProvider.notifier);
      final desired = _desired;
      final advertising = _ref.read(bleStateProvider).isAdvertising;

      if (desired && !advertising) {
        final identity = _ref.read(localIdentityProvider).valueOrNull;
        await notifier.startAdvertising(
          identityPublicKeyBytes: identity?.publicKeyBytes,
        );
      } else if (!desired && advertising) {
        await notifier.stopAdvertising();
      }
    } catch (e) {
      // A radio that refuses is reflected in bleStateProvider; never let a
      // reconcile failure surface as an unhandled error.
      AppLogger.warning('AdvertisingSupervisor: reconcile failed: $e');
    } finally {
      _reconciling = false;
    }
  }
}

/// App-scoped supervisor, held alive for the life of the [ProviderScope].
///
/// Declares every provider it reads so that a test (or the app) that
/// overrides any one of them is free to leave the supervisor itself
/// un-overridden — Riverpod otherwise refuses to build it across an
/// override boundary it cannot see.
final advertisingSupervisorProvider = Provider<AdvertisingSupervisor>(
  (ref) {
    return AdvertisingSupervisor(ref);
  },
  dependencies: [
    settingsAlwaysAdvertiseProvider,
    settingsStealthEnabledProvider,
    settingsDiscoveryEnabledProvider,
    nearbyAdvertisingIntentProvider,
    localIdentityProvider,
    bleStateProvider,
  ],
);
