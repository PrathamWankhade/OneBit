import 'dart:async';

import 'package:onebit/core/result/result.dart';
import 'package:onebit/features/dtn/domain/dtn_envelope.dart';

import 'transfer_envelope.dart';

/// The transport seam of the transfer engine.
///
/// Implementations (data layer) encode [MediaEnvelope]s into the DTN wire
/// and surface inbound radio packets for the engine's decode loop.
abstract interface class TransferGateway {
  /// Transmits one media envelope to [peerNodeId]. Returns the stored DTN
  /// packet (or an [Err] mapped from the transport failure).
  Future<Result<DtnPacket>> transmit(MediaEnvelope envelope, String peerNodeId);

  /// Envelopes that arrived at this node as final destination (broadcast;
  /// the engine subscribes once at start).
  Stream<DtnPacket> get inboundDeliveries;
}
