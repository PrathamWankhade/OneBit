import 'package:flutter/material.dart';
import 'package:onebit/features/ui/components/app_bottom_sheet.dart';

/// F10 — Message actions bottom sheet.
///
/// Shown on long-press of a message: Reply, Forward, Copy, React, Edit, Delete, Details.
enum MessageActionType {
  reply,
  forward,
  copy,
  react,
  edit,
  delete,
  details,
}

/// Show message actions and return the selected action type.
Future<MessageActionType?> showMessageActions(
  BuildContext context, {
  bool isOwnMessage = false,
  bool canEdit = false,
}) {
  final actions = <SheetAction>[
    const SheetAction(
      icon: Icons.reply,
      label: 'Reply',
      onTap: null, // replaced below
    ),
    const SheetAction(
      icon: Icons.forward,
      label: 'Forward',
      onTap: null,
    ),
    const SheetAction(
      icon: Icons.copy,
      label: 'Copy',
      onTap: null,
    ),
    const SheetAction(
      icon: Icons.emoji_emotions_outlined,
      label: 'React',
      onTap: null,
    ),
  ];

  if (isOwnMessage && canEdit) {
    actions.add(const SheetAction(
      icon: Icons.edit_outlined,
      label: 'Edit',
      onTap: null,
    ));
  }

  actions.add(const SheetAction(
    icon: Icons.delete_outline,
    label: 'Delete',
    onTap: null,
    isDestructive: true,
  ));

  actions.add(const SheetAction(
    icon: Icons.info_outline,
    label: 'Details',
    onTap: null,
  ));

  // Map indices to action types
  final types = <MessageActionType>[
    MessageActionType.reply,
    MessageActionType.forward,
    MessageActionType.copy,
    MessageActionType.react,
    if (isOwnMessage && canEdit) MessageActionType.edit,
    MessageActionType.delete,
    MessageActionType.details,
  ];

  // Rebuild with proper onTap
  final mappedActions = <SheetAction>[];
  for (var i = 0; i < actions.length; i++) {
    final original = actions[i];
    mappedActions.add(SheetAction(
      icon: original.icon,
      label: original.label,
      isDestructive: original.isDestructive,
      trailing: original.trailing,
      onTap: () {}, // Will be overridden by caller via navigator result
    ));
  }

  // Instead, use a simpler approach: return the index-based type
  return _showMessageActionsSheet(context, types: types);
}

Future<MessageActionType?> _showMessageActionsSheet(
  BuildContext context, {
  required List<MessageActionType> types,
}) async {
  final result = await showAppBottomSheet<int>(
    context,
    actions: types.map((type) => _actionForType(type)).toList(),
  );
  if (result == null || result < 0 || result >= types.length) return null;
  return types[result];
}

SheetAction _actionForType(MessageActionType type) {
  switch (type) {
    case MessageActionType.reply:
      return SheetAction(
        icon: Icons.reply,
        label: 'Reply',
        onTap: () {},
      );
    case MessageActionType.forward:
      return SheetAction(
        icon: Icons.forward,
        label: 'Forward',
        onTap: () {},
      );
    case MessageActionType.copy:
      return SheetAction(
        icon: Icons.copy,
        label: 'Copy',
        onTap: () {},
      );
    case MessageActionType.react:
      return SheetAction(
        icon: Icons.emoji_emotions_outlined,
        label: 'React',
        onTap: () {},
      );
    case MessageActionType.edit:
      return SheetAction(
        icon: Icons.edit_outlined,
        label: 'Edit',
        onTap: () {},
      );
    case MessageActionType.delete:
      return SheetAction(
        icon: Icons.delete_outline,
        label: 'Delete',
        isDestructive: true,
        onTap: () {},
      );
    case MessageActionType.details:
      return SheetAction(
        icon: Icons.info_outline,
        label: 'Details',
        onTap: () {},
      );
  }
}
