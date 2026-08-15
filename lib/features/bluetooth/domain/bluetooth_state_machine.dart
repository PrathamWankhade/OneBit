import 'dart:async';

import 'package:onebit/features/bluetooth/domain/bluetooth_events.dart';
import 'package:onebit/features/bluetooth/domain/bluetooth_state.dart';

/// The authoritative application transport state machine.
///
/// Pure Dart and side-effect free: repositories/controllers feed events via
/// [handle] and observe the resulting [state] snapshot. Guards inside
/// [_resolve] reject illegal transitions and leave the machine unchanged.
/// Every state change is broadcast on [states].
///
/// The machine models the application's *focus* — one scan, one advertise,
/// one primary link. The native side keeps multiple devices concurrent;
/// this object is the auditable, UI-facing view of that focus.
final class BluetoothStateMachine {
  BluetoothStateMachine({this._maxReconnectAttempts = 3});

  final int _maxReconnectAttempts;

  final StreamController<BluetoothState> _controller =
      StreamController<BluetoothState>.broadcast();

  BluetoothState _state = BluetoothState.bluetoothOff;
  String? _deviceId;
  int _negotiatedMtu = 23;
  bool _mtuReady = false;
  bool _gattReady = false;
  int _reconnectAttempts = 0;
  Object? _lastError;

  /// Current machine state.
  BluetoothState get state => _state;

  /// The peer of the monitored link, when in a link path.
  String? get deviceId => _deviceId;

  /// Negotiated MTU, or the 23-byte default before negotiation.
  int get negotiatedMtu => _negotiatedMtu;

  /// True once MTU negotiation (or its fallback) settled.
  bool get mtuReady => _mtuReady;

  /// True once GATT services were discovered on the link.
  bool get gattReady => _gattReady;

  /// How many automatic reconnects have been scheduled this session.
  int get reconnectAttempts => _reconnectAttempts;

  /// Reason of the latest rejected event or failure, for diagnostics.
  Object? get lastError => _lastError;

  /// Broadcasts every accepted state change.
  Stream<BluetoothState> get states => _controller.stream;

  /// The current snapshot, re-emitted on subscribe.
  Stream<BluetoothState> get statesWithInitial async* {
    yield _state;
    yield* _controller.stream;
  }

  /// Feeds [event] into the machine.
  ///
  /// Returns the resulting state — the previous state when the event was
  /// rejected, and the new state after a legal transition.
  BluetoothState handle(BluetoothEvent event) {
    final resolved = _resolve(event);
    if (resolved == null) {
      _lastError = 'Rejected ${event.runtimeType} in ${_state.rawName}';
      return _state;
    }
    if (resolved != _state) {
      _lastError = null;
      _state = resolved;
      _controller.add(_state);
    }
    return _state;
  }

  /// Resolves [event] to a target state, or `null` to reject.
  ///
  /// Side effects on machine flags are performed here, guarded so flags
  /// only change together with a legal transition.
  BluetoothState? _resolve(BluetoothEvent event) {
    switch (event) {
      case AdapterOnEvent():
        return _from({BluetoothState.bluetoothOff, BluetoothState.error})
            ? BluetoothState.initializing
            : null;
      case AdapterOffEvent():
        _clearLink();
        return BluetoothState.bluetoothOff;
      case InitializedEvent():
        return _from({BluetoothState.initializing})
            ? BluetoothState.ready
            : null;
      case InitializeFailedEvent():
        return _from({BluetoothState.initializing})
            ? BluetoothState.bluetoothUnavailable
            : null;
      case ScanStartedEvent():
        return _from(_radioActive()) ? BluetoothState.scanning : null;
      case ScanStoppedEvent():
        return _from({BluetoothState.scanning, BluetoothState.deviceFound})
            ? BluetoothState.ready
            : null;
      case DeviceFoundEvent():
        return _from({BluetoothState.scanning})
            ? BluetoothState.deviceFound
            : null;
      case AdvertisingStartedEvent():
        return _from({
              ..._radioActive(),
              BluetoothState.disconnected,
              BluetoothState.deviceFound,
            })
            ? BluetoothState.advertising
            : null;
      case AdvertisingStoppedEvent():
        return _from({BluetoothState.advertising, BluetoothState.deviceFound})
            ? BluetoothState.ready
            : null;
      case ConnectRequestedEvent(:final deviceId):
        if (!_from({
          BluetoothState.ready,
          BluetoothState.scanning,
          BluetoothState.deviceFound,
          BluetoothState.disconnected,
          BluetoothState.reconnecting,
          BluetoothState.advertising,
        })) {
          return null;
        }
        _deviceId = deviceId;
        _reconnectAttempts = 0;
        return BluetoothState.connecting;
      case ConnectedEvent(:final deviceId):
        if (!_from({BluetoothState.connecting})) return null;
        _deviceId = deviceId;
        return BluetoothState.connected;
      case MtuStartedEvent():
        return _from({BluetoothState.connected})
            ? BluetoothState.mtuNegotiation
            : null;
      case MtuNegotiatedEvent(:final mtu):
        if (!_from({BluetoothState.mtuNegotiation, BluetoothState.connected}) ||
            mtu < 23) {
          return null;
        }
        _negotiatedMtu = mtu;
        _mtuReady = true;
        return BluetoothState.serviceDiscovery;
      case MtuFailedEvent():
        if (!_from({BluetoothState.mtuNegotiation})) return null;
        _negotiatedMtu = 23;
        _mtuReady = true; // Fallback: continue at the default MTU.
        return BluetoothState.serviceDiscovery;
      case ServicesDiscoveredEvent():
        if (!_from({BluetoothState.serviceDiscovery}) || !_mtuReady) {
          return null;
        }
        _gattReady = true;
        return BluetoothState.linkReady;
      case DisconnectRequestedEvent():
        if (!_from(_linkStates())) return null;
        return BluetoothState.disconnecting;
      case DisconnectedEvent():
        if (!_from({..._linkStates(), BluetoothState.disconnecting})) {
          return null;
        }
        _clearLink();
        return BluetoothState.disconnected;
      case ReconnectRequestedEvent():
        if (!_from({BluetoothState.disconnected}) ||
            _reconnectAttempts >= _maxReconnectAttempts) {
          return null;
        }
        _reconnectAttempts += 1;
        return BluetoothState.reconnecting;
      case LinkLostEvent():
        if (!_from(_linkStates())) return null;
        if (_reconnectAttempts < _maxReconnectAttempts) {
          _reconnectAttempts += 1;
          return BluetoothState.reconnecting;
        }
        _clearLink();
        return BluetoothState.disconnected;
      case FatalAdapterErrorEvent():
        return _state == BluetoothState.error ? null : BluetoothState.error;
      case UnknownEvent():
        return null;
    }
  }

  bool _from(Set<BluetoothState> sources) => sources.contains(_state);

  Set<BluetoothState> _radioActive() => {
    BluetoothState.ready,
    BluetoothState.scanning,
    BluetoothState.deviceFound,
    BluetoothState.advertising,
  };

  Set<BluetoothState> _linkStates() => {
    BluetoothState.connecting,
    BluetoothState.connected,
    BluetoothState.mtuNegotiation,
    BluetoothState.serviceDiscovery,
    BluetoothState.linkReady,
    BluetoothState.reconnecting,
  };

  void _clearLink() {
    _deviceId = null;
    _mtuReady = false;
    _gattReady = false;
  }

  /// True when the radio is usable in the current state.
  bool get isRadioOperational => _state.isRadioOperational;

  void dispose() {
    _controller.close();
  }
}
