import 'dart:async';

import 'package:onebit/features/reliable/reliable_channel.dart';

/// Fake channel for deterministic testing of the reliable transfer layer.
///
/// Simulates BLE delivery with configurable loss, duplication, and timing.
class FakeReliableChannel implements ReliableChannel {
  FakeReliableChannel({this.onSend});

  /// Optional callback invoked when bytes are sent.
  void Function(List<int> bytes)? onSend;

  final _incomingController = StreamController<List<int>>.broadcast();
  bool _connected = true;

  @override
  bool get isConnected => _connected;

  @override
  Future<void> send(List<int> bytes) async {
    if (!_connected) throw Exception('channel disconnected');
    onSend?.call(bytes);
  }

  @override
  Stream<List<int>> get incoming => _incomingController.stream;

  /// Simulate bytes arriving from the remote peer.
  void receive(List<int> bytes) {
    if (!_incomingController.isClosed) {
      _incomingController.add(bytes);
    }
  }

  /// Simulate a remote peer disconnecting.
  void simulateDisconnect() {
    _connected = false;
  }

  /// Simulate the connection being restored.
  void simulateReconnect() {
    _connected = true;
  }

  /// Dispose the fake channel.
  void dispose() {
    _connected = false;
    _incomingController.close();
  }
}
