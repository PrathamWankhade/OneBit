import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:onebit/core/errors/failure.dart';
import 'package:onebit/core/result/result.dart';
import 'package:onebit/features/media/attachments/attachment.dart';
import 'package:onebit/features/media/storage/attachment_store.dart';
import 'package:onebit/features/media/storage/storage_statistics.dart';

/// The production [AttachmentStore]: a folder hierarchy under [root].
///
/// Layout:
/// ```
/// <root>/
///   attachments/<category>/<safeName>   staged payloads
///   temp/<sessionId>                     receive-side assembly files
///   downloads/<safeName>                 finalized inbound payloads
///   cache/                               disk byte cache
/// ```
/// All paths stored in the catalog are media-root-relative and re-resolved
/// through [resolve] (traversal-guarded). Implementations never escape this
/// seam: hashing is a single SHA-256 pass while copying.
final class FileStore implements AttachmentStore {
  FileStore({
    required this._root,
    this.partitionQuotaBytes = 4 * 1024 * 1024 * 1024,
  });

  final Directory _root;
  final int partitionQuotaBytes;

  /// The configured media root (test overrides / callers that need it).
  Directory get mediaRoot => _root;

  Directory get _attachments => Directory('${_root.path}/attachments');
  Directory get _temp => Directory('${_root.path}/temp');
  Directory get _downloads => Directory('${_root.path}/downloads');
  Directory get _cache => Directory('${_root.path}/cache');

  Future<void> _ensureRoot() async {
    await _attachments.create(recursive: true);
    await _temp.create(recursive: true);
    await _downloads.create(recursive: true);
    await _cache.create(recursive: true);
  }

  /// Captures the single [Digest] emitted by a chunked hash conversion.
  /// Strips path separators / control characters; garanteed leaves a
  /// meaningful extension when present.
  /// meaningful extension when present.
  static String _safeName(String fileName) {
    final cleaned = fileName
        .replaceAll(RegExp(r'[/\\]'), '_')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
    final trimmed = cleaned.trim();
    if (trimmed.isEmpty || trimmed == '.') return 'file';
    return trimmed;
  }

  static final Sha256 _sha256 = Sha256();

  static Future<String> _hashFile(File file) async {
    final sink = _sha256.newHashSink();
    await for (final chunk in file.openRead()) {
      sink.add(chunk);
    }
    sink.close();
    return _bytesToHex((await sink.hash()).bytes);
  }

  static String _bytesToHex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  @override
  Future<Result<StagedPayload>> stage({
    required String fileName,
    required MediaCategory category,
    String? sourcePath,
    List<int>? fileBytes,
  }) async {
    try {
      await _ensureRoot();
      final folder = Directory('${_attachments.path}/${category.name}');
      await folder.create(recursive: true);
      final safe = _safeName(fileName);
      final target = File('${folder.path}/$safe');
      var sizeBytes = 0;
      String sha256;
      if (sourcePath != null && await File(sourcePath).exists()) {
        sha256 = await _copyHashing(File(sourcePath), target);
      } else if (fileBytes != null) {
        sizeBytes = fileBytes.length;
        await target.writeAsBytes(fileBytes, flush: true);
        sha256 = _bytesToHex((await _sha256.hash(fileBytes)).bytes);
      } else {
        return const Err(
          MediaStorageFailure(
            operation: 'stage',
            message: 'no sourcePath or fileBytes supplied',
          ),
        );
      }
      return Ok(
        StagedPayload(
          relativePath: relative(target),
          sizeBytes: sizeBytes != 0 ? sizeBytes : await target.length(),
          sha256: sha256,
        ),
      );
    } on MediaStorageFailure catch (failure) {
      return Err(failure);
    } catch (error, stackTrace) {
      return Err(
        MediaStorageFailure(
          operation: 'stage',
          message: 'staging failed: $error',
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Future<String> _copyHashing(File source, File target) async {
    final accumulator = _sha256.newHashSink();
    final inStream = source.openRead();
    final outSink = target.openWrite();
    try {
      await for (final chunk in inStream) {
        accumulator.add(chunk);
        outSink.add(chunk);
      }
    } finally {
      await outSink.close();
    }
    accumulator.close();
    return _bytesToHex((await accumulator.hash()).bytes);
  }

  String relative(File file) {
    final rootPath = _root.path.replaceAll('\\', '/');
    final filePath = file.path.replaceAll('\\', '/');
    if (!filePath.startsWith('$rootPath/')) {
      throw MediaStorageFailure(
        operation: 'relative',
        message: 'path outside the media root: ${file.path}',
      );
    }
    return filePath.substring(rootPath.length + 1);
  }

  @override
  String resolve(String relativePath) {
    if (relativePath.isEmpty) {
      throw const MediaStorageFailure(
        operation: 'resolve',
        message: 'empty path',
      );
    }
    if (relativePath.contains('..')) {
      throw MediaStorageFailure(
        operation: 'resolve',
        message: 'path traversal blocked: $relativePath',
      );
    }
    final rootPath = _root.path.replaceAll('\\', '/');
    final resolved = File(
      '${_root.path}/$relativePath',
    ).absolute.path.replaceAll('\\', '/');
    if (!resolved.startsWith('$rootPath/')) {
      throw MediaStorageFailure(
        operation: 'resolve',
        message: 'resolved path escapes the media root: $resolved',
      );
    }
    return resolved;
  }

  @override
  Future<Uint8List> readChunk(
    String relativePath, {
    required int offset,
    required int length,
  }) async {
    final file = File(resolve(relativePath));
    final raf = await file.open(mode: FileMode.read);
    try {
      await raf.setPosition(offset);
      final total = await raf.length();
      final toRead = total - offset < length ? total - offset : length;
      final bytes = await raf.read(toRead);
      return Uint8List.fromList(bytes);
    } finally {
      await raf.close();
    }
  }

  @override
  Future<bool> exists(String relativePath) =>
      File(resolve(relativePath)).exists();

  @override
  Future<void> delete(String relativePath) async {
    final file = File(resolve(relativePath));
    if (await file.exists()) await file.delete();
  }

  @override
  Future<void> replacePayload(String relativePath, List<int> bytes) async {
    final target = File(resolve(relativePath));
    final sibling = File('${target.path}.swap');
    await sibling.writeAsBytes(bytes, flush: true);
    await sibling.rename(target.path);
  }

  @override
  Future<String> sha256Of(String relativePath) =>
      _hashFile(File(resolve(relativePath)));

  // ---- Receive-side temp files ------------------------------------------

  File _tempFile(String sessionId) {
    final safe = _safeName(sessionId);
    return File('${_temp.path}/$safe');
  }

  @override
  Future<void> appendTemp(String sessionId, List<int> bytes) async {
    await _ensureRoot();
    final raf = await _tempFile(sessionId).open(mode: FileMode.append);
    try {
      await raf.writeFrom(bytes);
    } finally {
      await raf.close();
    }
  }

  @override
  Future<void> writeTempAt(
    String sessionId,
    int offset,
    List<int> bytes,
  ) async {
    await _ensureRoot();
    // FileMode.writeOnly (NOT writeOnlyAppend): O_APPEND would force every
    // write to the file tail on POSIX/Android, ignoring setPosition — chunk
    // envelopes may arrive out of order and must land at their exact offset.
    final raf = await _tempFile(sessionId).open(mode: FileMode.writeOnly);
    try {
      await raf.setPosition(offset);
      await raf.writeFrom(bytes);
    } finally {
      await raf.close();
    }
  }

  @override
  Future<bool> tempExists(String sessionId) => _tempFile(sessionId).exists();

  @override
  Future<int> tempLength(String sessionId) async {
    final file = _tempFile(sessionId);
    return await file.exists() ? file.length() : 0;
  }

  @override
  Future<String> sha256Temp(String sessionId) =>
      _hashFile(_tempFile(sessionId));

  @override
  Future<String> finalizeTemp(String sessionId, String fileName) async {
    await _ensureRoot();
    final source = _tempFile(sessionId);
    final target = File('${_downloads.path}/${_safeName(fileName)}');
    if (await source.exists()) {
      await source.rename(target.path);
    }
    return relative(target);
  }

  @override
  Future<void> deleteTemp(String sessionId) async {
    final file = _tempFile(sessionId);
    if (await file.exists()) await file.delete();
  }

  @override
  Future<void> purgeTemps() async {
    await _ensureRoot();
    await for (final entity in _temp.list()) {
      if (entity is File) await entity.delete();
    }
  }

  // ---- Capacity / statistics --------------------------------------------

  @override
  Future<bool> storageAvailable(int bytes) async {
    final used = await _usedBytes();
    return used + bytes <= partitionQuotaBytes;
  }

  Future<int> _usedBytes() async {
    var total = 0;
    for (final dir in [_attachments, _temp, _downloads, _cache]) {
      total += await _dirBytes(dir);
    }
    return total;
  }

  static Future<int> _dirBytes(Directory dir) async {
    if (!await dir.exists()) return 0;
    var total = 0;
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        total += await entity.length();
      }
    }
    return total;
  }

  @override
  Future<Result<StorageStatistics>> statistics() async {
    try {
      final payloadBytes = await _dirBytes(_attachments);
      final tempBytes = await _dirBytes(_temp);
      final cacheBytes = await _dirBytes(_cache);
      await _ensureRoot();
      var attachmentCount = 0;
      await for (final entity in _attachments.list(recursive: true)) {
        if (entity is File) attachmentCount++;
      }
      return Ok(
        StorageStatistics(
          rootBytes: await _dirBytes(_root),
          freeBytes:
              partitionQuotaBytes - (payloadBytes + tempBytes + cacheBytes),
          payloadBytes: payloadBytes,
          tempBytes: tempBytes,
          cacheBytes: cacheBytes,
          attachmentCount: attachmentCount,
        ),
      );
    } catch (error, stackTrace) {
      return Err(
        MediaStorageFailure(
          operation: 'statistics',
          message: 'statistics scan failed: $error',
          stackTrace: stackTrace,
        ),
      );
    }
  }
}
