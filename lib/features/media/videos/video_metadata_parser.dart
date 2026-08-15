import '../preview/media_metadata_parser.dart';

/// Pure-Dart video container parser: MP4/MOV (ISO BMFF) and Matroska (MKV)
/// duration + frame dimensions, scanned from the header window only.
///
/// Box/element walks are depth- and step-bounded so hostile headers cannot
/// cause unbounded work. Returns null when the header does not carry the
/// information — the dispatcher falls back to a metadata-less result.
final class VideoMetadataParser {
  const VideoMetadataParser();

  /// Maximum boxes / EBML elements visited in one scan.
  static const int _maxVisits = 1024;

  ParsedMediaAttributes? parse(MediaProbeInput input) {
    final header = input.headerBytes;

    // ISO BMFF: `ftyp` box identifies mp4/mov/m4v/video/iso2 ….
    if (header.length >= 12 && _ascii(header, 4, 4) == 'ftyp') {
      return _scanIsoBmff(header);
    }

    // Matroska: EBML header magic 0x1A45DFA3.
    if (header.length >= 4 &&
        header[0] == 0x1A &&
        header[1] == 0x45 &&
        header[2] == 0xDF &&
        header[3] == 0xA3) {
      return _scanMatroska(header);
    }
    return null;
  }

  // ---------------------------------------------------------------------
  // ISO BMFF (MP4 / MOV)
  // ---------------------------------------------------------------------

  ParsedMediaAttributes? _scanIsoBmff(List<int> bytes) {
    int? durationMs;
    int? width;
    int? height;
    var visits = 0;

    var offset = 0;
    while (offset + 8 <= bytes.length && visits++ < _maxVisits) {
      final size = _be32(bytes, offset);
      final type = _ascii(bytes, offset + 4, 4);
      if (type.isEmpty || size < 8) break;

      if (type == 'moov' && offset + size <= bytes.length) {
        final moov = _scanMoov(bytes, offset, size);
        durationMs ??= moov.$1;
        width ??= moov.$2;
        height ??= moov.$3;
        if (durationMs != null && width != null && height != null) {
          break;
        }
      }
      // `mdat` and friends carry no metadata — skip by declared size.
      offset += size;
    }

    if (durationMs == null && width == null && height == null) return null;
    return ParsedMediaAttributes(
      width: width,
      height: height,
      durationMs: durationMs,
    );
  }

  (int?, int?, int?) _scanMoov(List<int> bytes, int start, int boxSize) {
    int? durationMs;
    int? width;
    int? height;
    var visits = 0;
    var offset = start + 8;
    final end = start + boxSize;
    while (offset + 8 <= bytes.length &&
        offset + 8 <= end &&
        visits++ < _maxVisits) {
      final size = _be32(bytes, offset);
      final type = _ascii(bytes, offset + 4, 4);
      if (type.isEmpty || size < 8 || offset + size > bytes.length) break;

      switch (type) {
        case 'mvhd':
          durationMs ??= _boxDurationMs(bytes, offset, size);
        case 'trak':
          final trak = _scanTrak(bytes, offset, size);
          durationMs ??= trak.$1;
          width ??= trak.$2;
          height ??= trak.$3;
      }
      offset += size;
      if (durationMs != null && width != null && height != null) break;
    }
    return (durationMs, width, height);
  }

  (int?, int?, int?) _scanTrak(List<int> bytes, int start, int boxSize) {
    int? durationMs;
    int? width;
    int? height;
    var visits = 0;
    var offset = start + 8;
    final end = start + boxSize;
    while (offset + 8 <= bytes.length &&
        offset + 8 <= end &&
        visits++ < _maxVisits) {
      final size = _be32(bytes, offset);
      final type = _ascii(bytes, offset + 4, 4);
      if (type.isEmpty || size < 8 || offset + size > bytes.length) break;

      switch (type) {
        case 'mdia':
          durationMs ??= _mdiaDurationMs(bytes, offset, size);
        case 'tkhd':
          if (offset + size <= bytes.length) {
            final dims = _tkhdDimensions(bytes, offset, size);
            width ??= dims.$1;
            height ??= dims.$2;
          }
      }
      offset += size;
      if (durationMs != null && width != null && height != null) break;
    }
    return (durationMs, width, height);
  }

  int? _mdiaDurationMs(List<int> bytes, int start, int boxSize) {
    final end = start + boxSize;
    var offset = start + 8;
    while (offset + 8 <= bytes.length && offset + 8 <= end) {
      final size = _be32(bytes, offset);
      final type = _ascii(bytes, offset + 4, 4);
      if (type.isEmpty || size < 8 || offset + size > bytes.length) return null;
      if (type == 'mdhd') return _boxDurationMs(bytes, offset, size);
      offset += size;
    }
    return null;
  }

  /// `mvhd` / `mdhd` share the same timescale/duration layout.
  int? _boxDurationMs(List<int> bytes, int start, int boxSize) {
    final version = bytes[start + 8];
    if (version == 1) {
      if (boxSize < 40) return null;
      final timescale = _be32(bytes, start + 24);
      final duration = _be64(bytes, start + 28);
      if (timescale > 0) return duration ~/ timescale * 1000;
    } else {
      if (boxSize < 24) return null;
      final timescale = _be32(bytes, start + 16);
      final duration = _be32(bytes, start + 20);
      if (timescale > 0) return duration * 1000 ~/ timescale;
    }
    return null;
  }

  /// `tkhd` width/height are fixed-point 16.16 at the box tail.
  (int?, int?) _tkhdDimensions(List<int> bytes, int start, int boxSize) {
    final version = bytes[start + 8];
    final base = start + (version == 1 ? 88 : 76);
    if (base + 8 > start + boxSize || base + 8 > bytes.length) {
      return (null, null);
    }
    final width = _be32(bytes, base) >> 16;
    final height = _be32(bytes, base + 4) >> 16;
    return (width > 0 ? width : null, height > 0 ? height : null);
  }

  // ---------------------------------------------------------------------
  // Matroska (MKV)
  // ---------------------------------------------------------------------

  ParsedMediaAttributes? _scanMatroska(List<int> bytes) {
    final collector = _EbmlCollector();
    _walkEbml(bytes, 0, bytes.length, collector);
    if (collector.durationTicks == null &&
        collector.pixelWidth == null &&
        collector.pixelHeight == null) {
      return null;
    }
    final scale = collector.timecodeScale ?? 1000000; // 1 ns default
    if (scale <= 0) return null;
    final durationMs = collector.durationTicks == null
        ? null
        : (collector.durationTicks! * scale ~/ 1000000);
    return ParsedMediaAttributes(
      width: collector.pixelWidth,
      height: collector.pixelHeight,
      durationMs: durationMs,
    );
  }

  /// Bounded recursive EBML walk collecting the values we care about.
  void _walkEbml(
    List<int> bytes,
    int start,
    int end,
    _EbmlCollector collector,
  ) {
    var offset = start;
    while (offset + 4 < bytes.length &&
        offset < end &&
        collector.visits < _maxVisits) {
      collector.visits++;
      final idRead = _readEbmlId(bytes, offset);
      if (idRead.$2 < 0) break;
      final id = idRead.$1;
      final idEnd = idRead.$2;

      final sizeRead = _readEbmlSize(bytes, idEnd);
      if (sizeRead.$2 < 0 || sizeRead.$1 < 0) break;
      final size = sizeRead.$1;
      final dataStart = sizeRead.$2;
      final dataEnd = dataStart + size;
      if (dataEnd > bytes.length || dataEnd > end) break;

      switch (id) {
        case 0x4489: // Duration (in timecode units)
          collector.durationTicks = _ebmlUint(bytes, dataStart, size);
        case 0x2AD7B1: // TimecodeScale (default 1 000 000 ns)
          collector.timecodeScale =
              _ebmlUint(bytes, dataStart, size) ?? 1000000;
        case 0xB0: // PixelWidth
          collector.pixelWidth = _ebmlUint(bytes, dataStart, size)?.toInt();
        case 0xBA: // PixelHeight
          collector.pixelHeight = _ebmlUint(bytes, dataStart, size)?.toInt();
        case 0x1549A966: // Info
        case 0x1654AE6B: // Tracks
        case 0xAE: // TrackEntry
        case 0xE0: // Video
        case 0x1F43B675: // Cluster
          _walkEbml(bytes, dataStart, dataEnd, collector);
      }
      offset = dataEnd;
    }
  }

  /// Reads an unsigned big-endian integer payload.
  int? _ebmlUint(List<int> bytes, int start, int length) {
    if (length < 1 || length > 8 || start + length > bytes.length) return null;
    var value = 0;
    for (var i = 0; i < length; i++) {
      value = value << 8 | bytes[start + i];
    }
    return value;
  }

  /// Reads an EBML element id.
  ///
  /// The marker bit is part of the id (libebml convention): the id is the
  /// whole bit pattern whose leading zeros encode the length. Returns
  /// `(id, offsetAfterVint)` or `(0, -1)` when unreadable.
  (int, int) _readEbmlId(List<int> bytes, int offset) {
    if (offset >= bytes.length) return (0, -1);
    final first = bytes[offset];
    var length = 1;
    var marker = first;
    while ((marker & 0x80) == 0) {
      if (length >= 8 || offset + length >= bytes.length) return (0, -1);
      marker = bytes[offset + length];
      length++;
    }
    var value = marker;
    for (var i = 1; i < length; i++) {
      value = value << 8 | bytes[offset + i];
    }
    return (value, offset + length);
  }

  /// Reads an EBML data-size VINT (the marker bit is masked out).
  ///
  /// Returns `(size, offsetAfterVint)` or `(-1, -1)` when unreadable.
  (int, int) _readEbmlSize(List<int> bytes, int offset) {
    if (offset >= bytes.length) return (-1, -1);
    final first = bytes[offset];
    var length = 1;
    var marker = first;
    while ((marker & 0x80) == 0) {
      if (length >= 8 || offset + length >= bytes.length) return (-1, -1);
      marker = bytes[offset + length];
      length++;
    }
    var value = marker & (0x7F >> (length - 1));
    for (var i = 1; i < length; i++) {
      value = value << 8 | bytes[offset + i];
    }
    // The all-markers value encodes "unknown size" — refuse to walk it.
    if (value == (1 << (length * 7)) - 1) return (-1, -1);
    return (value, offset + length);
  }

  static int _be32(List<int> bytes, int offset) {
    if (offset + 4 > bytes.length) return 0;
    return (bytes[offset] << 24) |
        (bytes[offset + 1] << 16) |
        (bytes[offset + 2] << 8) |
        bytes[offset + 3];
  }

  static int _be64(List<int> bytes, int offset) {
    var value = 0;
    for (var i = 0; i < 8; i++) {
      if (offset + i >= bytes.length) break;
      value = value << 8 | bytes[offset + i];
    }
    return value;
  }

  static String _ascii(List<int> bytes, int offset, int length) {
    if (offset + length > bytes.length) return '';
    return String.fromCharCodes(bytes.sublist(offset, offset + length));
  }
}

/// Accumulates the values a Matroska scan is looking for.
final class _EbmlCollector {
  int visits = 0;
  int? durationTicks;
  int? timecodeScale;
  int? pixelWidth;
  int? pixelHeight;
}
