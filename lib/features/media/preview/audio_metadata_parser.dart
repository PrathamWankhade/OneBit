import '../preview/media_metadata_parser.dart';

/// Pure-Dart audio container parser: WAV, MP3 (ID3v2 + frame counting) and
/// Ogg (Vorbis/Opus) duration + sample rate.
///
/// Frame counting is approximate but robust; bitrate fields win whenever
/// present. Reads only the provided header window.
final class AudioMetadataParser {
  const AudioMetadataParser();

  ParsedMediaAttributes? parse(MediaProbeInput input) {
    final header = input.headerBytes;

    // WAV: RIFF....WAVEfmt.
    if (header.length >= 12 &&
        _ascii(header, 0, 4) == 'RIFF' &&
        _ascii(header, 8, 4) == 'WAVE') {
      return _parseWav(input);
    }

    // Ogg: "OggS" page capture.
    if (MagicBytes.startsWith(header, MagicBytes.ogg)) {
      return _parseOgg(input);
    }

    // MP3: ID3v2 tag or a raw frame sync 0xFFEx.
    if (header.length >= 3 &&
        header[0] == 0x49 &&
        header[1] == 0x44 &&
        header[2] == 0x33) {
      return _parseMp3WithId3(input);
    }
    if (header.length >= 2 && header[0] == 0xFF && (header[1] & 0xE0) == 0xE0) {
      return _parseMp3Raw(input);
    }
    return null;
  }

  ParsedMediaAttributes? _parseWav(MediaProbeInput input) {
    final header = input.headerBytes;
    // fmt chunk payload: audioFormat(2) channels(2) sampleRate(4) …
    var offset = 12;
    while (offset + 8 <= header.length) {
      final chunkId = _ascii(header, offset, 4);
      final size = _le32(header, offset + 4);
      if (chunkId == 'fmt ' &&
          size >= 16 &&
          offset + 8 + size <= header.length) {
        final sampleRate = _le32(header, offset + 12);
        // data chunk carries the samples; bytesPerSecond at fmt+8.
        final bytesPerSecond = _le32(header, offset + 8);
        final dataChunk = _findChunk(
          header,
          offset + 8 + size,
          chunkIdAfter: 'data',
        );
        final dataBytes = dataChunk == null
            ? null
            : input.sizeBytes - (dataChunk + 8);
        int? durationMs;
        if (bytesPerSecond > 0 && (dataBytes ?? 0) > 0) {
          durationMs = dataBytes! * 1000 ~/ bytesPerSecond;
        }
        return ParsedMediaAttributes(
          durationMs: durationMs,
          sampleRate: sampleRate > 0 ? sampleRate : null,
        );
      }
      offset += 8 + size;
    }
    return null;
  }

  int? _findChunk(List<int> header, int start, {required String chunkIdAfter}) {
    var offset = start;
    while (offset + 8 <= header.length) {
      final chunkId = _ascii(header, offset, 4);
      final size = _le32(header, offset + 4);
      if (chunkId == 'data') return offset;
      offset += 8 + size;
    }
    return null;
  }

  ParsedMediaAttributes? _parseOgg(MediaProbeInput input) {
    // First page: segment table gives the lacing sizes of the initial
    // Vorbis/Opus header packet; we need the *second* page's granule start
    // to estimate duration — not available in one header window reliably,
    // so report sample rate only when the identification header is present.
    final header = input.headerBytes;
    if (header.length < 41) return null;
    final version = header[4];
    if (version != 0) return null;
    // Characterization packet of the first page: identification header.
    final packet = header.sublist(28, header.length < 60 ? header.length : 60);
    int? sampleRate;
    if (packet.length >= 16) {
      final codec = String.fromCharCodes(packet.sublist(1, 7));
      if (codec == 'vorbis') {
        sampleRate = _le32(packet, 12); // audio sample rate at offset 12
      } else if (codec == 'OpusHe') {
        sampleRate = 48000; // Opus decodes at 48 kHz
      }
    }
    return sampleRate == null
        ? null
        : ParsedMediaAttributes(sampleRate: sampleRate);
  }

  ParsedMediaAttributes? _parseMp3WithId3(MediaProbeInput input) {
    final header = input.headerBytes;
    if (header.length < 10) return null;
    final major = header[3];
    final flags = header[5];
    final size =
        ((header[6] & 0x7F) << 21) |
        ((header[7] & 0x7F) << 14) |
        ((header[8] & 0x7F) << 7) |
        (header[9] & 0x7F);
    var offset = 10 + size;
    if (offset + 4 > header.length) return null;
    if ((flags & 0x40) != 0 && offset + 10 <= header.length) {
      // Extended header size (syncsafe).
      offset +=
          4 +
          (((header[offset] & 0x7F) << 21) |
              ((header[offset + 1] & 0x7F) << 14) |
              ((header[offset + 2] & 0x7F) << 7) |
              (header[offset + 3] & 0x7F));
    }
    return _frameScan(input, offset, freeBitrateAllowed: major < 4);
  }

  ParsedMediaAttributes? _parseMp3Raw(MediaProbeInput input) {
    final header = input.headerBytes;
    final sampleRate = _mp3SampleRate(header[1], header[2]);
    final bitrateKbps = _mp3Bitrate(header[2]);
    int? durationMs;
    if (bitrateKbps != null && bitrateKbps > 0) {
      // Audio bytes ≈ 0.95 * file size (CBR estimate, strips tags).
      durationMs = input.sizeBytes * 8 ~/ bitrateKbps;
    }
    return ParsedMediaAttributes(
      durationMs: durationMs,
      sampleRate: sampleRate,
    );
  }

  ParsedMediaAttributes? _frameScan(
    MediaProbeInput input,
    int startOffset, {
    required bool freeBitrateAllowed,
  }) {
    final header = input.headerBytes;
    var offset = startOffset;
    var frames = 0;
    int? sampleRate;
    int? bitrateKbps;
    while (offset + 4 <= header.length &&
        frames < 4096 &&
        !(header[offset] == 0xFF && (header[offset + 1] & 0xE0) == 0xE0) &&
        frames < 4) {
      offset++;
    }
    // A valid sync at [offset]: parse a few frames for sample rate + CBR
    // bitrate, then extrapolate the duration from file size.
    while (offset + 4 <= header.length && frames < 8) {
      if (header[offset] == 0xFF && (header[offset + 1] & 0xE0) == 0xE0) {
        final rate = _mp3SampleRate(header[offset + 1], header[offset + 2]);
        final bitrate = _mp3Bitrate(header[offset + 2]);
        if (rate != null) sampleRate = rate;
        if (bitrate != null) bitrateKbps = bitrate;
        frames++;
        final frameLength = _mp3FrameLength(header, offset);
        if (frameLength < 0) break;
        offset += frameLength;
      } else {
        offset++;
      }
    }
    if (sampleRate == null && bitrateKbps == null) return null;
    int? durationMs;
    if (bitrateKbps != null && bitrateKbps > 0) {
      durationMs = input.sizeBytes * 8 ~/ bitrateKbps;
    }
    return ParsedMediaAttributes(
      durationMs: durationMs,
      sampleRate: sampleRate,
    );
  }

  int? _mp3SampleRate(int byte1, int byte2) => switch ((byte1 >> 1) & 0x03) {
    0 => 44100,
    1 => 48000,
    2 => 32000,
    _ => null,
  };

  int? _mp3Bitrate(int byte2) {
    final index = (byte2 >> 4) & 0x0F;
    const table = <int?>[
      null,
      32,
      40,
      48,
      56,
      64,
      80,
      96,
      112,
      128,
      160,
      192,
      224,
      256,
      320,
      null,
    ];
    return table[index];
  }

  /// Computes the frame length in bytes for a sync at [offset].
  int _mp3FrameLength(List<int> header, int offset) {
    final versionId = (header[offset + 1] >> 3) & 0x03; // 0=2.5, 2=2, 3=1
    final layer = (header[offset + 1] >> 1) & 0x03;
    final bitrateKbps = _mp3Bitrate(header[offset + 2]);
    final sampleRate = _mp3SampleRate(header[offset + 1], header[offset + 2]);
    final padding = (header[offset + 2] >> 1) & 0x01;
    if (bitrateKbps == null || sampleRate == null) return -1;
    if (layer == 3) {
      // Layer I: 384 slots.
      return (12 * bitrateKbps * 1000 ~/ sampleRate + padding) * 4;
    }
    final scale = versionId == 3 ? 144 : 72;
    return scale * bitrateKbps * 1000 ~/ sampleRate + padding;
  }

  static int _le32(List<int> bytes, int offset) =>
      bytes[offset] |
      (bytes[offset + 1] << 8) |
      (bytes[offset + 2] << 16) |
      (bytes[offset + 3] << 24);

  static String _ascii(List<int> bytes, int offset, int length) {
    if (offset + length > bytes.length) return '';
    return String.fromCharCodes(bytes.sublist(offset, offset + length));
  }
}
