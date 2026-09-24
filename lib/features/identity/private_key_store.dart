import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stable internal storage key for the identity private key.
const String _privateKeyStorageKey = 'onebit.identity.private_key';

/// Minimal secure storage boundary for identity private key material.
///
/// Wraps [FlutterSecureStorage] with a focused API: read, write, delete.
/// Uses platform-backed protected storage (Android Keystore, iOS Keychain).
class PrivateKeyStore {
  PrivateKeyStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  /// Read the private key bytes from secure storage.
  ///
  /// Returns null if no key is stored.
  /// Throws [PrivateKeyStoreException] on read failure.
  Future<Uint8List?> read() async {
    try {
      final json = await _storage.read(key: _privateKeyStorageKey);
      if (json == null) return null;
      final decoded = jsonDecode(json) as List<dynamic>;
      return Uint8List.fromList(decoded.cast<int>());
    } on Exception catch (e) {
      throw PrivateKeyStoreException('Failed to read private key: $e');
    }
  }

  /// Write private key bytes to secure storage.
  ///
  /// Throws [PrivateKeyStoreException] on write failure.
  Future<void> write(Uint8List keyBytes) async {
    try {
      final json = jsonEncode(keyBytes.toList());
      await _storage.write(key: _privateKeyStorageKey, value: json);
    } on Exception catch (e) {
      throw PrivateKeyStoreException('Failed to write private key: $e');
    }
  }

  /// Delete the private key from secure storage.
  ///
  /// Throws [PrivateKeyStoreException] on delete failure.
  Future<void> delete() async {
    try {
      await _storage.delete(key: _privateKeyStorageKey);
    } on Exception catch (e) {
      throw PrivateKeyStoreException('Failed to delete private key: $e');
    }
  }
}

/// Exception for private key store operations.
class PrivateKeyStoreException implements Exception {
  PrivateKeyStoreException(this.message);
  final String message;

  @override
  String toString() => 'PrivateKeyStoreException: $message';
}
