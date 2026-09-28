import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/app/app.dart';
import 'package:onebit/data/database/app_database.dart';
import 'package:onebit/features/conversations/presentation/conversation_list_screen.dart';

AppDatabase createTestDb() =>
    AppDatabase.test(DatabaseConnection(NativeDatabase.memory()));

void main() {
  /// Bounded steps: the rows are fed by streams, and a `pumpAndSettle`
  /// has no business waiting on a list that never declares itself done.
  Future<void> pumpList(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 250));
  }

  Future<AppDatabase> pumpScreen(
    WidgetTester tester,
    AppDatabase db,
  ) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: const ConversationListScreen(),
        ),
      ),
    );
    await pumpList(tester);
    return db;
  }

  testWidgets('a row shows the last thing that happened in the chat',
      (tester) async {
    final db = createTestDb();
    final convId = await db.createConversation('Peer B');
    await db.insertMessage(conversationId: convId, content: 'first');
    await db.insertReceivedMessage(
      conversationId: convId,
      content: 'are you there?',
      externalMessageId: 'ext-1',
    );
    await db.createConversation('Peer C');

    await pumpScreen(tester, db);

    expect(find.text('Peer B'), findsOneWidget);
    expect(find.text('are you there?'), findsOneWidget);

    // A chat with nothing in it says so rather than repeating a label
    // about encryption that no message ever earned.
    expect(find.text('No messages yet'), findsOneWidget);
    expect(find.text('E2E encrypted'), findsNothing);

    await db.close();
  });

  testWidgets('an unread message lights the badge, opening it puts it out',
      (tester) async {
    final db = createTestDb();
    final convId = await db.createConversation('Peer B');
    await db.insertReceivedMessage(
      conversationId: convId,
      content: 'are you there?',
      externalMessageId: 'ext-1',
    );

    await pumpScreen(tester, db);
    expect(find.text('1'), findsOneWidget);

    // What the screen does when it is opened.
    await db.markConversationRead(convId);
    await pumpList(tester);

    expect(find.text('1'), findsNothing);
    expect(find.text('are you there?'), findsOneWidget);

    await db.close();
  });

  testWidgets('a chat of your own does not badge itself', (tester) async {
    final db = createTestDb();
    final convId = await db.createConversation('Peer B');
    await db.insertMessage(conversationId: convId, content: 'mine');

    await pumpScreen(tester, db);

    expect(find.text('mine'), findsOneWidget);
    expect(find.text('1'), findsNothing);

    await db.close();
  });

  testWidgets('mark all read clears every badge at once', (tester) async {
    final db = createTestDb();
    final first = await db.createConversation('Peer B');
    final second = await db.createConversation('Peer C');
    await db.insertReceivedMessage(
      conversationId: first,
      content: 'one',
      externalMessageId: 'x1',
    );
    await db.insertReceivedMessage(
      conversationId: second,
      content: 'two',
      externalMessageId: 'x2',
    );

    await pumpScreen(tester, db);
    expect(find.text('1'), findsNWidgets(2));

    await db.markAllConversationsRead();
    await pumpList(tester);

    expect(find.text('1'), findsNothing);

    await db.close();
  });
}
