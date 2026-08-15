import 'package:flutter/foundation.dart';
import 'package:onebit/core/result/result.dart';

import '../attachments/attachment.dart';
import 'storage_statistics.dart';

/// The file-system seam of the media subsystem — the only place file bytes
/// ever cross. Everything else (engine, use cases, domain) depends on this
/// interface, so tests inject a memory or temp-dir store and `dart:io`
/// never leaks upward.
abstract interface class AttachmentStore {
  /// Copies [sourcePath] (or writes [fileBytes]) into
  /// `attachments/<folder>/` under a safe name, computing the whole-file
  /// SHA-256 in the same single pass. Returns the stored relative path.
  Future<Result<StagedPayload>> stage({
    required String fileName,
    required MediaCategory category,
    String? sourcePath,
    List<int>? fileBytes,
  });

  /// Resolves a media-root-relative path to a safe absolute path
  /// (traversal-guarded). Throws [MediaStorageFailure] on violations.
  String resolve(String relativePath);

  /// Reads a bounded byte window of [relativePath].
  Future<Uint8List> readChunk(
    String relativePath, {
    required int offset,
    required int length,
  });

  /// Whole-file SHA-256 (hex) of [relativePath].
  Future<String> sha256Of(String relativePath);

  /// Whether a payload exists.
  Future<bool> exists(String relativePath);

  /// Removes a payload (missing files are not an error).
  Future<void> delete(String relativePath);

  /// Replaces a payload in place (compression output) — writes a sibling
  /// temp file and renames over the original.
  Future<void> replacePayload(String relativePath, List<int> bytes);

  // ---- Receive-side temp files ------------------------------------------

  /// Appends [bytes] to `temp/<sessionId>` (creates the file lazily).
  Future<void> appendTemp(String sessionId, List<int> bytes);

  /// Writes [bytes] at an absolute [offset] of `temp/<sessionId>` — chunk
  /// envelopes may arrive out of order.
  Future<void> writeTempAt(String sessionId, int offset, List<int> bytes);

  /// Whether the temp file exists.
  Future<bool> tempExists(String sessionId);

  /// Current byte length of the temp file (0 when missing).
  Future<int> tempLength(String sessionId);

  /// Whole-file SHA-256 of the temp file.
  Future<String> sha256Temp(String sessionId);

  /// Renames `temp/<sessionId>` into `downloads/<safeName>` (atomic move)
  /// and returns the media-root-relative path.
  Future<String> finalizeTemp(String sessionId, String fileName);

  /// Purges the temp file.
  Future<void> deleteTemp(String sessionId);

  /// Purges every leftover temp file (startup sweep).
  Future<void> purgeTemps();

  // ---- Capacity / statistics --------------------------------------------

  /// Whether [bytes] more payload bytes fit under the media root.
  Future<bool> storageAvailable(int bytes);

  /// Health snapshot of the media root.
  Future<Result<StorageStatistics>> statistics();
}

/// One staged payload inside the media root.
@immutable
final class StagedPayload {
  const StagedPayload({
    required this.relativePath,
    required this.sizeBytes,
    required this.sha256,
  });

  final String relativePath;
  final int sizeBytes;
  final String sha256;
}
