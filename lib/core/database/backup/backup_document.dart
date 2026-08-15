import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

/// Version-1 database backup header, stored in plaintext.
@immutable
final class BackupHeader {
  const BackupHeader({
    required this.schemaVersion,
    required this.exportedAt,
    required this.nodeId,
    required this.appVersion,
    required this.tableCount,
    required this.rowCount,
    required this.integrity,
    this.compression = _compressionZlib,
    this.encrypted = false,
  });

  static const String magic = 'ONEBITDB';
  static const int formatVersion = 1;
  static const String _compressionZlib = 'zlib';
  static const String _compressionNone = 'none';

  /// Drift schema version at export time (gates forward imports).
  final int schemaVersion;

  /// ISO-8601 UTC timestamp of the export.
  final String exportedAt;

  /// `NODE-XXXX-XXXX` identity that produced the backup.
  final String nodeId;

  /// App version string at export time.
  final String appVersion;

  /// Number of tables in the payload.
  final int tableCount;

  /// Total rows across all tables.
  final int rowCount;

  /// sha256 hex of the uncompressed payload bytes.
  final String integrity;

  /// `zlib` (default) or `none`.
  final String compression;

  /// True when the payload section is a [BackupEnvelope].
  final bool encrypted;

  Map<String, Object?> toJson() => <String, Object?>{
    'magic': magic,
    'format': formatVersion,
    'schema': schemaVersion,
    'exported_at': exportedAt,
    'node_id': nodeId,
    'app_version': appVersion,
    'tables': tableCount,
    'rows': rowCount,
    'integrity': integrity,
    'compression': compression,
    'encrypted': encrypted,
  };

  static BackupHeader fromJson(Map<String, Object?> json) => BackupHeader(
    schemaVersion: json['schema']! as int,
    exportedAt: json['exported_at']! as String,
    nodeId: json['node_id']! as String,
    appVersion: json['app_version']! as String,
    tableCount: json['tables']! as int,
    rowCount: json['rows']! as int,
    integrity: json['integrity']! as String,
    compression: json['compression'] as String? ?? _compressionZlib,
    encrypted: json['encrypted'] as bool? ?? false,
  );

  static bool isValidCompression(String value) =>
      value == _compressionZlib || value == _compressionNone;
}

/// A parsed backup document: [header] plus the (possibly encrypted) payload.
@immutable
final class BackupDocument {
  const BackupDocument({required this.header, required this.payload});

  final BackupHeader header;

  /// Compressed payload bytes, or the raw envelope when [BackupHeader.encrypted].
  final Uint8List payload;
}

/// Summary of a completed import, for UI/log confirmation.
@immutable
final class BackupImportSummary {
  const BackupImportSummary({
    required this.nodeId,
    required this.exportedAt,
    required this.schemaVersion,
    required this.tableCount,
    required this.rowCount,
    required this.importedAt,
  });

  final String nodeId;
  final DateTime exportedAt;
  final int schemaVersion;
  final int tableCount;
  final int rowCount;
  final DateTime importedAt;
}

/// Builds and parses the `ONEBITDB` byte format.
///
/// ```text
/// [8-byte magic: "ONEBITDB"][1-byte format version]
/// [header JSON (UTF-8), newline-terminated]
/// [payload: envelope bytes (encrypted) or zlib/none-compressed JSON]
/// ```
abstract final class BackupDocumentCodec {
  const BackupDocumentCodec._();

  /// Encodes [header] + [payloadBytes] into a full backup document.
  static Uint8List encode({
    required BackupHeader header,
    required List<int> payloadBytes,
  }) {
    final headerBytes = utf8.encode('${jsonEncode(header.toJson())}\n');
    final out = Uint8List(8 + 1 + headerBytes.length + payloadBytes.length);
    out.setAll(0, utf8.encode(BackupHeader.magic));
    out[8] = BackupHeader.formatVersion;
    out.setAll(9, headerBytes);
    out.setAll(9 + headerBytes.length, payloadBytes);
    return out;
  }

  /// Parses and structurally validates a document.
  ///
  /// Throws [FormatException] (mapped by callers to [BackupFailure]) on any
  /// mismatch.
  static BackupDocument decode(List<int> bytes) {
    if (bytes.length < 9) {
      throw const FormatException('Backup document is too short');
    }
    if (ascii.decode(bytes.sublist(0, 8)) != BackupHeader.magic) {
      throw const FormatException('Not a OneBit database backup');
    }
    if (bytes[8] != BackupHeader.formatVersion) {
      throw FormatException('Unsupported backup format: ${bytes[8]}');
    }
    var headerEnd = 9;
    while (headerEnd < bytes.length && bytes[headerEnd] != 0x0A) {
      headerEnd++;
    }
    if (headerEnd >= bytes.length) {
      throw const FormatException('Backup header is not terminated');
    }
    final header = BackupHeader.fromJson(
      (jsonDecode(utf8.decode(bytes.sublist(9, headerEnd))) as Map)
          .cast<String, Object?>(),
    );
    final payload = Uint8List.fromList(bytes.sublist(headerEnd + 1));
    return BackupDocument(header: header, payload: payload);
  }
}

/// Compression + integrity helpers over the backup payload.
abstract final class BackupPayload {
  const BackupPayload._();

  static final Sha256 _sha256 = Sha256();

  /// Compresses [jsonBytes] (zlib when smaller, else `none`) and computes the
  /// integrity hash of the uncompressed bytes.
  static Future<({String compression, Uint8List bytes, String integrity})> pack(
    List<int> jsonBytes,
  ) async {
    final integrity = await hashHex(jsonBytes);
    final compressed = zlib.encode(jsonBytes);
    final useZlib = compressed.length < jsonBytes.length;
    return (
      compression: useZlib ? 'zlib' : 'none',
      bytes: Uint8List.fromList(useZlib ? compressed : jsonBytes),
      integrity: integrity,
    );
  }

  /// Decompresses [bytes] per [compression] and verifies [integrity].
  static Future<Uint8List> unpack({
    required List<int> bytes,
    required String compression,
    required String integrity,
  }) async {
    final List<int> uncompressed = switch (compression) {
      'zlib' => zlib.decode(bytes),
      BackupHeader._compressionNone => bytes,
      _ => throw FormatException('Unknown compression: $compression'),
    };
    if (await hashHex(uncompressed) != integrity) {
      throw const FormatException('Backup integrity check failed');
    }
    return Uint8List.fromList(uncompressed);
  }

  /// sha256 hex of [bytes].
  static Future<String> hashHex(List<int> bytes) async {
    final digest = await _sha256.hash(bytes);
    return digest.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
