import 'dart:async';

import 'package:onebit/core/logging/app_logger.dart';
import 'package:onebit/features/reliable/reliable_channel.dart';
import 'package:onebit/features/reliable/transfer.dart';

/// Configuration for the reliable transfer layer.
class ReliableTransferConfig {
  const ReliableTransferConfig({
    this.ackTimeoutMs = 5000,
    this.maxAttempts = 3,
    this.duplicateCacheSize = 64,
  });

  /// How long to wait for an ACK before retrying.
  final int ackTimeoutMs;

  /// Maximum send attempts (1 initial + N-1 retries).
  final int maxAttempts;

  /// Number of recently-seen transfer IDs kept for duplicate detection.
  final int duplicateCacheSize;
}

/// Manages reliable byte transfers over an unreliable channel.
///
/// Handles:
/// - Transfer ID assignment
/// - ACK matching
/// - Timeout + bounded retry
/// - Duplicate detection on receiver
/// - Delivery result
/// - Disconnect / disposal cleanup
class ReliableTransferManager {
  ReliableTransferManager({
    required this._channel,
    ReliableTransferConfig? config,
    this._onDataReceived,
  })  : _config = config ?? const ReliableTransferConfig() {
    _incomingSub = _channel.incoming.listen(handleIncoming);
  }

  final ReliableChannel _channel;
  final ReliableTransferConfig _config;
  final void Function(List<int> payload, int transferId)? _onDataReceived;
  StreamSubscription<List<int>>? _incomingSub;

  /// Monotonically increasing transfer ID (wraps at 256).
  final TransferId _transferId = TransferId();

  /// Currently pending outbound transfer.
  _PendingTransfer? _pending;

  /// Timer for ACK timeout.
  Timer? _ackTimer;

  /// Recent inbound transfer IDs for duplicate detection (FIFO, bounded).
  final List<int> _receivedIds = [];

  /// Stream controller for transfer state changes.
  final _stateController =
      StreamController<TransferState>.broadcast();

  /// Stream of transfer state updates.
  Stream<TransferState> get stateStream => _stateController.stream;

  /// Whether a transfer is currently in progress.
  bool get hasPendingTransfer => _pending != null;

  /// Current transfer state.
  TransferState get currentState =>
      _pending != null ? TransferState.waitingForAck : TransferState.delivered;

  // ── Sender API ────────────────────────────────────────────

  /// Send [payload] reliably to the connected peer.
  ///
  /// Returns a Future that completes with [TransferResult.delivered]
  /// when the ACK is received, [TransferResult.failed] after retries
  /// are exhausted or on channel error, or [TransferResult.cancelled]
  /// if the channel disconnects or the manager is disposed.
  Future<TransferResult> sendReliable(List<int> payload) async {
    if (!_channel.isConnected) {
      AppLogger.warning('Reliable send rejected: channel not connected');
      return TransferResult.failed;
    }

    if (_pending != null) {
      AppLogger.warning('Reliable send rejected: transfer already pending');
      return TransferResult.failed;
    }

    final id = _transferId.next();
    _pending = _PendingTransfer(
      id: id,
      payload: payload,
      attempts: 1,
    );

    _emitState(TransferState.waitingForAck);
    _startAckTimer();

    final envelope = TransferEnvelope(
      type: TransferEnvelope.dataType,
      transferId: id,
      payload: payload,
    );

    try {
      await _channel.send(envelope.encode());
      AppLogger.info('Reliable send: id=$id, ${payload.length} bytes, attempt 1');
    } catch (e) {
      AppLogger.error('Reliable send failed (write error)', e);
      _completeTransfer(TransferState.failed);
      return TransferResult.failed;
    }

    return _pending!.completer.future;
  }

  // ── Receiver API ──────────────────────────────────────────

  /// Process incoming raw bytes from the channel.
  ///
  /// Call this when bytes arrive on the communication characteristic.
  void handleIncoming(List<int> bytes) {
    final envelope = TransferEnvelope.decode(bytes);
    if (envelope == null) {
      AppLogger.warning('Reliable: malformed envelope ignored');
      return;
    }

    if (envelope.isAck) {
      _handleAck(envelope.transferId);
    } else if (envelope.isData) {
      _handleData(envelope);
    }
  }

  // ── Disconnect / Bluetooth OFF ───────────────────────────

  /// Notify the manager that the BLE connection has dropped.
  ///
  /// Fails any pending transfer immediately.
  void onDisconnect() {
    _cancelAckTimer();
    if (_pending != null && !_pending!.completer.isCompleted) {
      AppLogger.warning(
          'Reliable: connection lost — failing transfer ${_pending!.id}');
      _completeTransfer(TransferState.failed);
    }
  }

  /// Cancel any active transfer and clean up.
  void cancelAll() {
    _cancelAckTimer();
    if (_pending != null && !_pending!.completer.isCompleted) {
      _completeTransfer(TransferState.cancelled);
    }
  }

  /// Dispose the manager and clean up all resources.
  void dispose() {
    _cancelAckTimer();
    _incomingSub?.cancel();
    if (_pending != null && !_pending!.completer.isCompleted) {
      _completeTransfer(TransferState.cancelled);
    }
    _receivedIds.clear();
    if (!_stateController.isClosed) {
      _stateController.close();
    }
  }

  // ── Internal ──────────────────────────────────────────────

  void _handleAck(int transferId) {
    final pending = _pending;
    if (pending == null) {
      // Unknown ACK — ignore safely.
      AppLogger.info('Reliable: unknown ACK for id=$transferId (ignored)');
      return;
    }

    if (pending.id != transferId) {
      // ACK for a different transfer — ignore.
      AppLogger.info(
          'Reliable: ACK id=$transferId != pending id=${pending.id} (ignored)');
      return;
    }

    _cancelAckTimer();
    AppLogger.info('Reliable: ACK received for id=$transferId — delivered');
    _completeTransfer(TransferState.delivered);
  }

  void _handleData(TransferEnvelope envelope) {
    final id = envelope.transferId;

    // Duplicate detection.
    if (_receivedIds.contains(id)) {
      AppLogger.info('Reliable: duplicate DATA id=$id (ACK sent again)');
      _sendAck(id);
      return;
    }

    // Record this ID.
    _receivedIds.add(id);
    if (_receivedIds.length > _config.duplicateCacheSize) {
      _receivedIds.removeAt(0);
    }

    _sendAck(id);

    // Deliver to upper layer.
    if (_onDataReceived != null) {
      AppLogger.info(
          'Reliable: DATA received id=$id, ${envelope.payload.length} bytes');
      _onDataReceived(envelope.payload, id);
    }
  }

  void _sendAck(int transferId) {
    final ack = TransferEnvelope(
      type: TransferEnvelope.ackType,
      transferId: transferId,
    );
    _channel.send(ack.encode()).catchError((e) {
      AppLogger.warning('Reliable: failed to send ACK for id=$transferId');
    });
  }

  void _startAckTimer() {
    _cancelAckTimer();
    _ackTimer = Timer(
      Duration(milliseconds: _config.ackTimeoutMs),
      _onAckTimeout,
    );
  }

  void _cancelAckTimer() {
    _ackTimer?.cancel();
    _ackTimer = null;
  }

  void _onAckTimeout() {
    final pending = _pending;
    if (pending == null || pending.completer.isCompleted) return;

    if (pending.attempts >= _config.maxAttempts) {
      AppLogger.warning(
          'Reliable: retry limit reached for id=${pending.id} '
          '(${pending.attempts} attempts)');
      _completeTransfer(TransferState.failed);
      return;
    }

    pending.attempts++;
    _emitState(TransferState.retrying);

    final envelope = TransferEnvelope(
      type: TransferEnvelope.dataType,
      transferId: pending.id,
      payload: pending.payload,
    );

    AppLogger.info(
        'Reliable: retrying id=${pending.id}, attempt ${pending.attempts}');

    _channel.send(envelope.encode()).catchError((e) {
      AppLogger.error('Reliable: retry write failed for id=${pending.id}', e);
      _completeTransfer(TransferState.failed);
    });

    _startAckTimer();
  }

  void _completeTransfer(TransferState finalState) {
    _cancelAckTimer();
    final pending = _pending;
    if (pending == null) return;

    if (!pending.completer.isCompleted) {
      switch (finalState) {
        case TransferState.delivered:
          pending.completer.complete(TransferResult.delivered);
        case TransferState.failed:
          pending.completer.complete(TransferResult.failed);
        case TransferState.cancelled:
          pending.completer.complete(TransferResult.cancelled);
        default:
          pending.completer.complete(TransferResult.failed);
      }
    }

    _emitState(finalState);
    _pending = null;
  }

  void _emitState(TransferState state) {
    if (!_stateController.isClosed) {
      _stateController.add(state);
    }
  }
}

/// Bookkeeping for one outbound reliable transfer.
class _PendingTransfer {
  _PendingTransfer({
    required this.id,
    required this.payload,
    required this.attempts,
  });

  final int id;
  final List<int> payload;
  int attempts;
  final completer = Completer<TransferResult>();
}
