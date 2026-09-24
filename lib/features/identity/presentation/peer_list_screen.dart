import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:onebit/features/peer_registry/peer_entry.dart';
import 'package:onebit/features/peer_registry/peer_lifecycle_state.dart';
import 'package:onebit/features/peer_registry/peer_registry_providers.dart';
import 'package:onebit/features/trust/trust_state.dart';

/// Screen showing all known peers with their trust, verification,
/// and connection state.
///
/// Displays multiple peers simultaneously, each independently
/// addressable with its own identity and status.
class PeerListScreen extends ConsumerWidget {
  const PeerListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final peersAsync = ref.watch(peerEntriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Peers')),
      body: peersAsync.when(
        loading: () => const _LoadingState(),
        error: (e, _) => _ErrorState(error: e),
        data: (peers) {
          if (peers.isEmpty) {
            return const _EmptyState();
          }
          return _PeerListView(peers: peers);
        },
      ),
    );
  }
}

// ── Loading State ──────────────────────────────────────────────

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading peers\u2026'),
        ],
      ),
    );
  }
}

// ── Error State ────────────────────────────────────────────────

class _ErrorState extends ConsumerWidget {
  const _ErrorState({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: theme.colorScheme.error.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 24),
            Text(
              'Unable to load peers',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Something went wrong while loading your peers.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => ref.invalidate(peerEntriesProvider),
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty State ────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'No peers yet',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Discover nearby OneBit devices\nor verify a peer to get started.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Peer List View ─────────────────────────────────────────────

class _PeerListView extends ConsumerWidget {
  const _PeerListView({required this.peers});

  final List<PeerEntry> peers;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sorted = _sortPeers(peers);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            '${sorted.length} peer${sorted.length == 1 ? '' : 's'}',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.separated(
            itemCount: sorted.length,
            separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
            itemBuilder: (context, index) => _PeerTile(
              key: ValueKey(sorted[index].identityId),
              peer: sorted[index],
            ),
          ),
        ),
      ],
    );
  }

  /// Sort peers: connected first, then by lifecycle, then by name.
  List<PeerEntry> _sortPeers(List<PeerEntry> peers) {
    final sorted = List<PeerEntry>.from(peers);
    sorted.sort((a, b) {
      // Connected peers first.
      if (a.isConnected && !b.isConnected) return -1;
      if (!a.isConnected && b.isConnected) return 1;

      // Then connecting peers.
      if (a.isConnecting && !b.isConnecting) return -1;
      if (!a.isConnecting && b.isConnecting) return 1;

      // Then by lifecycle state (discovered before disconnected).
      final aPriority = _lifecyclePriority(a.lifecycleState);
      final bPriority = _lifecyclePriority(b.lifecycleState);
      if (aPriority != bPriority) return aPriority.compareTo(bPriority);

      // Finally alphabetically by name.
      return a.peer.displayName.compareTo(b.peer.displayName);
    });
    return sorted;
  }

  int _lifecyclePriority(PeerLifecycleState state) {
    // discovered(0) < connecting(1) < connected(2) < disconnecting(3) < disconnected(4) < unknown(5)
    switch (state) {
      case PeerLifecycleState.discovered:
        return 0;
      case PeerLifecycleState.connecting:
        return 1;
      case PeerLifecycleState.connected:
        return 2;
      case PeerLifecycleState.disconnecting:
        return 3;
      case PeerLifecycleState.disconnected:
        return 4;
      case PeerLifecycleState.unknown:
        return 5;
    }
  }
}

// ── Peer Tile ──────────────────────────────────────────────────

class _PeerTile extends ConsumerWidget {
  const _PeerTile({required this.peer, super.key});

  final PeerEntry peer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identityId = peer.identityId;

    return ListTile(
      leading: _PeerAvatar(peer: peer),
      title: Row(
        children: [
          Expanded(
            child: Text(
              peer.peer.displayName,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          _LifecycleBadge(lifecycleState: peer.lifecycleState),
        ],
      ),
      subtitle: _PeerSubtitle(peer: peer),
      onTap: () => context.push('/identity/peers/$identityId'),
    );
  }
}

// ── Peer Avatar ────────────────────────────────────────────────

class _PeerAvatar extends StatelessWidget {
  const _PeerAvatar({required this.peer});

  final PeerEntry peer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Color backgroundColor;
    Color foregroundColor;

    if (peer.trustState == TrustState.revoked) {
      backgroundColor = theme.colorScheme.error.withValues(alpha: 0.15);
      foregroundColor = theme.colorScheme.error;
    } else if (peer.trustState == TrustState.trusted) {
      backgroundColor = theme.colorScheme.primary.withValues(alpha: 0.15);
      foregroundColor = theme.colorScheme.primary;
    } else {
      backgroundColor = theme.colorScheme.surfaceContainerHighest;
      foregroundColor = theme.colorScheme.onSurfaceVariant;
    }

    return CircleAvatar(
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      child: Text(
        peer.peer.displayName.isNotEmpty
            ? peer.peer.displayName[0].toUpperCase()
            : '?',
      ),
    );
  }
}

// ── Peer Subtitle ──────────────────────────────────────────────

class _PeerSubtitle extends StatelessWidget {
  const _PeerSubtitle({required this.peer});

  final PeerEntry peer;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StatusRow(peer: peer),
      ],
    );
  }
}

// ── Status Row ─────────────────────────────────────────────────

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.peer});

  final PeerEntry peer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        // Trust status
        if (peer.trustState != TrustState.unknown)
          _StatusChip(
            label: _trustLabel(peer.trustState),
            color: _trustColor(peer.trustState, theme),
            icon: _trustIcon(peer.trustState),
          ),
        // Verification status
        if (peer.isVerified)
          _StatusChip(
            label: 'Verified',
            color: theme.colorScheme.tertiary,
            icon: Icons.verified_outlined,
          ),
        // Connection status
        if (peer.lifecycleState != PeerLifecycleState.disconnected &&
            peer.lifecycleState != PeerLifecycleState.unknown)
          _StatusChip(
            label: _connectionLabel(peer.lifecycleState),
            color: _connectionColor(peer.lifecycleState, theme),
            icon: _connectionIcon(peer.lifecycleState),
          ),
      ],
    );
  }

  String _trustLabel(TrustState state) {
    switch (state) {
      case TrustState.unknown:
        return '';
      case TrustState.verified:
        return 'Verified';
      case TrustState.trusted:
        return 'Trusted';
      case TrustState.revoked:
        return 'Revoked';
    }
  }

  Color _trustColor(TrustState state, ThemeData theme) {
    switch (state) {
      case TrustState.unknown:
        return theme.colorScheme.onSurfaceVariant;
      case TrustState.verified:
        return theme.colorScheme.tertiary;
      case TrustState.trusted:
        return theme.colorScheme.primary;
      case TrustState.revoked:
        return theme.colorScheme.error;
    }
  }

  IconData _trustIcon(TrustState state) {
    switch (state) {
      case TrustState.unknown:
        return Icons.help_outline;
      case TrustState.verified:
        return Icons.verified_outlined;
      case TrustState.trusted:
        return Icons.shield;
      case TrustState.revoked:
        return Icons.block;
    }
  }

  String _connectionLabel(PeerLifecycleState state) {
    switch (state) {
      case PeerLifecycleState.unknown:
        return '';
      case PeerLifecycleState.discovered:
        return 'Discovered';
      case PeerLifecycleState.connecting:
        return 'Connecting';
      case PeerLifecycleState.connected:
        return 'Connected';
      case PeerLifecycleState.disconnecting:
        return 'Disconnecting';
      case PeerLifecycleState.disconnected:
        return '';
    }
  }

  Color _connectionColor(PeerLifecycleState state, ThemeData theme) {
    switch (state) {
      case PeerLifecycleState.unknown:
        return theme.colorScheme.onSurfaceVariant;
      case PeerLifecycleState.discovered:
        return theme.colorScheme.onSurfaceVariant;
      case PeerLifecycleState.connecting:
        return theme.colorScheme.tertiary;
      case PeerLifecycleState.connected:
        return theme.colorScheme.primary;
      case PeerLifecycleState.disconnecting:
        return theme.colorScheme.onSurfaceVariant;
      case PeerLifecycleState.disconnected:
        return theme.colorScheme.onSurfaceVariant;
    }
  }

  IconData _connectionIcon(PeerLifecycleState state) {
    switch (state) {
      case PeerLifecycleState.unknown:
        return Icons.help_outline;
      case PeerLifecycleState.discovered:
        return Icons.radar;
      case PeerLifecycleState.connecting:
        return Icons.sync;
      case PeerLifecycleState.connected:
        return Icons.link;
      case PeerLifecycleState.disconnecting:
        return Icons.link_off;
      case PeerLifecycleState.disconnected:
        return Icons.link_off;
    }
  }
}

// ── Status Chip ────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

// ── Lifecycle Badge ────────────────────────────────────────────

class _LifecycleBadge extends StatelessWidget {
  const _LifecycleBadge({required this.lifecycleState});

  final PeerLifecycleState lifecycleState;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    String label;
    Color color;
    IconData icon;

    switch (lifecycleState) {
      case PeerLifecycleState.unknown:
        return const SizedBox.shrink();
      case PeerLifecycleState.discovered:
        label = 'Discovered';
        color = theme.colorScheme.onSurfaceVariant;
        icon = Icons.radar;
      case PeerLifecycleState.connecting:
        label = 'Connecting';
        color = theme.colorScheme.tertiary;
        icon = Icons.sync;
      case PeerLifecycleState.connected:
        label = 'Connected';
        color = theme.colorScheme.primary;
        icon = Icons.link;
      case PeerLifecycleState.disconnecting:
        label = 'Disconnecting';
        color = theme.colorScheme.onSurfaceVariant;
        icon = Icons.link_off;
      case PeerLifecycleState.disconnected:
        return const SizedBox.shrink();
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(color: color),
        ),
      ],
    );
  }
}
