import 'package:flutter/material.dart';
import 'package:onebit/features/ui/components/app_bottom_sheet.dart';

/// F10 — Conversation actions bottom sheet.
///
/// Shown on long-press of a conversation: Pin, Mute, Hide, Delete.
/// Includes peer header (avatar + name + last seen).
enum ConversationActionType {
  pin,
  mute,
  hide,
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
    actions: [
      SheetAction(
        icon: Icons.push_pin_outlined,
        label: 'Pin conversation',
        onTap: () {},
      ),
      SheetAction(
        icon: Icons.notifications_off_outlined,
        label: 'Mute notifications',
        onTap: () {},
      ),
      SheetAction(
        icon: Icons.visibility_off_outlined,
        label: 'Hide conversation',
        onTap: () {},
      ),
      SheetAction(
        icon: Icons.delete_outline,
        label: 'Delete conversation',
        isDestructive: true,
        onTap: () {},
      ),
    ],
  );
}
