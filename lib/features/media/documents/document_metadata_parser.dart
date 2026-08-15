import '../preview/media_metadata_parser.dart';

/// Pure-Dart document parser: PDF page count + plain-text encoding sniff.
///
/// PDF page counting counts `/Type /Page[ s]` objects referenced from the
/// root `Pages` tree via `Count` entries; both sit inside the header window
/// for small files. Reads only the provided bytes, never a file.
final class DocumentMetadataParser {
  const DocumentMetadataParser();

  ParsedMediaAttributes? parse(MediaProbeInput input) {
    final header = input.headerBytes;

    if (MagicBytes.startsWith(header, MagicBytes.pdf)) {
      return _parsePdf(header);
    }
    return null;
  }

  ParsedMediaAttributes _parsePdf(List<int> bytes) {
    final text = String.fromCharCodes(bytes);
    final encoding = _guessEncoding(bytes);

    // The /Count N convention inside the Pages tree.
    final counts = RegExp(r'/Count\s+(\d+)').allMatches(text);
    var pageCount = 0;
    for (final match in counts.take(32)) {
      final value = int.tryParse(match.group(1) ?? '');
      if (value != null && value > pageCount) pageCount = value;
    }
    if (pageCount > 0) {
      return ParsedMediaAttributes(pageCount: pageCount, encoding: encoding);
    }

    // Older PDFs rely on counting /Type /Page objects.
    final pages = RegExp(r'/Type\s*/Page[^s]').allMatches(text).length;
    if (pages > 0) {
      return ParsedMediaAttributes(pageCount: pages, encoding: encoding);
    }
    return ParsedMediaAttributes(encoding: encoding);
  }

  static String _guessEncoding(List<int> bytes) {
    // UTF-16 BOM detected — else UTF-8 if valid, else windows-1252.
    if (bytes.length >= 2 &&
        ((bytes[0] == 0xFF && bytes[1] == 0xFE) ||
            (bytes[0] == 0xFE && bytes[1] == 0xFF))) {
      return 'utf-16';
    }
    try {
      String.fromCharCodes(bytes);
      // Sniff for multibyte sequences that prove UTF-8 beyond ASCII.
      for (var i = 0; i < bytes.length && i < 4096; i++) {
        final b = bytes[i];
        if (b >= 0xC0) {
          if (i + 1 < bytes.length && (bytes[i + 1] & 0xC0) == 0x80) {
            return 'utf-8';
          }
        }
      }
      return 'ascii';
    } on Object {
      return 'binary';
    }
  }
}
