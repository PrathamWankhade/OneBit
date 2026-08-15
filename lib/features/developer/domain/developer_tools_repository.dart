import 'package:onebit/core/result/result.dart';

/// Repository contract for developer tools.
///
/// Provides diagnostics (logs, capability probes) without exposing internal
/// framework objects to the UI. The developer panel in a later phase renders
/// through this boundary.
abstract interface class DeveloperToolsRepository {
  /// Emits the most recent log records (ring buffer snapshot stream).
  Stream<Result<List<Object>>> watchRecentLogs();

  /// Pings the native host and returns a latency measurement (or failure).
  Future<Result<Duration>> measureChannelLatency();
}
