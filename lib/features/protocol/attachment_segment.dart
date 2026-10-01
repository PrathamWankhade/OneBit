import 'dart:convert';
import 'dart:typed_data';

/// One slice of a file traveling as an ordinary chat message.
///
/// Content on the wire:
/// ```
/// [seg:<id>:<index>/<count>:<name>:<base64>]
/// ```
/// where `id` is 16 hex chars naming the attachment, `index`/`count`
/// locate the slice, `name` is the sanitized file name (carried on
/// every slice so a slice arriving before the manifest still knows
/// where it belongs), and the payload is base64 file bytes.
///
/// Segments are messages in every mechanical sense — queued rows,
/// encrypted frames when the peer's key is held, per-row wire ids for
/// dedup — but never user-visible ones: the thread filters them out,
/// the list preview skips them, and they land read so no badge counts
/// machinery as mail. The visible row is the manifest; when its slices
/// are all present the file is written and the manifest starts
/// rendering from disk.
class SegTag {
  SegTag._();

  /// Marker that opens a segment.
  static const String prefix = '[seg:';

  /// Raw file bytes per slice. Base64 inflates this to ~3868 chars,
  /// which plus the header stays inside the 4000-byte content cap.
  static const int sliceBytes = 2900;

  /// Sanity cap: a single attachment past this many slices is refused
  /// rather than turned into thousands of rows and radio time.
  static const int maxSlices = 1000;

  /// Split [bytes] into slice payloads for [segId] and [fileName].
  static List<String> encodeSlices({
    required String segId,
    required String fileName,
    required Uint8List bytes,
  }) {
    if (segId.length != 16) {
      throw ArgumentError('Segment id must be 16 hex chars');
    }
    final slices = <String>[];
    final count = (bytes.length + sliceBytes - 1) ~/ sliceBytes;
    if (count > maxSlices) {
      throw ArgumentError('Attachment needs $count slices (max $maxSlices)');
    }
    for (var index = 0; index < count; index++) {
      final start = index * sliceBytes;
      var end = start + sliceBytes;
      if (end > bytes.length) end = bytes.length;
      final chunk = base64Encode(bytes.sublist(start, end));
      slices.add('$prefix$segId:$index/$count:$fileName:$chunk]');
    }
    return slices;
  }

  /// The slice in [content], or null when it is not one — including
  /// when the header lies about its own shape.
  static ({String id, int index, int count, String name, Uint8List bytes})?
      parse(String content) {
    if (!content.startsWith(prefix) || !content.endsWith(']')) return null;

    final inner = content.substring(prefix.length, content.length - 1);
    // Three colons separate four fields; the base64 tail contains no
    // colon, so the split is exact rather than best-effort.
    final parts = inner.split(':');
    if (parts.length != 4) return null;

    final id = parts[0];
    if (id.length != 16 || !RegExp(r'^[0-9a-fA-F]+$').hasMatch(id)) {
      return null;
    }

    final fraction = parts[1].split('/');
    if (fraction.length != 2) return null;
    final index = int.tryParse(fraction[0]);
    final count = int.tryParse(fraction[1]);
    if (index == null || count == null) return null;
    if (count < 1 || count > maxSlices || index < 0 || index >= count) {
      return null;
    }

    final name = parts[2];
    if (name.isEmpty ||
        name.contains('[') ||
        name.contains(']') ||
        name.contains('/')) {
      return null;
    }

    late Uint8List bytes;
    try {
      bytes = base64Decode(parts[3]);
    } catch (_) {
      return null;
    }
    if (bytes.isEmpty || bytes.length > sliceBytes) return null;

    return (id: id, index: index, count: count, name: name, bytes: bytes);
  }
}

/// The visible row of an attachment: what it is, what it is called,
/// and which slices complete it.
///
/// Wire shapes (all rendered by the existing media widgets):
/// ```
/// [image:<name>:<id>:<count>]           (new: segmented transfer)
/// [voice:<name>:<id>:<count>]           (new: segmented transfer)
/// [file:<name>:<id>:<count>]            (new: segmented transfer)
/// [image:<name>]                        (legacy: local file, never sent)
/// ```
/// Anything else starting with `[` is somebody else's renderer.
class AttachmentManifest {
  AttachmentManifest._();

  /// Kinds that carry segmented transfers.
  static const Set<String> kinds = {'image', 'voice', 'file'};

  /// Build a manifest for a segmented transfer.
  static String encode({
    required String kind,
    required String fileName,
    required String segId,
    required int count,
    List<String> extra = const [],
  }) {
    if (!kinds.contains(kind)) throw ArgumentError('Unknown kind: $kind');
    final fields = [kind, fileName, segId, '$count', ...extra];
    return '[${fields.join(':')}]';
  }

  /// Remove what the filesystem cannot wear from [fileName].
  static String sanitize(String fileName) {
    final base = fileName.split('/').last.split('\\').last;
    final clean = base.replaceAll(RegExp(r'[\[\]:]'), '_');
    return clean.isEmpty ? 'file' : clean;
  }

  /// The manifest in [content], or null when it is not one.
  ///
  /// Legacy manifests (no transfer id) come back with a null [segId]:
  /// render them the old way — a local lookup, placeholder beyond it.
  static (
    {String kind,
    String name,
    String? segId,
    int? count,
    List<String> extra}
  )? parse(String content) {
    if (!content.startsWith('[') || !content.endsWith(']')) return null;
    final parts = content.substring(1, content.length - 1).split(':');
    if (parts.length < 2 || !kinds.contains(parts[0])) return null;

    final kind = parts[0];
    final name = parts[1];
    if (name.isEmpty) return null;

    if (parts.length == 2) {
      return (kind: kind, name: name, segId: null, count: null, extra: const []);
    }
    if (parts.length < 4) return null;

    final segId = parts[2];
    if (segId.length != 16 || !RegExp(r'^[0-9a-fA-F]+$').hasMatch(segId)) {
      return null;
    }
    final count = int.tryParse(parts[3]);
    if (count == null || count < 1 || count > SegTag.maxSlices) return null;

    return (
      kind: kind,
      name: name,
      segId: segId,
      count: count,
      extra: parts.sublist(4),
    );
  }
}
