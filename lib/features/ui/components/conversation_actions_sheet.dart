import 'package:flutter/material.dart';
import 'package:onebit/features/ui/components/app_bottom_sheet.dart';

/// F10 — Conversation actions bottom sheet.
///
/// Shown on long-press of a conversation.
///
/// Pin, mute and hide used to be listed here with no handler behind
/// them, so only deletion was ever reachable — and it needs to be
/// reachable for real, since it is the one thing a user can do to a
/// chat they no longer want.
enum ConversationActionType {
  delete,
}

/// Show conversation actions and return the selected action type.
Future<ConversationActionType?> showConversationActions(
  BuildContext context, {
  required String peerName,
  String? lastSeen,
}) {
  return showAppBottomSheet<ConversationActionType>(
    context,
    actions: const [
      SheetAction(
        icon: Icons.delete_outline,
        label: 'Delete conversation',
        isDestructive: true,
        result: ConversationActionType.delete,
      ),
    ],
  );
}
