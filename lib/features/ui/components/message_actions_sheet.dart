import 'package:flutter/material.dart';
import 'package:onebit/features/ui/components/app_bottom_sheet.dart';

/// F10 — Message actions bottom sheet.
///
/// Shown on long-press of a message.
///
/// Only actions the app can actually carry out are listed. Reply,
/// forward, react, edit and details were here as rows with an empty tap
/// handler — a menu that looks like five things and does none of them is
/// worse than a menu that says two. They come back as they land.
enum MessageActionType {
  copy,
  delete,
}

/// Show message actions and return the selected action type.
///
/// [canCopy] is false for a message whose body is an attachment tag —
/// there is no text worth putting on the clipboard, and offering to
/// copy `[image:photo.png]` would just be another thing that lies.
Future<MessageActionType?> showMessageActions(
  BuildContext context, {
  bool canCopy = true,
}) {
  return showAppBottomSheet<MessageActionType>(
    context,
    actions: [
      if (canCopy)
        const SheetAction(
          icon: Icons.copy,
          label: 'Copy',
          result: MessageActionType.copy,
        ),
      const SheetAction(
        icon: Icons.delete_outline,
        label: 'Delete',
        isDestructive: true,
        result: MessageActionType.delete,
      ),
    ],
  );
}
