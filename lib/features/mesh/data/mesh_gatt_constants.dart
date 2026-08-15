/// GATT identifiers reserved for the mesh packet channel.
///
/// The packet protocol phase defines the on-air framing; the identifiers
/// are stable so both the transport adapter and the native side agree.
abstract final class MeshGattConstants {
  MeshGattConstants._();

  /// Service that carries mesh PacketReceived payloads.
  static const String meshServiceUuid = '6E7B1E00-6B1A-4B74-9E72-1F1A2D9BC003';

  /// Inbound (neighbor → this node) payloads.
  static const String meshRxCharacteristic =
      '6E7B1E00-6B1A-4B74-9E72-1F1A2D9BC004';

  /// Outbound (this node → neighbor) payloads.
  static const String meshTxCharacteristic =
      '6E7B1E00-6B1A-4B74-9E72-1F1A2D9BC005';

  /// Reserved for the store-and-forward phase: advertising nodes that
  /// declare this service offer to hold undelivered traffic for later
  /// delivery. No node advertises it yet; the adapter maps it onto the
  /// [`MeshCapability.storeForward`] neighbor flag so future phases can
  /// gate relaying without changing the routing core.
  static const String storeForwardServiceUuid =
      '6E7B1E00-6B1A-4B74-9E72-1F1A2D9BC006';
}
