import 'package:flutter/material.dart';
import 'package:onebit/features/ui/components/app_bottom_sheet.dart';

/// F10 — Peer actions bottom sheet.
///
/// Shown from peer list/detail: Start conversation, Verify identity,
/// View identity, Copy OneBit ID, Block peer, Forget peer.
/// Includes peer header (avatar + name + status).
enum PeerActionType {
  startConversation,
  verifyIdentity,
  viewIdentity,
  copyId,
  block,
  forget,
}

/// Show peer actions and return the selected action type.
Future<PeerActionType?> showPeerActions(
  BuildContext context, {
  required String peerName,
  String? statusText,
}) {
  return showAppBottomSheet<PeerActionType>(
    context,
    actions: [
      const SheetAction(
        icon: Icons.chat_bubble_outline,
        label: 'Start conversation',
        onTap: null,
      ),
      const SheetAction(
        icon: Icons.verified_outlined,
        label: 'Verify identity',
        onTap: null,
      ),
      const SheetAction(
        icon: Icons.person_outline,
        label: 'View identity',
        onTap: null,
      ),
      const SheetAction(
        icon: Icons.copy,
        label: 'Copy OneBit ID',
        onTap: null,
      ),
      SheetAction(
        icon: Icons.block,
        label: 'Block peer',
        isDestructive: true,
        onTap: () {},
      ),
      SheetAction(
        icon: Icons.delete_outline,
        label: 'Forget peer',
        isDestructive: true,
        onTap: () {},
      ),
    ],
  );
}
