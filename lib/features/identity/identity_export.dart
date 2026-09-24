import 'dart:convert';
import 'dart:typed_data';

import 'package:onebit/features/identity/identity_fingerprint.dart';
import 'package:onebit/features/identity/identity_models.dart';
import 'package:onebit/features/identity/identity_repository.dart';

/// Canonical public identity representation for export/import.
///
/// This is the single authoritative format for OneBit public identity
/// interchange. It contains only public material — never private keys.
class PublicIdentity {
  PublicIdentity({
    required this.formatVersion,
    required this.identityType,
    required this.publicKeyHex,
    this.displayName,
    this.fingerprint,
  });

  /// Format version of the identity serialization.
  final int formatVersion;

  /// Cryptographic identity type (e.g. "ed25519").
  final String identityType;

  /// Hex-encoded public key bytes.
  final String publicKeyHex;

  /// Optional human-readable display name.
  final String? displayName;

  /// Optional pre-computed fingerprint for verification.
  final String? fingerprint;

  /// Convert to JSON-encodable map.
  Map<String, dynamic> toJson() => {
        'formatVersion': formatVersion,
        'identityType': identityType,
        'publicKey': publicKeyHex,
        if (displayName != null) 'displayName': displayName,
        if (fingerprint != null) 'fingerprint': fingerprint,
      };

  /// Serialize to JSON string.
  String toJsonString() => jsonEncode(toJson());

  /// Deserialize from JSON map.
  factory PublicIdentity.fromJson(Map<String, dynamic> json) {
    return PublicIdentity(
      formatVersion: json['formatVersion'] as int,
      identityType: json['identityType'] as String,
      publicKeyHex: json['publicKey'] as String,
      displayName: json['displayName'] as String?,
      fingerprint: json['fingerprint'] as String?,
    );
  }

  /// Deserialize from JSON string.
  factory PublicIdentity.fromJsonString(String jsonString) {
    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    return PublicIdentity.fromJson(json);
  }

  /// Raw public key bytes (derived from publicKeyHex).
  Uint8List get publicKeyBytes => IdentityRepository.hexToBytes(publicKeyHex);
}

/// Export a local identity as a public identity payload.
///
/// This function never accesses the private key. It reads only public
/// metadata from [identity] and computes the fingerprint.
Future<String> exportPublicIdentity(IdentityInfo identity) async {
  if (identity.publicKeyBytes == null || identity.identityId == null) {
    throw ArgumentError('Identity has no cryptographic material');
  }

  final fingerprint = await computeFingerprint(identity.publicKeyBytes!);

  final public = PublicIdentity(
    formatVersion: identityFormatVersion,
    identityType: 'ed25519',
    publicKeyHex: identity.identityId!,
    displayName: identity.displayName,
    fingerprint: fingerprint,
  );

  return public.toJsonString();
}

/// Result of importing a public identity.
class ImportResult {
  ImportResult({
    required this.identity,
    required this.isLocalIdentity,
  });

  /// The parsed public identity.
  final PublicIdentity identity;

  /// Whether this identity matches the local identity.
  final bool isLocalIdentity;
}

/// Maximum allowed size for an imported identity JSON payload.
const int kMaxImportPayloadSize = 8192;

/// Maximum allowed length for a display name in an identity payload.
const int kMaxDisplayNameLength = 128;

/// Import and validate a public identity payload.
///
/// Returns an [ImportResult] on success, or throws [ImportError] on failure.
/// This function never writes to the database or touches private storage.
ImportResult importPublicIdentity(
  String jsonString, {
  String? localPublicKeyHex,
}) {
  // Enforce input size limit before parsing
  if (jsonString.length > kMaxImportPayloadSize) {
    throw ImportError('Payload too large');
  }

  // Parse JSON
  final Map<String, dynamic> json;
  try {
    json = jsonDecode(jsonString) as Map<String, dynamic>;
  } catch (_) {
    throw ImportError('Invalid JSON');
  }

  // Validate required fields
  if (!json.containsKey('formatVersion')) {
    throw ImportError('Missing formatVersion');
  }
  if (!json.containsKey('identityType')) {
    throw ImportError('Missing identityType');
  }
  if (!json.containsKey('publicKey')) {
    throw ImportError('Missing publicKey');
  }

  // Validate types
  if (json['formatVersion'] is! int) {
    throw ImportError('formatVersion must be an integer');
  }
  if (json['identityType'] is! String) {
    throw ImportError('identityType must be a string');
  }
  if (json['publicKey'] is! String) {
    throw ImportError('publicKey must be a string');
  }

  // Validate format version
  final version = json['formatVersion'] as int;
  if (version != identityFormatVersion) {
    throw ImportError('Unsupported format version: $version');
  }

  // Validate identity type
  final keyType = json['identityType'] as String;
  if (keyType != 'ed25519') {
    throw ImportError('Unsupported identity type: $keyType');
  }

  // Validate public key
  final publicKeyHex = json['publicKey'] as String;
  if (publicKeyHex.isEmpty) {
    throw ImportError('publicKey is empty');
  }

  // Validate hex encoding
  if (!RegExp(r'^[0-9a-fA-F]+$').hasMatch(publicKeyHex)) {
    throw ImportError('publicKey is not valid hex');
  }

  // Validate key length (Ed25519 public key = 32 bytes = 64 hex chars)
  if (publicKeyHex.length != 64) {
    throw ImportError('publicKey must be 64 hex characters (32 bytes)');
  }

  // Validate optional displayName length
  if (json.containsKey('displayName')) {
    final name = json['displayName'];
    if (name is! String) {
      throw ImportError('displayName must be a string');
    }
    if (name.length > kMaxDisplayNameLength) {
      throw ImportError('displayName too long');
    }
  }

  // Validate optional fingerprint type
  if (json.containsKey('fingerprint') && json['fingerprint'] is! String) {
    throw ImportError('fingerprint must be a string');
  }

  // Parse and construct
  final public = PublicIdentity.fromJson(json);

  // Check if this matches the local identity
  final isLocal = localPublicKeyHex != null &&
      publicKeyHex.toLowerCase() == localPublicKeyHex.toLowerCase();

  return ImportResult(
    identity: public,
    isLocalIdentity: isLocal,
  );
}

/// Error type for identity import failures.
class ImportError implements Exception {
  ImportError(this.message);
  final String message;

  @override
  String toString() => 'ImportError: $message';
}
