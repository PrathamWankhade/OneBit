import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:onebit/core/theme/app_theme.dart';
import 'package:onebit/features/identity/identity_fingerprint.dart' as fp;
import 'package:onebit/features/identity/identity_providers.dart';
import 'package:onebit/features/identity/presentation/verification_indicator.dart';
import 'package:onebit/features/peer_registry/peer_registry_providers.dart';
import 'package:onebit/features/ui/components/one_bit_components.dart';

/// F7 — My Profile screen (Identity tab).
///
/// Compact header, identity card, trust states, security info, real peer stats.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identityAsync = ref.watch(localIdentityProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgBase,
      appBar: AppBar(
        backgroundColor: AppTheme.bgBase,
        title: Text(
          'Profile',
          style: AppTheme.titleLarge.copyWith(color: AppTheme.textPrimary),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.go('/home'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 22, color: AppTheme.accent),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: identityAsync.when(
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
        data: (identity) {
          if (identity == null) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.warning_amber, size: 48, color: AppTheme.amber),
                  SizedBox(height: 16),
                  Text('No identity found', style: AppTheme.bodyLarge),
                  SizedBox(height: 8),
                  Text(
                    'Complete onboarding to create your identity.',
                    style: AppTheme.bodySmall,
                  ),
                ],
              ),
            );
          }
          return _IdentityBody(identity: identity);
        },
      ),
    );
  }
}

class _IdentityBody extends ConsumerStatefulWidget {
  const _IdentityBody({required this.identity});

  final dynamic identity;

  @override
  ConsumerState<_IdentityBody> createState() => _IdentityBodyState();
}

class _IdentityBodyState extends ConsumerState<_IdentityBody> {
  late final Future<String?> _fingerprintFuture;

  @override
  void initState() {
    super.initState();
    _fingerprintFuture = widget.identity.publicKeyBytes != null
        ? fp.computeFingerprint(widget.identity.publicKeyBytes!)
        : Future<String?>.value(null);
  }

  @override
  Widget build(BuildContext context) {
    final identity = widget.identity;
    final peersAsync = ref.watch(peerEntriesProvider);
    final peerCount = peersAsync.whenOrNull(data: (peers) => peers.length) ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          _buildHeader(identity),
          const SizedBox(height: AppTheme.space24),
          _buildQuickActions(context),
          const SizedBox(height: AppTheme.space24),
          _buildIdentityCard(context, identity),
          const SizedBox(height: AppTheme.space16),
          if (identity.about != null && identity.about!.isNotEmpty) ...[
            _buildAboutSection(identity),
            const SizedBox(height: AppTheme.space16),
          ],
          _buildSecuritySection(),
          const SizedBox(height: AppTheme.space16),
          _buildNetworkStats(peerCount),
          const SizedBox(height: AppTheme.space32),
        ],
      ),
    );
  }

  // -- Header --

  Widget _buildHeader(dynamic identity) {
    return Column(
      children: [
        VerificationAvatar(
          status: VerificationDisplayStatus.verified,
          size: 72,
          child: Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: AppTheme.bgElevated,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              identity.displayName.isNotEmpty
                  ? identity.displayName[0].toUpperCase()
                  : '?',
              style: AppTheme.headlineMedium.copyWith(color: AppTheme.accent),
            ),
          ),
        ),
        const SizedBox(height: AppTheme.space12),
        Text(
          identity.displayName,
          style: AppTheme.headlineMedium.copyWith(color: AppTheme.brightWhite),
        ),
        const SizedBox(height: AppTheme.space4),
        if (identity.identityId != null)
          Text(
            _formatShortId(identity.identityId!),
            style: AppTheme.technicalSmall.copyWith(color: AppTheme.textTertiary),
          ),
        const SizedBox(height: AppTheme.space8),
        const OneBitIdentityBadge(
          label: 'Verified',
          color: AppTheme.trust,
          icon: Icons.verified,
        ),
      ],
    );
  }

  // -- Quick Actions --

  Widget _buildQuickActions(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _ProfileActionChip(
          icon: Icons.edit_outlined,
          label: 'Edit',
          onTap: () => context.push('/identity/edit'),
        ),
        const SizedBox(width: AppTheme.space12),
        _ProfileActionChip(
          icon: Icons.qr_code,
          label: 'QR Code',
          onTap: () => context.push('/identity/qr'),
          color: AppTheme.biometric,
        ),
        const SizedBox(width: AppTheme.space12),
        _ProfileActionChip(
          icon: Icons.share_outlined,
          label: 'Share',
          onTap: () {},
        ),
      ],
    );
  }

  // -- Identity Card --

  Widget _buildIdentityCard(BuildContext context, dynamic identity) {
    return OneBitCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const OneBitSectionHeader(label: 'Identity'),
          const SizedBox(height: AppTheme.space8),
          _IdRow(
            label: 'OneBit ID',
            id: identity.identityId ?? '',
            onCopy: () => _copyToClipboard(
              context,
              identity.identityId ?? '',
              'Identity ID copied',
            ),
          ),
          const SizedBox(height: AppTheme.space12),
          FutureBuilder<String?>(
            future: _fingerprintFuture,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const SizedBox(
                  height: 32,
                  child: Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: AppTheme.accent,
                      ),
                    ),
                  ),
                );
              }
              return _IdRow(
                label: 'Fingerprint',
                id: snapshot.data!,
                onCopy: () => _copyToClipboard(
                  context,
                  snapshot.data!,
                  'Fingerprint copied',
                ),
                isFingerprint: true,
              );
            },
          ),
          const SizedBox(height: AppTheme.space12),
          _ProfileInfoRow(
            icon: Icons.calendar_today,
            iconColor: AppTheme.textTertiary,
            text: 'Created ${_formatDate(identity.createdAt)}',
          ),
        ],
      ),
    );
  }

  // -- About --

  Widget _buildAboutSection(dynamic identity) {
    return OneBitCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const OneBitSectionHeader(label: 'About'),
          const SizedBox(height: AppTheme.space8),
          Text(
            identity.about!,
            style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  // -- Security --

  Widget _buildSecuritySection() {
    return const OneBitCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OneBitSectionHeader(label: 'Security'),
          SizedBox(height: AppTheme.space8),
          _ProfileInfoRow(
            icon: Icons.lock,
            iconColor: AppTheme.trust,
            text: 'End-to-end encryption active',
          ),
          SizedBox(height: AppTheme.space8),
          _ProfileInfoRow(
            icon: Icons.key,
            iconColor: AppTheme.accent,
            text: 'Ed25519 + X25519 key pair',
          ),
          SizedBox(height: AppTheme.space8),
          _ProfileInfoRow(
            icon: Icons.phone_android,
            iconColor: AppTheme.textTertiary,
            text: 'Keys stored in secure enclave',
          ),
        ],
      ),
    );
  }

  // -- Network Stats --

  Widget _buildNetworkStats(int peerCount) {
    return OneBitCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const OneBitSectionHeader(label: 'Network'),
          const SizedBox(height: AppTheme.space8),
          Row(
            children: [
              const Icon(Icons.people_outline, size: 16, color: AppTheme.textTertiary),
              const SizedBox(width: AppTheme.space8),
              Text(
                '$peerCount peer${peerCount == 1 ? '' : 's'} discovered',
                style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // -- Helpers --

  String _formatShortId(String id) {
    if (id.length <= 16) return id;
    return '${id.substring(0, 8)}...${id.substring(id.length - 8)}';
  }

  String _formatDate(DateTime date) {
    final months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month]} ${date.day}, ${date.year}';
  }

  void _copyToClipboard(BuildContext context, String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 1),
      ),
    );
  }
}

// -- Helper Widgets --

class _ProfileActionChip extends StatelessWidget {
  const _ProfileActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? AppTheme.textSecondary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.bgElevated,
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
          border: Border.all(color: AppTheme.borderSubtle, width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: chipColor),
            const SizedBox(width: AppTheme.space6),
            Text(
              label,
              style: AppTheme.labelMedium.copyWith(color: chipColor),
            ),
          ],
        ),
      ),
    );
  }
}

class _IdRow extends StatelessWidget {
  const _IdRow({
    required this.label,
    required this.id,
    required this.onCopy,
    this.isFingerprint = false,
  });

  final String label;
  final String id;
  final VoidCallback onCopy;
  final bool isFingerprint;

  @override
  Widget build(BuildContext context) {
    final displayText = isFingerprint ? _formatFingerprint(id) : _formatId(id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTheme.caption.copyWith(color: AppTheme.textTertiary),
        ),
        const SizedBox(height: AppTheme.space4),
        GestureDetector(
          onTap: onCopy,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  displayText,
                  style: (isFingerprint ? AppTheme.technicalSmall : AppTheme.technical)
                      .copyWith(color: AppTheme.textPrimary),
                ),
              ),
              const SizedBox(width: AppTheme.space8),
              const Icon(
                Icons.copy_rounded,
                size: 14,
                color: AppTheme.textTertiary,
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatId(String id) {
    if (id.length <= 16) return id;
    final buffer = StringBuffer();
    for (var i = 0; i < id.length && i < 16; i += 4) {
      if (buffer.isNotEmpty) buffer.write(':');
      buffer.write(id.substring(i, i + 4));
    }
    return '$buffer...';
  }

  String _formatFingerprint(String fp) {
    final clean = fp.replaceAll(' ', '');
    final buffer = StringBuffer();
    for (var i = 0; i < clean.length && i < 24; i += 4) {
      if (buffer.isNotEmpty) buffer.write(' ');
      buffer.write(clean.substring(i, i + 4));
    }
    return '$buffer...';
  }
}

class _ProfileInfoRow extends StatelessWidget {
  const _ProfileInfoRow({
    required this.icon,
    required this.iconColor,
    required this.text,
  });

  final IconData icon;
  final Color iconColor;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: AppTheme.space8),
        Expanded(
          child: Text(
            text,
            style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
          ),
        ),
      ],
    );
  }
}
