import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:onebit/core/crypto/identity/exchange_crypto.dart';
import 'package:onebit/core/crypto/identity/fingerprint.dart';
import 'package:onebit/core/crypto/identity/node_id.dart';
import 'package:onebit/core/crypto/identity/qr_domain.dart';
import 'package:onebit/core/utils/secure_random_util.dart';

/// Produces a 64-byte Ed25519 signature over [message].
///
/// The signer is supplied by the caller (on device it delegates to the key
/// store bridge) so this codec stays free of platform concerns.
typedef PayloadSigner = Future<Uint8List> Function(List<int> message);

/// Verifies [signature] over [message] against a 32-byte [publicKey]
/// (the payload's `ed` key for identity cards).
typedef PayloadVerifier =
    Future<bool> Function(
      List<int> message,
      Uint8List signature,
      List<int> publicKey,
    );

/// Computes the X25519 shared secret with [remotePublicKey] using the
/// caller's own key material (seed in tests, Keystore on device).
///
/// Used by [QrPayloadCodec.decodeTransfer]: the envelope embeds the sender's
/// ephemeral X25519 public key, and the recipient derives
/// `ECDH(our private, ephemeral public)`.
typedef SharedSecretProvider =
    Future<Uint8List> Function(List<int> remotePublicKey);

/// Codec for the OneBit QR wire protocol.
///
/// Wire text shape: `OB1:<base64url(json)>`. Two payload types live on the
/// same wire:
///
/// - **identity card** (`id`): public identity (`ts`,`id`,`n`,`fp`,
///   `ed`,`x`) signed by the owner's Ed25519 key (`s`). Intercepted or
///   mangled cards fail signature verification.
/// - **identity transfer** (`xfer`): secret seeds, ECDH-sealed to the
///   recipient's X25519 public key using a fresh ephemeral X25519 key and
///   AES-256-GCM (`u` field). GCM supplies confidentiality and integrity, so
///   transfers are not additionally signed.
///
/// Canonicalization: fields are always serialized in [cardOrder]; the
/// signature (`s`) is folded out before signing/verification, so reparsing
/// reproduces exactly the bytes that were signed.
abstract final class QrPayloadCodec {
  /// Wire prefix for every QR payload.
  static const String prefix = 'OB1:';

  static const int _version = 1;
  static const int _ephemeralLength = 32;
  static const int _nonceLength = 12;
  static const int _macLength = 16;
  static const String _transferInfo = 'onebit/qr/transfer/v1';

  /// Field order for canonical serialization of both payload types.
  static const List<String> cardOrder = <String>[
    'v',
    't',
    'ts',
    'id',
    'n',
    'fp',
    'ed',
    'x',
    's',
    'u',
  ];

  /// Wire type token for identity cards.
  static const String cardType = 'id';

  /// Wire type token for identity transfers.
  static const String transferType = 'xfer';

  // ----------------------------------------------------------------------
  // Identity card
  // ----------------------------------------------------------------------

  /// Encodes and signs [card], returning the wire text to display as a QR.
  static Future<String> encodeCard(
    QrIdentityCard card, {
    required PayloadSigner signer,
  }) async {
    final canonical = _serialize(_cardFields(card), includeSignature: false);
    final signature = await signer(utf8.encode(canonical));
    final document = _serialize(
      _cardFields(card),
      includeSignature: true,
      signature: signature,
    );
    return _wrap(document);
  }

  /// Decodes wire [text] and verifies its signature with [verifier].
  static Future<QrIdentityCard> decodeCard(
    String text, {
    required PayloadVerifier verifier,
  }) async {
    final fields = _unwrap(text, expectedType: cardType);
    final signature = fields['s'];
    if (signature is! String) {
      throw const FormatException('Identity card is not signed');
    }
    final canonical = _serialize(fields, includeSignature: false);
    final publicKey = _fromB64(_requireString(fields, 'ed'));
    final ok = await verifier(
      utf8.encode(canonical),
      _fromB64(signature),
      publicKey,
    );
    if (!ok) {
      throw const FormatException(
        'Identity card signature failed verification',
      );
    }
    return _cardFromFields(fields);
  }

  // ----------------------------------------------------------------------
  // Identity transfer
  // ----------------------------------------------------------------------

  /// Seals [content] for [recipientPublicKey] (32 bytes) and returns the
  /// encrypted wire text. The ephemeral secret is discarded after use.
  static Future<String> encodeTransfer(
    QrTransferContent content, {
    required List<int> recipientPublicKey,
  }) async {
    _requireLength(recipientPublicKey, _ephemeralLength, 'recipientPublicKey');
    final ephemeralSeed = SecureRandomUtil.randomBytes(_ephemeralLength);
    final ephemeralPublic = await ExchangeCrypto.publicKeyFromSeed(
      ephemeralSeed,
    );
    final shared = await ExchangeCrypto.sharedSecret(
      keyPairSeed: ephemeralSeed,
      remotePublicKey: recipientPublicKey,
    );
    final key = await ExchangeCrypto.deriveKey(
      sharedSecret: shared,
      salt: ephemeralPublic,
      info: _transferInfo,
    );
    final nonce = SecureRandomUtil.randomBytes(_nonceLength);
    final box = await ExchangeCrypto.encrypt(
      key: key,
      clearText: utf8.encode(_contentJson(content)),
      nonce: nonce,
    );

    final envelopeBytes = _concatList(<List<int>>[
      ephemeralPublic,
      box.nonce,
      box.mac.bytes,
      box.cipherText,
    ]);
    final fields = <String, Object?>{
      'v': _version,
      't': transferType,
      'ts': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'id': content.nodeId,
      'n': content.displayName,
      'fp': content.fingerprintHex,
      'u': _toB64(envelopeBytes),
    };
    return _wrap(_serialize(fields));
  }

  /// Opens [text] (an identity transfer addressed to our X25519 key) and
  /// returns the transferred identity. [sharedSecretProvider] computes the
  /// ECDH secret against the ephemeral key embedded in the envelope.
  static Future<QrTransferContent> decodeTransfer(
    String text, {
    required SharedSecretProvider sharedSecretProvider,
  }) async {
    final fields = _unwrap(text, expectedType: transferType);
    final envelope = _fromB64(_requireString(fields, 'u'));
    if (envelope.length <= _macLength + _nonceLength + _ephemeralLength) {
      throw const FormatException('Transfer envelope is truncated');
    }
    final ephemeralPublicKey = envelope.sublist(0, _ephemeralLength);
    final nonce = envelope.sublist(
      _ephemeralLength,
      _ephemeralLength + _nonceLength,
    );
    final mac = envelope.sublist(
      _ephemeralLength + _nonceLength,
      _ephemeralLength + _nonceLength + _macLength,
    );
    final cipherText = envelope.sublist(
      _ephemeralLength + _nonceLength + _macLength,
    );
    final shared = await sharedSecretProvider(ephemeralPublicKey);
    final key = await ExchangeCrypto.deriveKey(
      sharedSecret: shared,
      salt: ephemeralPublicKey,
      info: _transferInfo,
    );
    final box = SecretBox(
      Uint8List.fromList(cipherText),
      nonce: Uint8List.fromList(nonce),
      mac: Mac(Uint8List.fromList(mac)),
    );
    final cleared = await ExchangeCrypto.decrypt(key: key, box: box);
    final parsed = jsonDecode(utf8.decode(cleared));
    if (parsed is! Map) {
      throw const FormatException('Transfer cleartext is not an object');
    }
    return _transferFromFields(parsed.cast<String, Object?>());
  }

  // ----------------------------------------------------------------------
  // Field mapping
  // ----------------------------------------------------------------------

  static Map<String, Object?> _cardFields(QrIdentityCard card) =>
      <String, Object?>{
        'v': _version,
        't': cardType,
        'ts': card.timestamp,
        'id': card.nodeId,
        'n': card.displayName,
        'fp': card.fingerprintHex,
        'ed': _toB64(card.ed25519PublicKey),
        'x': _toB64(card.x25519PublicKey),
      };

  static QrIdentityCard _cardFromFields(Map<String, Object?> fields) =>
      _validatedCard(
        nodeId: _requireString(fields, 'id'),
        displayName: _requireString(fields, 'n'),
        fingerprintHex: _requireString(fields, 'fp').toLowerCase(),
        ed25519PublicKey: _fromB64(_requireString(fields, 'ed')),
        x25519PublicKey: _fromB64(_requireString(fields, 'x')),
        timestamp: (fields['ts']! as num).toInt(),
        signature: _fromB64(_requireString(fields, 's')),
      );

  static QrIdentityCard _validatedCard({
    required String nodeId,
    required String displayName,
    required String fingerprintHex,
    required List<int> ed25519PublicKey,
    required List<int> x25519PublicKey,
    required int timestamp,
    required List<int> signature,
  }) {
    if (!NodeId.isValid(nodeId)) {
      throw FormatException('Invalid node id in QR payload: "$nodeId"');
    }
    if (!Fingerprint.isValidHex(fingerprintHex)) {
      throw const FormatException('Invalid fingerprint in QR payload');
    }
    return QrIdentityCard(
      nodeId: nodeId,
      displayName: displayName,
      fingerprintHex: fingerprintHex,
      ed25519PublicKey: ed25519PublicKey,
      x25519PublicKey: x25519PublicKey,
      timestamp: timestamp,
      signature: Uint8List.fromList(signature),
    );
  }

  static String _contentJson(QrTransferContent content) =>
      jsonEncode(<String, Object?>{
        'v': _version,
        'id': content.nodeId,
        'n': content.displayName,
        'fp': content.fingerprintHex,
        'seed': _toB64(content.ed25519Seed),
        'xseed': _toB64(content.x25519Seed),
      });

  static QrTransferContent _transferFromFields(Map<String, Object?> fields) {
    final nodeId = _requireString(fields, 'id');
    final fingerprintHex = _requireString(fields, 'fp').toLowerCase();
    if (!NodeId.isValid(nodeId)) {
      throw FormatException('Invalid node id in transfer payload: "$nodeId"');
    }
    if (!Fingerprint.isValidHex(fingerprintHex)) {
      throw const FormatException('Invalid fingerprint in transfer payload');
    }
    return QrTransferContent(
      nodeId: nodeId,
      displayName: _requireString(fields, 'n'),
      fingerprintHex: fingerprintHex,
      ed25519Seed: _fromB64(_requireString(fields, 'seed')),
      x25519Seed: _fromB64(_requireString(fields, 'xseed')),
    );
  }

  // ----------------------------------------------------------------------
  // Serialization helpers
  // ----------------------------------------------------------------------

  /// Serializes [fields] to canonical JSON in [cardOrder], optionally
  /// appending a signature under the `s` key.
  static String _serialize(
    Map<String, Object?> fields, {
    bool includeSignature = false,
    Uint8List? signature,
  }) {
    final ordered = <String, Object?>{};
    for (final key in cardOrder) {
      if (key == 's' && !includeSignature) {
        continue;
      }
      final value = fields[key];
      if (value != null) {
        ordered[key] = value;
      }
    }
    if (includeSignature) {
      ordered['s'] = _toB64(signature!);
    }
    return jsonEncode(ordered);
  }

  static Map<String, Object?> _unwrap(
    String text, {
    required String expectedType,
  }) {
    final trimmed = text.trim();
    if (!trimmed.startsWith(prefix)) {
      throw FormatException('QR payload must start with "$prefix"', text);
    }
    final jsonText = utf8.decode(_fromB64(trimmed.substring(prefix.length)));
    final parsed = jsonDecode(jsonText);
    if (parsed is! Map) {
      throw const FormatException('QR payload must be a JSON object');
    }
    final fields = parsed.cast<String, Object?>();
    if (fields['v'] != _version) {
      throw const FormatException('Unsupported QR payload version');
    }
    if (fields['t'] != expectedType) {
      throw FormatException(
        'Expected payload type "$expectedType", got ${fields['t']}',
      );
    }
    return fields;
  }

  static String _wrap(String documentJson) =>
      '$prefix${_toB64(utf8.encode(documentJson))}';

  static String _requireString(Map<String, Object?> fields, String key) {
    final value = fields[key];
    if (value is! String || value.isEmpty) {
      throw FormatException('QR payload missing field "$key"');
    }
    return value;
  }

  static void _requireLength(List<int> bytes, int expected, String name) {
    if (bytes.length != expected) {
      throw ArgumentError(
        '$name must be $expected bytes (got ${bytes.length})',
      );
    }
  }

  static Uint8List _concatList(List<List<int>> parts) {
    final total = parts.fold<int>(0, (sum, part) => sum + part.length);
    final out = Uint8List(total);
    var offset = 0;
    for (final part in parts) {
      out.setAll(offset, part);
      offset += part.length;
    }
    return out;
  }

  static String _toB64(List<int> bytes) =>
      base64Url.encode(bytes).replaceAll('=', '');

  static Uint8List _fromB64(String encoded) {
    final padding = (4 - encoded.length % 4) % 4;
    final padded = encoded.padRight(encoded.length + padding, '=');
    return Uint8List.fromList(base64Url.decode(padded));
  }
}
