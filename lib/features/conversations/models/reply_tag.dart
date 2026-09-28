import 'dart:convert';

/// A reply travels the way an attachment already does: a marker at the
/// front of `content`, understood by whoever renders the message.
///
/// Nothing in the frame, the envelope or the database changes, and a
/// peer that has never heard of the marker shows the whole thing as
/// text rather than dropping it.
///
/// The quote is base64 because it sits between the marker and the `]`
/// that ends it, and a quoted message can itself contain a `]`.
class ReplyTag {
  ReplyTag._();

  /// Marker that opens a reply.
  static const String prefix = '[reply:';

  /// Longest quote carried into a reply, before encoding.
  ///
  /// The content field is bounded, and the point of a quote is to say
  /// *which* message is being answered, not to reproduce it.
  static const int maxQuoteLength = 200;

  /// Build the content that goes on the wire: [text] answering [quoted].
  static String encode({required String quoted, required String text}) {
    var quote = quoted;
    if (quote.length > maxQuoteLength) {
      quote = '${quote.substring(0, maxQuoteLength)}…';
    }
    return '$prefix${base64Encode(utf8.encode(quote))}]$text';
  }

  /// The quoted text and the reply body, or `null` when [content] is a
  /// plain message or a marker this build cannot read.
  static ({String quote, String text})? parse(String content) {
    if (!content.startsWith(prefix)) return null;
    final end = content.indexOf(']');
    if (end < 0) return null;
    try {
      final quote = utf8.decode(
        base64Decode(content.substring(prefix.length, end)),
      );
      return (quote: quote, text: content.substring(end + 1));
    } on FormatException {
      return null;
    }
  }

  /// What a reply to [content] should quote: the words the message
  /// itself says, an attachment given a plain label, and the content
  /// unchanged when there is nothing to relabel.
  ///
  /// A message that is itself a reply quotes its own body — the quote
  /// answers for the message in front of you, not for the one two
  /// steps back.
  static String quoteFor(String content) {
    final reply = parse(content);
    if (reply != null) return reply.text;

    if (content.startsWith('[') && content.endsWith(']')) {
      final inner = content.substring(1, content.length - 1);
      final colon = inner.indexOf(':');
      if (colon > 0) {
        return '${inner.substring(0, colon)}: ${inner.substring(colon + 1)}';
      }
    }
    return content;
  }
}
