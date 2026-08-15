import 'dart:async';

import 'dtn_envelope.dart';
import 'dtn_failure.dart';
import 'dtn_queue_snapshot.dart';
import 'dtn_statistics.dart';

/// The store-forward contract of this phase.
///
/// Upper layers (Phase 8 messaging, and today any caller) store envelopes
/// and observe their delivery without knowing anything about queues,
/// persistence or scheduling.
abstract interface class DTNRepository {
  /// Store one envelope for delivery.
  ///
  /// Idempotent for an existing [DtnPacket.packetId]: the second store
  /// returns the stored envelope rather than duplicating it.
  ///
  /// Throws [DtnFailure] on `queueOverflow`, `invalidRequest` or
  /// `persistenceFailed`.
  Future<DtnPacket> store(DtnPacket packet);

  /// Cancel an envelope that has not entered a terminal state yet.
  ///
  /// Returns true when it was cancelled; throws [DtnFailure.notFound] or
  /// [DtnFailure.alreadyTerminal] otherwise.
  Future<bool> cancel(String packetId);

  /// Current state of an envelope (or null when unknown to this node).
  Future<DtnPacket?> statusOf(String packetId);

  /// Wait for the next envelope that this node may hand to an upper layer.
  ///
  /// Phase 8 turns this into `listenForDeliveries`; today it is the only
  /// way to consume an inbound envelope and stays available for tests and
  /// the dev screens.
  Future<DtnPacket> observeDelivered();

  /// Stream of every queue snapshot (dev monitors).
  Stream<DtnQueueSnapshot> queueSnapshots();

  /// Stream of statistics snapshots (dev monitors).
  Stream<DtnStatisticsSnapshot> statisticsSnapshots();

  /// Latest remembered statistics (after `start` or restore).
  DtnStatisticsSnapshot get latestStatistics;
}
