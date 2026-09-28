import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/features/conversations/models/reply_tag.dart';

/// A reply travels as a marker in `content`, the way an attachment
/// already does. These pin the shape down: what goes out comes back,
/// a message that is not a reply reads as itself, and a marker this
/// build cannot read is treated as plain text rather than dropped.
void main() {
  group('ReplyTag round trip', () {
    test('a reply comes back with its quote and its body apart', () {
      final content = ReplyTag.encode(quoted: 'where are you', text: 'home');

      expect(content, startsWith('[reply:'));
      final parsed = ReplyTag.parse(content);
      expect(parsed!.quote, 'where are you');
      expect(parsed.text, 'home');
    });

    test('a quote containing the marker that ends it survives', () {
      final content = ReplyTag.encode(quoted: 'a]b', text: 'yes');

      final parsed = ReplyTag.parse(content);
      expect(parsed!.quote, 'a]b');
      expect(parsed.text, 'yes');
    });

    test('a quote with characters outside ASCII survives', () {
      final content = ReplyTag.encode(quoted: 'héllo — 世界', text: 'ok');

      expect(ReplyTag.parse(content)!.quote, 'héllo — 世界');
    });

    test('a quote longer than the cap is cut, not refused', () {
      final content = ReplyTag.encode(quoted: 'x' * 500, text: 'y');

      final quote = ReplyTag.parse(content)!.quote;
      expect(quote.length, ReplyTag.maxQuoteLength + 1);
      expect(quote.endsWith('…'), isTrue);
    });
  });

  group('ReplyTag reading a message', () {
    test('an ordinary message is not a reply', () {
      expect(ReplyTag.parse('hello there'), isNull);
      expect(ReplyTag.parse('[image:photo.png]'), isNull);
      expect(ReplyTag.parse('[reply:borked'), isNull);
      expect(ReplyTag.parse('[reply:!!!]text'), isNull);
    });

    test('an unreadable marker still shows its text rather than nothing',
        () {
      // Not valid base64, so the quote cannot be recovered — but the
      // reply's own words are still there and must not be lost.
      expect(ReplyTag.parse('[reply:!!!]text'), isNull);
      expect(ReplyTag.quoteFor('[reply:!!!]text'), '[reply:!!!]text');
    });

    test('quoteFor reads the message itself, not two steps back', () {
      // The middle message is a reply of its own.
      final middle = ReplyTag.encode(quoted: 'first', text: 'second');

      // Replying to it quotes what it says, not what it was answering.
      expect(ReplyTag.quoteFor(middle), 'second');

      // So the quote carried inside the next reply is plain words —
      // which is what the bubble renders.
      final outer = ReplyTag.encode(
        quoted: ReplyTag.quoteFor(middle),
        text: 'third',
      );
      expect(ReplyTag.parse(outer)!.quote, 'second');
      expect(ReplyTag.parse(outer)!.text, 'third');
    });

    test('quoteFor labels an attachment a peer can read', () {
      expect(ReplyTag.quoteFor('[image:photo.png]'), 'image: photo.png');
      expect(ReplyTag.quoteFor('[file:notes.pdf]'), 'file: notes.pdf');
    });

    test('quoteFor leaves an ordinary message alone', () {
      expect(ReplyTag.quoteFor('where are you'), 'where are you');
    });
  });
}
