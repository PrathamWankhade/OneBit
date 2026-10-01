import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:onebit/features/crypto/encrypted_payload.dart';
import 'package:onebit/features/crypto/key_derivation.dart';

/// Binary framing for an end-to-end encrypted message.
///
/// Wire format (big-endian):
/// ```
/// [magic: 1 byte 0xE1][version: 1 byte][senderKey: 32 bytes]
/// [OneBitEncryptedPayload.serialize() of the inner MessageCodec frame]
/// ```
///
/// The inner frame is an ordinary `MessageCodec` encoding, so once the
/// outer layer comes off the receive path below is unchanged: receipts,
/// announcements and chat text all decrypt first and decode after.
///
/// ## Why the sender key rides along
///
/// X25519 public keys are stable per identity (derived deterministically
/// from the Ed25519 seed), but nothing else carries them: the envelope
/// names the Ed25519 identity, QR happens once, and BLE advertisements
/// only fit a fingerprint. Attaching 32 bytes to every encrypted frame
/// means key learning needs no round trip and no state machine — the
/// first encrypted frame from a peer teaches us their key, and every
/// frame after that proves it again by decrypting.
///
/// ## Old peers
///
/// A peer built before encryption runs `MessageCodec.decode` on this
/// and throws — the first two bytes read as a 57601-byte id length, so
/// it fails long before touching content. An undecryptable frame is
/// dropped, never shown as a blob of base64.
///
/// ## Authentication
///
/// The header (magic, version, sender key) is the AES-GCM associated
/// data, so it cannot be swapped without breaking the tag. The sender
/// key itself is trusted only through the signed key announcement or
/// QR: anyone can claim any 32 bytes here, but without the session key
/// their frame never decrypts, and a frame that does decrypt arrived
/// under a key we already accepted.
class E2eeFrame {
  E2eeFrame._();

  /// First byte of every encrypted frame.
  static const int magic = 0xE1;

  /// Frame version. Bump when the layout changes; [decrypt] refuses
  /// anything else rather than guessing.
  static const int version = 1;

  /// Magic + version + sender X25519 public key.
  static const int headerLength = 34;

  /// HKDF context. Fixed, not directional, so both ends derive the same
  /// session key from the same shared secret.
  static final Uint8List sessionContext =
      Uint8List.fromList('onebit.e2ee.v1'.codeUnits);

  /// Encrypt an already-encoded message frame for the holder of
  /// [peerPublicKey].
  static Future<Uint8List> encrypt({
    required SimpleKeyPair localKeyPair,
    required Uint8List peerPublicKey,
    required Uint8List frame,
  }) async {
    final sessionKey = await _sessionKey(localKeyPair, peerPublicKey);
    final header = _header(await _publicBytes(localKeyPair));
    final payload = await OneBitEncryptedPayload.encrypt(
      key: sessionKey,
      plaintext: frame,
      associatedData: header,
    );
    final serialized = payload.serialize();

    final out = Uint8List(header.length + serialized.length);
    out.setAll(0, header);
    out.setAll(header.length, serialized);
    return out;
  }

  /// Decrypt [payload], or null when it is not an encrypted frame —
  /// including when it is one but this key cannot open it.
  ///
  /// Null always means "hand it to the next stage untouched": a
  /// plaintext frame fails the magic check, and a damaged or foreign
  /// frame fails the tag. Either way the plaintext path below decides
  /// what it is, and drops what it cannot decode.
  static Future<({Uint8List senderKey, Uint8List frame})?> decrypt({
    required SimpleKeyPair localKeyPair,
    required Uint8List payload,
  }) async {
    if (payload.length < headerLength + 1) return null;
    if (payload[0] != magic || payload[1] != version) return null;

    final header = payload.sublist(0, headerLength);
    final senderKey = Uint8List.fromList(payload.sublist(2, headerLength));

    final OneBitEncryptedPayload inner;
    try {
      inner = OneBitEncryptedPayload.deserialize(
        payload.sublist(headerLength),
      );
    } catch (_) {
      return null;
    }

    final SecretKey sessionKey;
    try {
      sessionKey = await _sessionKey(localKeyPair, senderKey);
    } catch (_) {
      return null;
    }

    try {
      final frame = await OneBitEncryptedPayload.decrypt(
        key: sessionKey,
        payload: inner,
        associatedData: header,
      );
      return (senderKey: senderKey, frame: Uint8List.fromList(frame));
    } catch (_) {
      return null;
    }
  }

  /// The X25519 session key both ends derive independently.
  static Future<SecretKey> _sessionKey(
    SimpleKeyPair localKeyPair,
    Uint8List peerPublicKey,
  ) async {
    final secretBytes = await _sharedSecretBytes(localKeyPair, peerPublicKey);
    return KeyDerivation.deriveSessionKey(
      sharedSecret: SecretKey(secretBytes),
      context: sessionContext,
    );
  }

  /// Raw ECDH output. Kept separate so the only thing HKDF ever sees is
  /// named for what it is.
  static Future<List<int>> _sharedSecretBytes(
    SimpleKeyPair localKeyPair,
    Uint8List peerPublicKey,
  ) async {
    final secret = await X25519().sharedSecretKey(
      keyPair: localKeyPair,
      remotePublicKey: SimplePublicKey(
        peerPublicKey,
        type: KeyPairType.x25519,
      ),
    );
    return secret.extractBytes();
  }

  static Uint8List _header(Uint8List senderPublicKey) {
    final header = Uint8List(headerLength);
    header[0] = magic;
    header[1] = version;
    header.setAll(2, senderPublicKey);
    return header;
  }

  static Future<Uint8List> _publicBytes(SimpleKeyPair keyPair) async {
    final public = await keyPair.extractPublicKey();
    return Uint8List.fromList(public.bytes);
  }
}
