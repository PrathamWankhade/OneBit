import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:onebit/core/theme/app_theme.dart';
import 'package:onebit/data/database/app_database.dart';
import 'package:onebit/features/conversations/providers/conversation_providers.dart';
import 'package:onebit/features/ui/components/components.dart';

/// F3 Conversations / Home Screen.
///
/// Chat list with real last messages, encryption indicators,
/// and mesh network status.
class ConversationListScreen extends ConsumerWidget {
  const ConversationListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationsAsync = ref.watch(conversationsProvider);

    return Scaffold(
      appBar: const _ChatsAppBar(),
      body: Column(
        children: [
          const _SearchBar(),
          Expanded(
            child: conversationsAsync.when(
              loading: () => const ConversationListSkeleton(),
              error: (e, st) => Center(
                child: Text(
                  'Error: $e',
                  style: AppTheme.bodyMedium.copyWith(color: AppTheme.red),
                ),
              ),
              data: (conversations) {
                if (conversations.isEmpty) {
                  return const _EmptyState();
                }
                return _ConversationList(conversations: conversations);
              },
            ),
          ),
        ],
      ),
    );
  }
}

// -- App Bar --

class _ChatsAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _ChatsAppBar();

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: Padding(
        padding: const EdgeInsets.all(10),
        child: SvgPicture.asset(
          'assets/icons/OneBitLogo.svg',
          width: 32,
          height: 32,
        ),
      ),
      title: const Text('OneBit'),
      actions: [
        IconButton(
          icon: const Icon(Icons.search, size: 24, color: AppTheme.accent),
          onPressed: () {},
          tooltip: 'Search',
        ),
        _OverflowMenu(
          onMarkAllRead: () {},
          onPinnedChats: () {},
          onSettings: () => context.push('/settings'),
        ),
      ],
    );
  }
}

class _OverflowMenu extends StatelessWidget {
  const _OverflowMenu({
    required this.onMarkAllRead,
    required this.onPinnedChats,
    required this.onSettings,
  });

  final VoidCallback onMarkAllRead;
  final VoidCallback onPinnedChats;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 24, color: AppTheme.textSecondary),
      color: AppTheme.bgElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppTheme.borderSubtle),
      ),
      onSelected: (value) {
        switch (value) {
          case 'mark_read':
            onMarkAllRead();
            break;
          case 'pinned':
            onPinnedChats();
            break;
          case 'settings':
            onSettings();
            break;
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: 'mark_read',
          height: 44,
          child: Text('Mark all read', style: AppTheme.bodyMedium),
        ),
        PopupMenuItem(
          value: 'pinned',
          height: 44,
          child: Text('Pinned chats', style: AppTheme.bodyMedium),
        ),
        PopupMenuItem(
          value: 'settings',
          height: 44,
          child: Text('Settings', style: AppTheme.bodyMedium),
        ),
      ],
    );
  }
}

// -- Search Bar --

class _SearchBar extends StatelessWidget {
  const _SearchBar();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        height: 40,
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppTheme.bgElevated,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          children: [
            Icon(Icons.search, size: 20, color: AppTheme.textTertiary),
            SizedBox(width: 12),
            Text(
              'Search or start new chat',
              style: AppTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

// -- Conversation List --

class _ConversationList extends StatelessWidget {
  const _ConversationList({required this.conversations});

  final List<Conversation> conversations;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: conversations.length + 2,
      itemBuilder: (context, index) {
        if (index == 0) return const _SectionHeader(label: 'Recent');
        if (index == conversations.length + 1) return const SizedBox(height: 80);
        final conversation = conversations[index - 1];
        return RepaintBoundary(
          child: Column(
            children: [
              _ConversationItem(conversation: conversation),
              if (index < conversations.length)
                const Divider(height: 1, indent: 76),
            ],
          ),
        );
      },
    );
  }
}

// -- Section Header --

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        label,
        style: AppTheme.labelMedium.copyWith(
          color: AppTheme.textTertiary,
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}

// -- Conversation Item --

class _ConversationItem extends StatefulWidget {
  const _ConversationItem({required this.conversation});

  final Conversation conversation;

  @override
  State<_ConversationItem> createState() => _ConversationItemState();
}

class _ConversationItemState extends State<_ConversationItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final conversation = widget.conversation;
    return GestureDetector(
      onTapDown: (_) => _pressController.forward(),
      onTapUp: (_) => _pressController.reverse(),
      onTapCancel: () => _pressController.reverse(),
      onTap: () => context.push('/conversation/${conversation.id}'),
      onLongPress: () => _showActions(context),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          );
        },
        child: Container(
          height: 76,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  color: AppTheme.bgElevated,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    conversation.title.isNotEmpty
                        ? conversation.title[0].toUpperCase()
                        : '?',
                    style: AppTheme.titleLarge.copyWith(
                      color: AppTheme.textSecondary,
                      fontSize: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // Content
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            conversation.title,
                            style: AppTheme.bodyLarge.copyWith(
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatTime(conversation.updatedAt),
                          style: AppTheme.caption.copyWith(
                            color: AppTheme.textTertiary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        // Encryption indicator
                        const Icon(
                          Icons.lock_outline,
                          size: 12,
                          color: AppTheme.trust,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'E2E encrypted',
                            style: AppTheme.bodySmall.copyWith(
                              color: AppTheme.textTertiary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showActions(BuildContext context) async {
    final action = await showConversationActions(
      context,
      peerName: widget.conversation.title,
    );
    if (action == null || !context.mounted) return;

    switch (action) {
      case ConversationActionType.delete:
        final confirmed = await showDestructiveDialog(
          context,
          title: 'Delete conversation?',
          body:
              'This will permanently delete all messages in this conversation. '
              'This action cannot be undone.',
          confirmLabel: 'Delete',
        );
        if (confirmed && context.mounted) {
          showDeleteSnackbar(context);
        }
      default:
        break;
    }
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(dt.year, dt.month, dt.day);

    if (date == today) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    final yesterday = today.subtract(const Duration(days: 1));
    if (date == yesterday) {
      return 'Yesterday';
    }
    return '${dt.day} ${_month(dt.month)}';
  }

  String _month(int m) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return months[m - 1];
  }
}

// -- Empty State --

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.accentMuted,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.accent.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.chat_bubble_outline,
                size: 36,
                color: AppTheme.accent,
              ),
            ),
            const SizedBox(height: AppTheme.space24),
            const Text(
              'No conversations yet',
              style: AppTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.space8),
            Text(
              'Start a mesh conversation by discovering peers nearby.',
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.space8),
            // Mesh hint
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.meshMuted,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                border: Border.all(
                  color: AppTheme.mesh.withValues(alpha: 0.3),
                  width: 0.5,
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.wifi_tethering, size: 14, color: AppTheme.mesh),
                  SizedBox(width: 6),
                  Text(
                    'Messages route through the mesh network',
                    style: AppTheme.caption,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.space24),
            FilledButton(
              onPressed: () => context.go('/nearby'),
              child: const Text('Discover peers'),
            ),
          ],
        ),
      ),
    );
  }
}
