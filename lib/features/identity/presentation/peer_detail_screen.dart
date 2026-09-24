import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:onebit/core/theme/app_theme.dart';
import 'package:onebit/features/identity/identity_providers.dart';
import 'package:onebit/features/identity/presentation/verification_indicator.dart';
import 'package:onebit/features/peer_registry/peer_connection_providers.dart';
import 'package:onebit/features/peer_registry/peer_entry.dart';
import 'package:onebit/features/peer_registry/peer_lifecycle_state.dart';
import 'package:onebit/features/peer_registry/peer_registry_providers.dart';
import 'package:onebit/features/settings/data/settings_providers.dart';
import 'package:onebit/features/trust/peer_verification.dart';
import 'package:onebit/features/trust/trust_providers.dart';
import 'package:onebit/features/trust/trust_state.dart';

/// WhatsApp-style Contact Info screen.
///
/// Shows peer details with action buttons, media gallery,
/// settings toggles, and management actions.
class PeerDetailScreen extends ConsumerWidget {
  const PeerDetailScreen({required this.peerIdentityId, super.key});

  final String peerIdentityId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final peersAsync = ref.watch(peerEntriesProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgBase,
      appBar: AppBar(
        backgroundColor: AppTheme.bgSurface,
        title: Text(
          'Contact info',
          style: AppTheme.titleLarge.copyWith(color: AppTheme.textPrimary),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: AppTheme.textSecondary),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, size: 24, color: AppTheme.textSecondary),
            onPressed: () {},
          ),
        ],
      ),
      body: peersAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.accent),
        ),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppTheme.red),
              const SizedBox(height: 16),
              Text('Error: $e', style: AppTheme.bodyMedium),
            ],
          ),
        ),
        data: (peers) {
          final peer = peers.where(
            (p) => p.identityId == peerIdentityId,
          ).firstOrNull;

          if (peer == null) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.person_off,
                    size: 48,
                    color: AppTheme.textTertiary,
                  ),
                  SizedBox(height: 16),
                  Text('Peer not found', style: AppTheme.bodyLarge),
                ],
              ),
            );
          }

          return _PeerBody(peer: peer);
        },
      ),
    );
  }
}

class _PeerBody extends ConsumerStatefulWidget {
  const _PeerBody({required this.peer});

  final PeerEntry peer;

  @override
  ConsumerState<_PeerBody> createState() => _PeerBodyState();
}

class _PeerBodyState extends ConsumerState<_PeerBody> {
  bool? _disappearingMessages;
  bool? _chatLock;
  bool? _advancedPrivacy;
  bool _settingsLoaded = false;

  @override
  Widget build(BuildContext context) {
    final peer = widget.peer;
    final identityId = peer.identityId;
    final trustService = ref.read(trustServiceProvider);
    final settingsRepo = ref.read(settingsRepositoryProvider);

    final trust = trustService.getTrust(identityId);
    final verification = trustService.getVerification(identityId);

    final manager = ref.read(peerConnectionManagerProvider);
    final isConnected = manager.isPeerConnected(identityId);
    final lifecycleState = manager.lifecycleStateFor(identityId);

    final verificationStatus = _resolveVerificationStatus(
      verification,
      trust.state,
    );

    if (!_settingsLoaded) {
      _disappearingMessages = settingsRepo.peerDisappearingMessages(identityId);
      _chatLock = settingsRepo.peerChatLock(identityId);
      _advancedPrivacy = settingsRepo.peerAdvancedPrivacy(identityId);
      _settingsLoaded = true;
    }

    final disappearingMessages = _disappearingMessages ?? false;
    final chatLockEnabled = _chatLock ?? false;
    final advancedPrivacyEnabled = _advancedPrivacy ?? false;

    return SingleChildScrollView(
      child: Column(
        children: [
          // Avatar + Name + About
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24),
            color: AppTheme.bgSurface,
            child: Column(
              children: [
                // Avatar
                VerificationAvatar(
                  status: verificationStatus,
                  size: 96,
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: const BoxDecoration(
                      color: AppTheme.bgElevated,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      peer.peer.displayName.isNotEmpty
                          ? peer.peer.displayName[0].toUpperCase()
                          : '?',
                      style: AppTheme.displayLarge.copyWith(color: AppTheme.accent),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Name
                Text(
                  peer.peer.displayName,
                  style: AppTheme.headlineMedium.copyWith(
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                // OneBit ID as subtitle
                Text(
                  _formatShortId(identityId),
                  style: AppTheme.caption.copyWith(color: AppTheme.textTertiary),
                ),
                const SizedBox(height: 4),
                // Connection status
                Text(
                  _connectionLabel(lifecycleState),
                  style: AppTheme.bodySmall.copyWith(
                    color: isConnected ? AppTheme.green : AppTheme.textTertiary,
                  ),
                ),
                const SizedBox(height: 4),
                VerificationBadge(status: verificationStatus),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Action buttons row
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ActionColumn(
                  icon: Icons.search,
                  label: 'Search',
                  onTap: () {},
                ),
                _ActionColumn(
                  icon: Icons.share,
                  label: 'Share',
                  onTap: () {},
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // About section
          if (peer.peer.about != null && peer.peer.about!.isNotEmpty)
            _InfoSection(
              children: [
                _InfoRow(
                  icon: Icons.info_outline,
                  label: 'About',
                  value: peer.peer.about!,
                ),
              ],
            ),
          if (peer.peer.about != null && peer.peer.about!.isNotEmpty)
            const SizedBox(height: 8),

          // Media, links, and docs
          _InfoSection(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                leading: const Icon(Icons.photo_library_outlined, color: AppTheme.textSecondary),
                title: Text(
                  'Media, links, and docs',
                  style: AppTheme.bodyMedium.copyWith(color: AppTheme.textPrimary),
                ),
                trailing: const Icon(Icons.chevron_right, color: AppTheme.textTertiary),
                onTap: () {},
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Settings toggles
          _InfoSection(
            children: [
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                secondary: const Icon(Icons.timer_outlined, color: AppTheme.textSecondary),
                title: Text(
                  'Disappearing messages',
                  style: AppTheme.bodyMedium.copyWith(color: AppTheme.textPrimary),
                ),
                subtitle: Text(
                  disappearingMessages ? 'On' : 'Off',
                  style: AppTheme.caption.copyWith(color: AppTheme.textTertiary),
                ),
                value: disappearingMessages,
                onChanged: (value) async {
                  await settingsRepo.setPeerDisappearingMessages(identityId, value);
                  setState(() => _disappearingMessages = value);
                },
              ),
              const Divider(height: 1, indent: 56),
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                secondary: const Icon(Icons.lock_outline, color: AppTheme.textSecondary),
                title: Text(
                  'Chat lock',
                  style: AppTheme.bodyMedium.copyWith(color: AppTheme.textPrimary),
                ),
                subtitle: Text(
                  chatLockEnabled ? 'On' : 'Off',
                  style: AppTheme.caption.copyWith(color: AppTheme.textTertiary),
                ),
                value: chatLockEnabled,
                onChanged: (value) async {
                  await settingsRepo.setPeerChatLock(identityId, value);
                  setState(() => _chatLock = value);
                },
              ),
              const Divider(height: 1, indent: 56),
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                secondary: const Icon(Icons.shield_outlined, color: AppTheme.textSecondary),
                title: Text(
                  'Advanced chat privacy',
                  style: AppTheme.bodyMedium.copyWith(color: AppTheme.textPrimary),
                ),
                subtitle: Text(
                  advancedPrivacyEnabled ? 'On' : 'Off',
                  style: AppTheme.caption.copyWith(color: AppTheme.textTertiary),
                ),
                value: advancedPrivacyEnabled,
                onChanged: (value) async {
                  await settingsRepo.setPeerAdvancedPrivacy(identityId, value);
                  setState(() => _advancedPrivacy = value);
                },
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Encryption info
          const _InfoSection(
            children: [
              _InfoRow(
                icon: Icons.lock,
                label: 'Encryption',
                value: 'E2E encryption. Messages are end-to-end encrypted.',
                iconColor: AppTheme.green,
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Identity section (collapsed)
          _InfoSection(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                leading: const Icon(Icons.fingerprint, color: AppTheme.textSecondary),
                title: Text(
                  'Verify security code',
                  style: AppTheme.bodyMedium.copyWith(color: AppTheme.textPrimary),
                ),
                trailing: const Icon(Icons.chevron_right, color: AppTheme.textTertiary),
                onTap: () => context.push('/identity/verify'),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Management actions
          _InfoSection(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                leading: const Icon(Icons.group_add_outlined, color: AppTheme.textSecondary),
                title: Text(
                  'Add to group',
                  style: AppTheme.bodyMedium.copyWith(color: AppTheme.textPrimary),
                ),
                onTap: () {},
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                leading: const Icon(Icons.star_border, color: AppTheme.textSecondary),
                title: Text(
                  'Add to favourites',
                  style: AppTheme.bodyMedium.copyWith(color: AppTheme.textPrimary),
                ),
                onTap: () {},
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                leading: const Icon(
                  Icons.notifications_off_outlined,
                  color: AppTheme.textSecondary,
                ),
                title: Text(
                  'Mute notifications',
                  style: AppTheme.bodyMedium.copyWith(color: AppTheme.textPrimary),
                ),
                onTap: () {},
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                leading: const Icon(
                  Icons.delete_outline,
                  color: AppTheme.red,
                ),
                title: Text(
                  'Clear chat',
                  style: AppTheme.bodyMedium.copyWith(color: AppTheme.red),
                ),
                onTap: () => _showClearChatConfirmation(context),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Block and Report
          _InfoSection(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                leading: Icon(
                  trust.state == TrustState.revoked
                      ? Icons.check_circle_outline
                      : Icons.block,
                  color: trust.state == TrustState.revoked
                      ? AppTheme.green
                      : AppTheme.red,
                ),
                title: Text(
                  trust.state == TrustState.revoked
                      ? 'Unblock peer'
                      : 'Block peer',
                  style: AppTheme.bodyMedium.copyWith(
                    color: trust.state == TrustState.revoked
                        ? AppTheme.green
                        : AppTheme.red,
                  ),
                ),
                onTap: () {
                  if (trust.state == TrustState.revoked) {
                    _unblockPeer(context, ref);
                  } else {
                    _showBlockConfirmation(context, ref);
                  }
                },
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                leading: const Icon(
                  Icons.report_outlined,
                  color: AppTheme.red,
                ),
                title: Text(
                  'Report peer',
                  style: AppTheme.bodyMedium.copyWith(color: AppTheme.red),
                ),
                onTap: () {},
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Remove peer button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showRemoveConfirmation(context, ref),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.red,
                  side: const BorderSide(color: AppTheme.red),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: Text(
                  'Remove peer',
                  style: AppTheme.bodyMedium.copyWith(color: AppTheme.red),
                ),
              ),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  VerificationDisplayStatus _resolveVerificationStatus(
    PeerVerification verification,
    TrustState trustState,
  ) {
    if (trustState == TrustState.revoked) {
      return VerificationDisplayStatus.blocked;
    }
    if (verification.isVerified) {
      return VerificationDisplayStatus.verified;
    }
    return VerificationDisplayStatus.unverified;
  }

  String _connectionLabel(PeerLifecycleState state) {
    switch (state) {
      case PeerLifecycleState.unknown:
        return 'offline';
      case PeerLifecycleState.discovered:
        return 'discovered';
      case PeerLifecycleState.connecting:
        return 'connecting...';
      case PeerLifecycleState.connected:
        return 'online';
      case PeerLifecycleState.disconnecting:
        return 'disconnecting...';
      case PeerLifecycleState.disconnected:
        return 'offline';
    }
  }

  String _formatShortId(String id) {
    if (id.length <= 16) return id;
    return '${id.substring(0, 8)}...${id.substring(id.length - 8)}';
  }

  Future<void> _unblockPeer(BuildContext context, WidgetRef ref) async {
    final trustService = ref.read(trustServiceProvider);
    try {
      trustService.establishTrust(
        peerIdentityId: widget.peer.identityId,
        at: DateTime.now(),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to unblock: $e')),
        );
      }
    }
  }

  void _showBlockConfirmation(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.bgSurface,
        title: Text(
          'Block peer',
          style: AppTheme.titleLarge.copyWith(color: AppTheme.textPrimary),
        ),
        content: Text(
          'Block this peer? They won\'t be able to message you '
          'and their trust status will be revoked.',
          style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.accent),
            ),
          ),
          TextButton(
            onPressed: () => _confirmBlock(context, ref),
            child: Text(
              'Block',
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.red),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmBlock(BuildContext context, WidgetRef ref) async {
    final trustService = ref.read(trustServiceProvider);
    trustService.revokeTrust(
      peerIdentityId: widget.peer.identityId,
      at: DateTime.now(),
    );
    if (context.mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Peer blocked')),
      );
    }
  }

  void _showClearChatConfirmation(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.bgSurface,
        title: Text(
          'Clear chat',
          style: AppTheme.titleLarge.copyWith(color: AppTheme.textPrimary),
        ),
        content: Text(
          'Delete all messages in this chat? This cannot be undone.',
          style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.accent),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Chat cleared')),
              );
            },
            child: Text(
              'Clear',
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.red),
            ),
          ),
        ],
      ),
    );
  }

  void _showRemoveConfirmation(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.bgSurface,
        title: Text(
          'Remove peer',
          style: AppTheme.titleLarge.copyWith(color: AppTheme.textPrimary),
        ),
        content: Text(
          'Remove this peer from your known peers? '
          'This will delete the peer identity record.',
          style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.accent),
            ),
          ),
          TextButton(
            onPressed: () => _confirmRemove(context, ref),
            child: Text(
              'Remove',
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.red),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRemove(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(identityRepositoryProvider);
    try {
      await repo.deletePeerIdentity(widget.peer.peer.id);
    } catch (e) {
      // Ignore — peer may already be deleted.
    }
    if (context.mounted) {
      Navigator.of(context).pop();
      context.go('/identity');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Peer removed')),
      );
    }
  }
}

// ── Reusable widgets ─────────────────────────────────────────────

class _ActionColumn extends StatelessWidget {
  const _ActionColumn({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: AppTheme.bgElevated,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 22, color: AppTheme.accent),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: AppTheme.caption.copyWith(color: AppTheme.accent),
          ),
        ],
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.bgSurface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: children,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: Icon(icon, size: 20, color: iconColor ?? AppTheme.textSecondary),
      title: Text(
        label,
        style: AppTheme.bodyMedium.copyWith(color: AppTheme.textPrimary),
      ),
      subtitle: Text(
        value,
        style: AppTheme.caption.copyWith(color: AppTheme.textTertiary),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
