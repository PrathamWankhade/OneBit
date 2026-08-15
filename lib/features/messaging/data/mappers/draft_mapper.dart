import 'package:onebit/core/database/database.dart';
import 'package:onebit/features/messaging/domain/drafts/draft.dart';

/// Maps `MessageDraftRow` ↔ [Draft].
abstract final class DraftMapper {
  const DraftMapper._();

  static MessageDraftRow toRow(Draft draft) => MessageDraftRow(
    channelId: draft.channelId,
    body: draft.body,
    editingMessageId: draft.editingMessageId,
    createdAt: draft.createdAt ?? DateTime.now(),
    updatedAt: draft.updatedAt ?? DateTime.now(),
  );

  static Draft toDomain(MessageDraftRow row) => Draft(
    channelId: row.channelId,
    body: row.body,
    editingMessageId: row.editingMessageId,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
  );
}
