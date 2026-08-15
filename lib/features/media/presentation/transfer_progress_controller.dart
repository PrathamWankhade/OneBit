import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/core/result/result.dart';
import 'package:onebit/features/media/domain/media_engine.dart';
import 'package:onebit/features/media/presentation/media_providers.dart';
import 'package:onebit/features/media/transfer/transfer_session.dart';
import 'package:onebit/features/media/transfer/transfer_state.dart';

/// Presentation state of one transfer session.
final class TransferProgressView {
  const TransferProgressView({
    this.session,
    this.fileName,
    this.sizeBytes = 0,
    this.speedBytesPerSecond = 0,
    this.eta,
    this.loading = false,
    this.notFound = false,
    this.failure,
  });

  /// Latest session snapshot (`null` until the first stream event).
  final TransferSession? session;

  /// Resolved catalog file name of the transferred attachment.
  final String? fileName;

  /// Whole payload size in bytes.
  final int sizeBytes;

  /// Smoothed throughput over the recent window.
  final double speedBytesPerSecond;

  /// Estimated time to completion under the current speed.
  final Duration? eta;

  /// Initial load in progress.
  final bool loading;

  /// No session exists for the requested id.
  final bool notFound;

  /// Stream / lookup failure detail.
  final Object? failure;

  TransferProgressView copyWith({
    TransferSession? session,
    String? fileName,
    int? sizeBytes,
    double? speedBytesPerSecond,
    Duration? eta,
    bool? loading,
    bool? notFound,
    Object? failure,
  }) => TransferProgressView(
    session: session ?? this.session,
    fileName: fileName ?? this.fileName,
    sizeBytes: sizeBytes ?? this.sizeBytes,
    speedBytesPerSecond: speedBytesPerSecond ?? this.speedBytesPerSecond,
    eta: eta ?? this.eta,
    loading: loading ?? this.loading,
    notFound: notFound ?? this.notFound,
    failure: failure ?? this.failure,
  );
}

/// Watches [MediaEngine.watchTransfer] and derives speed + ETA from the
/// session's byte counters.
final transferProgressControllerProvider = AsyncNotifierProvider.family
    .autoDispose<TransferProgressController, TransferProgressView, String>(
      TransferProgressController.new,
    );

final class TransferProgressController
    extends AsyncNotifier<TransferProgressView> {
  TransferProgressController(this.arg);

  /// Session id from the route.
  final String arg;

  static const Duration _window = Duration(seconds: 4);
  final List<(DateTime, int)> _samples = [];
  StreamSubscription<Result<TransferSession?>>? _sub;

  @override
  Future<TransferProgressView> build() async {
    final engine = ref.watch(mediaEngineProvider);
    ref.onDispose(() {
      _sub?.cancel();
      _samples.clear();
    });
    _sub = engine
        .watchTransfer(arg)
        .listen(
          (result) =>
              _onSession(result.value, failure: result.failure, engine: engine),
          onError: (Object error) {
            state = AsyncData(
              TransferProgressView(
                session: state.value?.session,
                fileName: state.value?.fileName,
                failure: error,
              ),
            );
          },
        );
    return const TransferProgressView(loading: true);
  }

  Future<void> _onSession(
    TransferSession? session, {
    required MediaEngine engine,
    Object? failure,
  }) async {
    if (session == null) {
      state = AsyncData(
        TransferProgressView(notFound: true, fileName: state.value?.fileName),
      );
      return;
    }
    String? fileName = state.value?.fileName;
    var sizeBytes = state.value?.sizeBytes ?? 0;
    if (fileName == null) {
      final attachment = (await engine.attachmentOf(
        session.attachmentId,
      )).value;
      if (attachment != null) {
        fileName = attachment.metadata.fileName;
        sizeBytes = attachment.metadata.sizeBytes;
      }
    }
    final speed = _track(session.bytesTransferred);
    final remaining = sizeBytes - session.bytesTransferred;
    final eta = speed > 0 && remaining > 0
        ? Duration(seconds: (remaining / speed).round())
        : null;
    state = AsyncData(
      TransferProgressView(
        session: session,
        fileName: fileName,
        sizeBytes: sizeBytes,
        speedBytesPerSecond: speed,
        eta: eta,
        failure: failure,
      ),
    );
  }

  double _track(int bytesTransferred) {
    final now = DateTime.now();
    _samples.add((now, bytesTransferred));
    _samples.removeWhere((s) => now.difference(s.$1) > _window);
    if (_samples.length < 2) return 0;
    final first = _samples.first;
    final last = _samples.last;
    final elapsed = last.$1.difference(first.$1).inMilliseconds;
    if (elapsed <= 0) return 0;
    return (last.$2 - first.$2) * 1000 / elapsed;
  }

  Future<void> pause() async {
    final engine = ref.read(mediaEngineProvider);
    final session = state.value?.session;
    if (session == null || !session.state.isActive) return;
    await engine.pauseTransfer(session.sessionId);
  }

  Future<void> resume() async {
    final engine = ref.read(mediaEngineProvider);
    final session = state.value?.session;
    if (session == null || session.state == TransferState.completed) return;
    await engine.resumeTransfer(session.sessionId);
  }

  Future<void> retry() async {
    final engine = ref.read(mediaEngineProvider);
    final session = state.value?.session;
    if (session == null) return;
    await engine.retryTransfer(session.sessionId);
  }

  Future<void> cancel() async {
    final engine = ref.read(mediaEngineProvider);
    final session = state.value?.session;
    if (session == null || session.state.isTerminal) return;
    await engine.cancelTransfer(session.sessionId);
  }
}
