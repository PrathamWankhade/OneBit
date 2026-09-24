import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/features/ble/ble_providers.dart';
import 'package:onebit/features/ble/ble_state.dart';

/// Monitors app lifecycle (foreground/background) and pauses/resumes
/// BLE scanning when the app transitions.
///
/// Does NOT disconnect active connections — those survive background transitions.
/// Does NOT stop advertising — the native layer handles background advertising.
///
/// Also monitors BLE radio state changes: if Bluetooth turns off while
/// scanning is active, the scan is stopped proactively.
class BleLifecycleObserver extends WidgetsBindingObserver {
  BleLifecycleObserver(this._ref);

  final Ref _ref;

  /// Whether scanning was active before the app was backgrounded.
  bool _wasScanning = false;

  /// Whether the observer has been initialized.
  bool _initialized = false;

  /// Initialize by adding this observer to the binding.
  ///
  /// Also sets up a listener on BLE radio state to stop scanning
  /// proactively when Bluetooth is turned off.
  void initialize() {
    if (_initialized) return;
    _initialized = true;
    WidgetsBinding.instance.addObserver(this);

    // Listen for BLE radio state changes and stop scanning when Bluetooth
    // turns off, preventing the native layer from erroring on an active scan.
    _ref.listen<BleState>(bleStateProvider, (previous, next) {
      if (next.radio == BleRadioState.off || next.radio == BleRadioState.unknown) {
        final bleNotifier = _ref.read(bleStateProvider.notifier);
        if (next.isScanning) {
          _wasScanning = false; // Don't resume when BT comes back.
          bleNotifier.stopScan();
        }
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final bleNotifier = _ref.read(bleStateProvider.notifier);
    final bleState = _ref.read(bleStateProvider);

    switch (state) {
      case AppLifecycleState.paused:
        // App is going to background. Remember scan state.
        _wasScanning = bleState.isScanning;
        if (_wasScanning) {
          bleNotifier.stopScan();
        }
        break;

      case AppLifecycleState.resumed:
        // App came back to foreground.
        // Do NOT auto-resume scanning — let the user decide.
        // Active connections survive the background transition.
        break;

      case AppLifecycleState.inactive:
        // App is partially obscured (e.g., on iOS during phone call).
        // No action needed — connections survive.
        break;

      case AppLifecycleState.detached:
        // App is being terminated. The providerScope disposal
        // will handle full cleanup via ref.onDispose chains.
        break;

      case AppLifecycleState.hidden:
        // App is hidden but still alive. No action needed.
        break;
    }
  }

  /// Remove the observer from the binding.
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }
}

/// Provider that creates and manages the BLE lifecycle observer.
///
/// The observer is created once at app scope and lives for the entire
/// application lifetime. It is disposed when the ProviderScope is torn down.
final bleLifecycleObserverProvider = Provider<BleLifecycleObserver>((ref) {
  final observer = BleLifecycleObserver(ref);
  observer.initialize();
  ref.onDispose(observer.dispose);
  return observer;
});
