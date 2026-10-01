import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:onebit/features/identity/identity_repository.dart';
import 'package:onebit/features/protocol/message_codec.dart';

/// A signed X25519 public key, carried as an ordinary message frame.
///
/// Content on the wire: `[key:<x25519hex>:<sighex>]`, where the
/// signature is the sender's Ed25519 signature over the 32 X25519 key
/// bytes. The frame ends with [marker], the same trailing byte receipts
/// use: a peer built before announcements exist runs its strict decode,
/// finds one byte too many, and drops the packet instead of printing
/// a key into somebody's conversation.
///
/// ## Why signed
///
/// The key itself is public — secrecy is not the point. Binding is:
/// without the signature anyone on the channel could substitute their
/// own key, have messages encrypted to them, and read everything. The
/// signature ties the X25519 key to the Ed25519 identity the envelope
/// already names, so a forged announcement fails verification against
/// the sender's identity key and is dropped. First contact is still
/// trust-on-first-use (the Ed identity itself is unverified until the
/// user verifies it), but from then on the encryption key cannot be
/// swapped without tripping the identity the user verified.
class KeyAnnouncement {
  KeyAnnouncement._();

  /// Marker that opens an announcement.
  static const String prefix = '[key:';

  /// Trailing byte that makes an older peer drop the frame outright.
  /// Shared with receipts; the two are told apart by content, never by
  /// this byte.
  static const int marker = 0x1E;

  /// The frame id an announcement carries. It is never stored, so it
  /// has no row to deduplicate against.
  static const String frameId = 'key';

  /// Build the content that publishes [x25519Hex] under [signature].
  static String encode({
    required String x25519Hex,
    required Uint8List signature,
  }) {
    final sigHex = IdentityRepository.bytesToHex(signature);
    return '$prefix$x25519Hex:$sigHex]';
  }

  /// The announced key and signature in [content], or null when it is
  /// not an announcement. Structural only — call [verify] before
  /// trusting the key.
  static ({String keyHex, Uint8List signature})? parse(String content) {
    if (!content.startsWith(prefix) || !content.endsWith(']')) return null;

    final inner = content.substring(prefix.length, content.length - 1);
    final colon = inner.indexOf(':');
    if (colon <= 0) return null;

    final keyHex = inner.substring(0, colon);
    final sigHex = inner.substring(colon + 1);
    if (keyHex.length != 64 || sigHex.length != 128) return null;

    final hexPattern = RegExp(r'^[0-9a-fA-F]+$');
    if (!hexPattern.hasMatch(keyHex) || !hexPattern.hasMatch(sigHex)) {
      return null;
    }
    if (keyHex.replaceAll('0', '').isEmpty) return null;

    return (
      keyHex: keyHex,
      signature: IdentityRepository.hexToBytes(sigHex),
    );
  }

  /// Whether [content] announces a key genuinely signed by the holder
  /// of [senderEdPublicKey].
  ///
  /// False covers every failure — malformed content, a signature made
  /// by anyone else, a verification that throws — because the caller
  /// only ever needs to know "store it or drop it".
  static Future<bool> verify({
    required String content,
    required Uint8List senderEdPublicKey,
  }) async {
    final parsed = parse(content);
    if (parsed == null) return false;
    try {
      return await Ed25519().verify(
        IdentityRepository.hexToBytes(parsed.keyHex),
        signature: Signature(
          parsed.signature,
          publicKey: SimplePublicKey(
            senderEdPublicKey,
            type: KeyPairType.ed25519,
          ),
        ),
      );
    } catch (_) {
      return false;
    }
  }

  /// Decode an announcement frame, or null when [bytes] is anything
  /// else and should be handed down the pipeline untouched.
  static ({String keyHex, Uint8List signature})? decodeFrame(
    Uint8List bytes,
  ) {
    if (bytes.isEmpty || bytes[bytes.length - 1] != marker) return null;
    try {
      final frame = MessageCodec.decode(bytes.sublist(0, bytes.length - 1));
      return parse(frame.content);
    } catch (_) {
      // A plain message whose timestamp happened to end in the marker.
      return null;
    }
  }

  /// Build a complete announcement frame for [x25519Hex].
  static Uint8List encodeFrame({
    required String x25519Hex,
    required Uint8List signature,
    required int timestampMs,
  }) {
    final frame = MessageCodec.encode(
      externalMessageId: frameId,
      content: encode(x25519Hex: x25519Hex, signature: signature),
      timestampMs: timestampMs,
    );

    final out = Uint8List(frame.length + 1);
    out.setAll(0, frame);
    out[frame.length] = marker;
    return out;
  }
}
