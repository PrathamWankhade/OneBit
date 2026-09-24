/// I9.3 — Message conversation screen.
///
/// Shows outbound messages to a specific peer with a composer.
/// This is the I9 message screen — replaces the old I8 conversation
/// screen for direct messaging via I9 routing.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/features/message/application/outbound_message_store.dart';
import 'package:onebit/features/message/presentation/message_bubble.dart';
import 'package:onebit/features/message/presentation/message_composer.dart';
import 'package:onebit/features/message/providers/message_providers.dart';

/// Screen for composing and viewing messages to a specific peer.
///
/// Takes a [peerId] as route parameter and displays all outbound
/// messages to that peer with a composer at the bottom.
class MessageScreen extends ConsumerWidget {
  const MessageScreen({required this.peerId, super.key});

  /// The destination peer's IdentityId (hex-encoded public key).
  final String peerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = ref.watch(outboundMessageStoreProvider).getByDestination(peerId);

    return Scaffold(
      appBar: _MessageAppBar(peerId: peerId),
      body: Column(
        children: [
          Expanded(
            child: messages.isEmpty
                ? const _EmptyState()
                : _MessageList(messages: messages),
          ),
          MessageComposer(
            onSend: (text) => _sendMessage(ref, text),
          ),
        ],
      ),
    );
  }

  void _sendMessage(WidgetRef ref, String text) {
    ref.read(messageComposerProvider.notifier).sendMessage(
          destinationPeerId: peerId,
          content: text,
        );
    // Errors are shown via the composer's error state.
  }
}

/// AppBar showing peer name and back navigation.
class _MessageAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const _MessageAppBar({required this.peerId});

  final String peerId;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppBar(
      title: _PeerTitle(peerId: peerId),
    );
  }
}

/// Title widget that resolves peer display name.
class _PeerTitle extends ConsumerWidget {
  const _PeerTitle({required this.peerId});

  final String peerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // For now, show truncated peerId. In I9.10 we'll resolve
    // display names from the peer registry.
    final displayId = peerId.length > 12
        ? '${peerId.substring(0, 8)}\u2026${peerId.substring(peerId.length - 4)}'
        : peerId;

    return Text(displayId, style: const TextStyle(fontSize: 16));
  }
}

/// Scrollable message list with auto-scroll to bottom.
class _MessageList extends StatefulWidget {
  const _MessageList({required this.messages});

  final List<OutboundMessage> messages;

  @override
  State<_MessageList> createState() => _MessageListState();
}

class _MessageListState extends State<_MessageList> {
  final _scrollController = ScrollController();

  @override
  void didUpdateWidget(_MessageList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.messages.length > oldWidget.messages.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: widget.messages.length,
      itemBuilder: (context, index) {
        final outbound = widget.messages[index];
        return MessageBubble(
          content: outbound.text,
          createdAt: outbound.createdAt,
          state: outbound.message.state,
        );
      },
    );
  }
}

/// Empty state shown when no messages exist yet.
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No messages yet',
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Send a message to start the conversation',
            style: TextStyle(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
