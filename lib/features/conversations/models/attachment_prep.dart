import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Shrink a picked picture until it fits the transport.
///
/// The segmented transport caps one attachment at about a megabyte,
/// but a phone photo is several — and nobody waits twenty minutes on
/// BLE for full resolution. JPEG at chat sizes lands under the cap
/// with room to spare. Returns null when the bytes are not an image
/// at all, or stay too big at the floor quality: the caller refuses
/// honestly instead of sending a corrupt or endless transfer.
class AttachmentPrep {
  AttachmentPrep._();

  /// Largest encoded image we will send (120 KB ≈ 45 slices).
  static const int maxImageBytes = 120 * 1024;

  /// Downscale [bytes] to a JPEG that fits [maxBytes].
  static Uint8List? prepareImage(
    Uint8List bytes, {
    int maxBytes = maxImageBytes,
  }) {
    final img.Image? decoded;
    try {
      decoded = img.decodeImage(bytes);
    } catch (_) {
      return null;
    }
    if (decoded == null) return null;

    const sizes = [1024, 768, 512];
    const qualities = [70, 50, 30];
    for (final size in sizes) {
      final resized = _fitInside(decoded, size);
      for (final quality in qualities) {
        final out = Uint8List.fromList(
          img.encodeJpg(resized, quality: quality),
        );
        if (out.length <= maxBytes) return out;
      }
    }
    return null;
  }

  /// Scale so the longest side is [size], or return the image itself
  /// when it already fits.
  static img.Image _fitInside(img.Image source, int size) {
    final longest =
        source.width > source.height ? source.width : source.height;
    if (longest <= size) return source;
    final scale = size / longest;
    return img.copyResize(
      source,
      width: (source.width * scale).round(),
      height: (source.height * scale).round(),
    );
  }
}
