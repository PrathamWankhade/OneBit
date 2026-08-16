import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/core/extensions/build_context_extensions.dart';
import 'package:onebit/core/widgets/onebit_qr_code.dart';
import 'package:onebit/core/widgets/onebit_scaffold.dart';
import 'package:onebit/features/identity/domain/node_identity.dart';
import 'package:onebit/features/identity/presentation/qr_identity_controller.dart';
import 'package:onebit/shared/design_system/components/onebit_button.dart';
import 'package:onebit/shared/design_system/components/onebit_error_state.dart';
import 'package:onebit/shared/design_system/components/onebit_loading_indicator.dart';
import 'package:onebit/shared/design_system/components/onebit_scroll_clearance.dart';
import 'package:onebit/shared/design_system/components/onebit_status_chip.dart';
import 'package:onebit/shared/design_system/components/onebit_technical_card.dart';
import 'package:onebit/shared/design_system/icons/onebit_icons.dart';
import 'package:onebit/shared/design_system/spacing/onebit_radius.dart';
import 'package:onebit/shared/design_system/spacing/onebit_spacing.dart';
import 'package:onebit/shared/design_system/themes/onebit_theme_extension.dart';
import 'package:onebit/shared/design_system/typography/onebit_typography.dart';

/// This node's identity QR card: a signed pattern another node can scan to
/// trust this identity.
class QrIdentityScreen extends ConsumerWidget {
  const QrIdentityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final view = ref.watch(qrIdentityControllerProvider);

    return OneBitScaffold(
      appBar: AppBar(title: Text(l10n.qrIdentityTitle)),
      body: switch (view) {
        AsyncData(:final value) => _IdentityCard(value: value),
        AsyncError(:final error) => OneBitErrorState(
          message: l10n.qrIdentityBuildError,
          detail: '$error',
        ),
        _ => const OneBitLoadingIndicator(),
      },
    );
  }
}

final class _IdentityCard extends ConsumerWidget {
  const _IdentityCard({required this.value});

  final QrIdentityView value;

  Future<void> _copyFingerprint(BuildContext context) async {
    await Clipboard.setData(
      ClipboardData(text: value.identity.fingerprint.hex),
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.qrIdentityFingerprintCopied)),
    );
  }

  Future<void> _share(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: value.cardText));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.qrIdentityShareCopied)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final identity = value.identity;
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final colors = context.oneBitColors;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        OneBitSpacing.m,
        OneBitSpacing.m,
        OneBitSpacing.m,
        OneBitScrollClearance.bottom(context),
      ),
      children: [
        Center(
          child: Column(
            children: [
              _QrTile(
                cardText: value.cardText,
                label: l10n.qrIdentityCardTitle,
              ),
              const SizedBox(height: OneBitSpacing.m),
              Text(
                identity.profile.displayName,
                style: textTheme.titleLarge?.copyWith(color: colors.identity),
              ),
              const SizedBox(height: OneBitSpacing.xs),
              OneBitStatusChip.preset(
                OneBitStatusPreset.verified,
                label: l10n.qrIdentityVerified,
              ),
              const SizedBox(height: OneBitSpacing.s),
              Text(
                l10n.qrIdentityScanHint,
                textAlign: TextAlign.center,
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: OneBitSpacing.l),
        OneBitTechnicalCard(
          title: l10n.qrIdentityNodeId,
          content: identity.nodeId.value,
          maxLines: 2,
        ),
        const SizedBox(height: OneBitSpacing.m),
        _FingerprintRow(
          identity: identity,
          onCopy: () => _copyFingerprint(context),
        ),
        const SizedBox(height: OneBitSpacing.m),
        OneBitTechnicalCard(
          title: l10n.qrIdentityCreated,
          content: '${identity.createdAt.toLocal()}',
          maxLines: 2,
        ),
        const SizedBox(height: OneBitSpacing.l),
        OneBitButton(
          label: l10n.qrIdentityShare,
          icon: OneBitIcons.share,
          variant: OneBitButtonVariant.secondary,
          onPressed: () => _share(context),
        ),
        const SizedBox(height: OneBitSpacing.s),
        OneBitButton(
          label: l10n.qrIdentityCopyFingerprint,
          icon: OneBitIcons.fingerprint,
          variant: OneBitButtonVariant.text,
          onPressed: () => _copyFingerprint(context),
        ),
      ],
    );
  }
}

final class _QrTile extends StatelessWidget {
  const _QrTile({required this.cardText, required this.label});

  final String cardText;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(OneBitSpacing.m),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(OneBitRadius.lg),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            width: 220,
            height: 220,
            child: OneBitQrCode(data: cardText, semanticsLabel: label),
          ),
          const SizedBox(height: OneBitSpacing.m),
          Text(
            label,
            style: OneBitTypography.technicalStyle(
              fontSize: OneBitTypography.caption,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

final class _FingerprintRow extends StatelessWidget {
  const _FingerprintRow({required this.identity, required this.onCopy});

  final NodeIdentity identity;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final colors = context.oneBitColors;

    return Container(
      padding: const EdgeInsets.all(OneBitSpacing.m),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(OneBitRadius.md),
      ),
      child: Row(
        children: [
          Icon(OneBitIcons.fingerprint, size: 20, color: colors.identity),
          const SizedBox(width: OneBitSpacing.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.qrIdentityFingerprint,
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(color: colors.identity),
                ),
                const SizedBox(height: OneBitSpacing.xs),
                SelectableText(
                  identity.fingerprint.formatted,
                  style: OneBitTypography.technicalStyle(
                    fontSize: OneBitTypography.caption,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onCopy,
            tooltip: l10n.qrIdentityCopyFingerprint,
            icon: Icon(OneBitIcons.copy, size: 20, color: colors.identity),
          ),
        ],
      ),
    );
  }
}
