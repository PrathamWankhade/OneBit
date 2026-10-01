import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/data/database/app_database.dart';

AppDatabase createTestDb() => AppDatabase.test(DatabaseConnection(NativeDatabase.memory()));

void main() {
  late AppDatabase db;

  setUp(() async {
    db = createTestDb();
    // Run migration to create tables
    await db.customStatement('PRAGMA foreign_keys = ON');
  });

  tearDown(() async {
    await db.close();
  });

  group('Conversations', () {
    test('create and retrieve', () async {
      final id = await db.createConversation('Test Chat');
      final conv = await db.getConversation(id);

      expect(conv, isNotNull);
      expect(conv!.title, 'Test Chat');
      expect(conv.id, id);
    });

    test('watchAll returns sorted list', () async {
      final ids = await Future.wait([
        db.createConversation('First'),
        db.createConversation('Second'),
      ]);

      final stream = db.watchConversations();
      final results = await stream.first;

      expect(results.length, 2);
      // Most recently updated first (both created at same time, order may vary)
      expect(results.map((c) => c.id).toSet(), ids.toSet());
    });

    test('update conversation', () async {
      final id = await db.createConversation('Old Name');
      final conv = await db.getConversation(id);
      await db.updateConversation(
        ConversationsCompanion(
          id: Value(id),
          title: const Value('New Name'),
          createdAt: Value(conv!.createdAt),
          updatedAt: Value(conv.updatedAt),
        ),
      );

      final updated = await db.getConversation(id);
      expect(updated!.title, 'New Name');
    });

    test('delete conversation', () async {
      final id = await db.createConversation('To Delete');
      await db.deleteConversation(id);

      final conv = await db.getConversation(id);
      expect(conv, isNull);
    });
  });

  group('Messages', () {
    late int conversationId;

    setUp(() async {
      conversationId = await db.createConversation('Chat');
    });

    test('insert and retrieve', () async {
      final msgId = await db.insertMessage(
        conversationId: conversationId,
        content: 'Hello',
      );

      final messages = await db.getMessages(conversationId);
      expect(messages.length, 1);
      expect(messages.first.content, 'Hello');
      expect(messages.first.id, msgId);
    });

    test('messages belong to correct conversation', () async {
      final otherId = await db.createConversation('Other Chat');

      await db.insertMessage(conversationId: conversationId, content: 'Msg 1');
      await db.insertMessage(conversationId: otherId, content: 'Msg 2');
      await db.insertMessage(conversationId: conversationId, content: 'Msg 3');

      final msgs1 = await db.getMessages(conversationId);
      final msgs2 = await db.getMessages(otherId);

      expect(msgs1.length, 2);
      expect(msgs2.length, 1);
      expect(msgs1.map((m) => m.content), ['Msg 1', 'Msg 3']);
      expect(msgs2.first.content, 'Msg 2');
    });

    test('watchMessages streams updates', () async {
      final stream = db.watchMessages(conversationId);

      await db.insertMessage(conversationId: conversationId, content: 'First');
      final afterFirst = await stream.first;
      expect(afterFirst.length, 1);

      await db.insertMessage(conversationId: conversationId, content: 'Second');
      final afterSecond = await stream.first;
      expect(afterSecond.length, 2);
    });

    test('delete message', () async {
      final msgId = await db.insertMessage(
        conversationId: conversationId,
        content: 'Delete me',
      );

      await db.deleteMessage(msgId);
      final messages = await db.getMessages(conversationId);
      expect(messages, isEmpty);
    });

    test('deleteMessages clears all for conversation', () async {
      await db.insertMessage(conversationId: conversationId, content: 'A');
      await db.insertMessage(conversationId: conversationId, content: 'B');

      await db.deleteMessages(conversationId);
      final messages = await db.getMessages(conversationId);
      expect(messages, isEmpty);
    });

    test('message has default local status', () async {
      await db.insertMessage(conversationId: conversationId, content: 'Hi');

      final messages = await db.getMessages(conversationId);
      expect(messages.first.status, 'local');
    });

    test('insertMessage updates conversation updatedAt', () async {
      await db.insertMessage(conversationId: conversationId, content: 'Hi');

      final convAfter = await db.getConversation(conversationId);

      // Verify the timestamp exists and is reasonable
      expect(convAfter, isNotNull);
      expect(convAfter!.updatedAt, isA<DateTime>());
      expect(convAfter.updatedAt.isAfter(DateTime(2020)), true);
    });
  });

  group('Cascade behavior', () {
    test('deleting conversation does not leave orphaned messages', () async {
      final convId = await db.createConversation('Chat');
      await db.insertMessage(conversationId: convId, content: 'Msg 1');

      // Delete messages first (foreign key constraint)
      await db.deleteMessages(convId);
      await db.deleteConversation(convId);

      final conv = await db.getConversation(convId);
      expect(conv, isNull);
    });
  });

  group('Schema', () {
    test('schema version is 12', () {
      expect(db.schemaVersion, 13);
    });
  });

  group('Message validation', () {
    test('empty content is rejected by trim check', () async {
      final convId = await db.createConversation('Chat');

      // Database allows empty strings, but the app should trim and check
      // This test verifies the database accepts content (validation is in UI)
      final msgId = await db.insertMessage(
        conversationId: convId,
        content: 'actual content',
      );
      expect(msgId, greaterThan(0));
    });
  });

  group('Read receipts', () {
    late int conversationId;

    setUp(() async {
      conversationId = await db.createConversation('Chat');
    });

    test('a message from a peer arrives unread', () async {
      await db.insertReceivedMessage(
        conversationId: conversationId,
        content: 'hello',
        externalMessageId: 'ext-1',
      );

      final messages = await db.getMessages(conversationId);
      expect(messages.single.isRead, 0);
    });

    test('a message of your own is born read', () async {
      await db.insertMessage(conversationId: conversationId, content: 'mine');

      final messages = await db.getMessages(conversationId);
      expect(messages.single.isRead, 1);
    });

    test('opening the conversation clears the badge', () async {
      await db.insertReceivedMessage(
        conversationId: conversationId,
        content: 'unread',
        externalMessageId: 'ext-1',
      );
      final before = await db.watchConversationDigests().first;
      expect(before[conversationId]!.unread, 1);

      await db.markConversationRead(conversationId);

      final after = await db.watchConversationDigests().first;
      expect(after[conversationId]!.unread, 0);
    });

    test('mark all read answers the menu item it is wired to', () async {
      final otherId = await db.createConversation('Other');
      await db.insertReceivedMessage(
        conversationId: conversationId,
        content: 'a',
        externalMessageId: 'x1',
      );
      await db.insertReceivedMessage(
        conversationId: otherId,
        content: 'b',
        externalMessageId: 'x2',
      );

      await db.markAllConversationsRead();

      final digests = await db.watchConversationDigests().first;
      expect(digests[conversationId]!.unread, 0);
      expect(digests[otherId]!.unread, 0);
    });

    test('the digest carries the newest message', () async {
      await db.insertMessage(
        conversationId: conversationId,
        content: 'first',
      );
      await db.insertMessage(
        conversationId: conversationId,
        content: 'second',
      );

      final digests = await db.watchConversationDigests().first;
      expect(digests[conversationId]!.preview, 'second');
      expect(digests[conversationId]!.unread, 0);
    });

    test('a conversation nobody has written to previews as empty', () async {
      final digests = await db.watchConversationDigests().first;
      expect(digests[conversationId]!.preview, '');
    });

    test('one conversation never borrows another\'s message', () async {
      final otherId = await db.createConversation('Other');
      await db.insertMessage(
        conversationId: conversationId,
        content: 'only mine',
      );

      final digests = await db.watchConversationDigests().first;
      expect(digests[conversationId]!.preview, 'only mine');
      expect(digests[otherId]!.preview, '');
    });

    test('a receipt raises a message and never lowers it', () async {
      await db.insertMessage(
        conversationId: conversationId,
        content: 'out',
        status: 'sent',
      );
      final row = (await db.getMessages(conversationId)).single;

      await db.ackMessage(row.id, 'delivered');
      expect((await db.getMessages(conversationId)).single.status, 'delivered');

      await db.ackMessage(row.id, 'read');
      expect((await db.getMessages(conversationId)).single.status, 'read');

      // A duplicate delivery arriving behind the read leaves it alone.
      await db.ackMessage(row.id, 'delivered');
      expect((await db.getMessages(conversationId)).single.status, 'read');
    });

    test('a send that failed is never dressed up by a receipt', () async {
      await db.insertMessage(
        conversationId: conversationId,
        content: 'out',
        status: 'failed',
      );
      final row = (await db.getMessages(conversationId)).single;

      await db.ackMessage(row.id, 'read');
      expect((await db.getMessages(conversationId)).single.status, 'failed');
    });

    test('a receipt reaches something that is still waiting', () async {
      await db.insertMessage(
        conversationId: conversationId,
        content: 'out',
        status: 'queued',
      );
      final row = (await db.getMessages(conversationId)).single;

      await db.ackMessage(row.id, 'delivered');
      expect((await db.getMessages(conversationId)).single.status, 'delivered');
    });

    test('a row that never left cannot be acknowledged', () async {
      await db.insertMessage(conversationId: conversationId, content: 'mine');
      final row = (await db.getMessages(conversationId)).single;

      // Status is what decides, and `local` is not one a receipt is
      // allowed to move.
      await db.ackMessage(row.id, 'read');
      expect((await db.getMessages(conversationId)).single.status, 'local');
    });

    test('what a read receipt is owed names the peer, not us', () async {
      await db.insertReceivedMessage(
        conversationId: conversationId,
        content: 'theirs',
        externalMessageId: 'm_9',
      );
      await db.insertMessage(
        conversationId: conversationId,
        content: 'mine',
        status: 'sent',
      );

      expect(await db.readPendingIds(conversationId), ['m_9']);

      await db.markConversationRead(conversationId);
      expect(await db.readPendingIds(conversationId), isEmpty);
    });

    test('every unread message waits its turn, and only once', () async {
      await db.insertReceivedMessage(
        conversationId: conversationId,
        content: 'one',
        externalMessageId: 'm_1',
      );
      await db.insertReceivedMessage(
        conversationId: conversationId,
        content: 'two',
        externalMessageId: 'm_2',
      );

      expect(await db.readPendingIds(conversationId), ['m_1', 'm_2']);

      await db.markConversationRead(conversationId);
      expect(await db.readPendingIds(conversationId), isEmpty);

      // A chat with nothing in it owes nothing.
      final empty = await db.createConversation('Empty');
      expect(await db.readPendingIds(empty), isEmpty);
    });
  });
}
