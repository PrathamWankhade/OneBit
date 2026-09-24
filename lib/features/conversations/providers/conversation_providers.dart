import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/app/app.dart';
import 'package:onebit/data/database/app_database.dart';

final conversationsProvider = StreamProvider<List<Conversation>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchConversations();
});

final messagesProvider = StreamProvider.family<List<Message>, int>((ref, conversationId) {
  final db = ref.watch(databaseProvider);
  return db.watchMessages(conversationId);
});

final conversationProvider = FutureProvider.family<Conversation?, int>((ref, id) async {
  final db = ref.watch(databaseProvider);
  return db.getConversation(id);
});
