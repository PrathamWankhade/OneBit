/// Abstract communication channel for the reliable transfer layer.
///
/// Decouples reliability logic from the raw BLE transport.
/// For production: implemented by [BleServiceChannel].
/// For tests: implemented by [FakeReliableChannel].
abstract class ReliableChannel {
  /// Send raw bytes to the connected peer.
  ///
  /// Returns a Future that completes when the BLE write is acknowledged
  /// by the BLE stack (not the application-level ACK).
  Future<void> send(List<int> bytes);

  /// Stream of raw bytes received from the peer.
  Stream<List<int>> get incoming;

  /// Whether the underlying connection is alive.
  bool get isConnected;
}
