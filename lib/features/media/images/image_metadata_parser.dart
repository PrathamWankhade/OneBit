import '../preview/media_metadata_parser.dart';

/// Pure-Dart image header parser: PNG / JPEG / GIF / WEBP dimensions.
///
/// Reads only the bytes handed to it (never a file), so it is unit-testable
/// anywhere. Returns null when the header does not carry the information —
/// the dispatcher then falls back to a metadata-less result.
final class ImageMetadataParser {
  const ImageMetadataParser();

  /// PNG: signature + `IHDR` width/height at fixed offsets (big-endian).
  /// Supports bit depths 1–16 and all color types; interlaced images report
  /// their interlace dimensions too.
  ParsedMediaAttributes? parse(MediaProbeInput input) {
    final header = input.headerBytes;
    if (MagicBytes.startsWith(header, MagicBytes.png) && header.length >= 24) {
      final width = _readBe32(header, 16);
      final height = _readBe32(header, 20);
      if (width > 0 && height > 0) {
        return ParsedMediaAttributes(width: width, height: height);
      }
    }

    if (MagicBytes.startsWith(header, MagicBytes.jpeg)) {
      final dims = _parseJpeg(header);
      if (dims != null) {
        return ParsedMediaAttributes(width: dims.$1, height: dims.$2);
      }
    }

    if (MagicBytes.startsWith(header, MagicBytes.gif87) ||
        MagicBytes.startsWith(header, MagicBytes.gif89)) {
      if (header.length >= 10) {
        final width = _readLe16(header, 6);
        final height = _readLe16(header, 8);
        if (width > 0 && height > 0) {
          return ParsedMediaAttributes(width: width, height: height);
        }
      }
    }

    // RIFF....WEBP — dimensions depend on the VP8* four-CC.
    if (MagicBytes.startsWith(header, MagicBytes.webp) &&
        header.length >= 30 &&
        header[8] == 0x57 &&
        header[9] == 0x45 &&
        header[10] == 0x42 &&
        header[11] == 0x50) {
      final dims = _parseWebp(header);
      if (dims != null) {
        return ParsedMediaAttributes(width: dims.$1, height: dims.$2);
      }
    }
    return null;
  }

  /// Walks JPEG segments; the first SOF{0,1,2} carries height/width.
  (int, int)? _parseJpeg(List<int> header) {
    // SOI at 0-1; then segments: FF marker, length (BE), payload.
    var i = 2;
    while (i + 3 < header.length) {
      if (header[i] != 0xFF) {
        i++;
        continue;
      }
      final marker = header[i + 1];
      if (marker == 0xD8) {
        i += 2;
        continue;
      }
      if (marker == 0xD9 || marker == 0xDA) {
        return null; // EOI / SOS before any SOF — degenerate file
      }
      if (marker >= 0xC0 &&
          marker <= 0xCF &&
          marker != 0xC4 &&
          marker != 0xC8 &&
          marker != 0xCC) {
        if (i + 8 < header.length && header[i + 2] == 0 && header[i + 3] > 0) {
          final height = _readBe16(header, i + 4);
          final width = _readBe16(header, i + 6);
          if (width > 0 && height > 0) return (width, height);
        }
        return null;
      }
      final length = _readBe16(header, i + 2);
      if (length < 2) return null;
      i += 2 + length;
    }
    return null;
  }

  /// WEBP: extended (VP8X, 24-bit canvas) or lossy/lossless (14-bit dims).
  (int, int)? _parseWebp(List<int> header) {
    final fourCc = String.fromCharCodes(header.sublist(12, 16));
    switch (fourCc) {
      case 'VP8X': // extended: 24-bit canvas at offsets 24..29
        if (header.length >= 30) {
          final width = header[24] | (header[25] << 8) | (header[26] << 16);
          final height = header[27] | (header[28] << 8) | (header[29] << 16);
          // Canvas size is stored minus one.
          if (width >= 0 && height >= 0) return (width + 1, height + 1);
        }
        return null;
      case 'VP8 ': // lossy: dimensions at 26..29 (14-bit each)
        if (header.length >= 30) {
          final width = header[26] | ((header[27] & 0x3F) << 8);
          final height = header[28] | ((header[29] & 0x3F) << 8);
          if (width > 0 && height > 0) return (width, height);
        }
        return null;
      case 'VP8L': // lossless: 14-bit dims packed at 21..24 (LE)
        if (header.length >= 25) {
          final bits = _readLe32(header, 21);
          final width = (bits & 0x3FFF) + 1;
          final height = ((bits >> 14) & 0x3FFF) + 1;
          return (width, height);
        }
        return null;
    }
    return null;
  }

  static int _readBe32(List<int> bytes, int offset) =>
      (bytes[offset] << 24) |
      (bytes[offset + 1] << 16) |
      (bytes[offset + 2] << 8) |
      bytes[offset + 3];

  static int _readBe16(List<int> bytes, int offset) =>
      (bytes[offset] << 8) | bytes[offset + 1];

  static int _readLe16(List<int> bytes, int offset) =>
      bytes[offset] | (bytes[offset + 1] << 8);

  static int _readLe32(List<int> bytes, int offset) =>
      bytes[offset] |
      (bytes[offset + 1] << 8) |
      (bytes[offset + 2] << 16) |
      (bytes[offset + 3] << 24);
}
