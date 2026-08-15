import 'dart:io';
import 'dart:typed_data';

import 'package:onebit/features/media/cache/media_cache.dart';

/// On-disk [BlobCache]: one file per key under a dedicated directory.
///
/// Byte-level sibling of [MemoryCache]; the attachment-payload and
/// thumbnail cache tier. Keys must be filesystem-safe (the storage layer
/// uses SHA-256 hex keys) — other keys are rejected.
final class DiskCache implements BlobCache {
  DiskCache({required this._directory});

  final Directory _directory;

  int? _bytes;
  int? _entries;

  File _fileOf(String key) {
    if (!RegExp(r'^[a-f0-9]{16,}$').hasMatch(key)) {
      throw ArgumentError.value(key, 'key', 'expected a hex key');
    }
    return File('${_directory.path}/$key.bin');
  }

  Future<void> _ensure() async {
    if (_bytes != null) return;
    await _directory.create(recursive: true);
    var bytes = 0;
    var entries = 0;
    await for (final entity in _directory.list()) {
      if (entity is File) {
        entries++;
        bytes += await entity.length();
      }
    }
    _bytes = bytes;
    _entries = entries;
  }

  @override
  Future<Uint8List?> get(String key) async {
    await _ensure();
    final file = _fileOf(key);
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  @override
  Future<void> put(String key, Uint8List bytes) async {
    await _ensure();
    final file = _fileOf(key);
    final previous = await file.exists() ? await file.length() : 0;
    await file.writeAsBytes(bytes, flush: true);
    _bytes = _bytes! - previous + bytes.length;
  }

  @override
  Future<void> evict(String key) async {
    await _ensure();
    final file = _fileOf(key);
    if (!await file.exists()) return;
    _bytes = _bytes! - await file.length();
    _entries = _entries! - 1;
    await file.delete();
  }

  @override
  Future<void> clear() async {
    await _directory.create(recursive: true);
    await for (final entity in _directory.list()) {
      if (entity is File && entity.path.endsWith('.bin')) {
        await entity.delete();
      }
    }
    _bytes = 0;
    _entries = 0;
  }

  @override
  int get byteSize => _bytes ?? 0;

  @override
  int get entryCount => _entries ?? 0;
}
