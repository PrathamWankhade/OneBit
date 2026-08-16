import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/core/extensions/build_context_extensions.dart';
import 'package:onebit/core/widgets/onebit_scaffold.dart';
import 'package:onebit/features/identity/presentation/qr_scanner_controller.dart';
import 'package:onebit/features/identity/presentation/qr_scanner_service.dart';
import 'package:onebit/shared/design_system/components/onebit_button.dart';
import 'package:onebit/shared/design_system/components/onebit_error_state.dart';
import 'package:onebit/shared/design_system/components/onebit_scroll_clearance.dart';
import 'package:onebit/shared/design_system/components/onebit_technical_card.dart';
import 'package:onebit/shared/design_system/icons/onebit_icons.dart';
import 'package:onebit/shared/design_system/spacing/onebit_radius.dart';
import 'package:onebit/shared/design_system/spacing/onebit_spacing.dart';
import 'package:onebit/shared/design_system/typography/onebit_typography.dart';

/// Scans another node's identity QR card and adds it as a trust contact.
class QrScannerScreen extends ConsumerWidget {
  const QrScannerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final view = ref.watch(qrScannerControllerProvider);
    final controller = ref.read(qrScannerControllerProvider.notifier);

    return OneBitScaffold(
      appBar: AppBar(
        title: Text(l10n.qrScannerTitle),
        actions: [
          if (view.isScanning || view.isDecoding)
            TextButton(
              onPressed: controller.cancelScan,
              child: Text(l10n.qrScannerCancelScan),
            ),
        ],
      ),
      body: switch (view.phase) {
        QrScannerPhase.idle => _IdleView(onStart: controller.startScanning),
        QrScannerPhase.permissionDenied => _PermissionView(
          onRetry: controller.startScanning,
        ),
        QrScannerPhase.scanning || QrScannerPhase.decoding => _ScanningView(
          onDetect: controller.onDetected,
          decoding: view.isDecoding,
        ),
        QrScannerPhase.success => _SuccessView(view: view),
        QrScannerPhase.invalid => _InvalidView(
          message: '${view.error ?? ''}',
          onScanAgain: controller.scanAgain,
        ),
        QrScannerPhase.cancelled => _CancelledView(
          onScanAgain: controller.scanAgain,
        ),
        QrScannerPhase.error => OneBitErrorState(
          message: l10n.qrScannerErrorTitle,
          detail: '${view.error ?? ''}',
        ),
      },
    );
  }
}

final class _IdleView extends StatelessWidget {
  const _IdleView({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(OneBitSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(OneBitIcons.qrScanner, size: 72, color: scheme.primary),
            const SizedBox(height: OneBitSpacing.l),
            Text(
              l10n.qrScannerFingerprintMatches,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: OneBitSpacing.l),
            OneBitButton(
              label: l10n.qrScannerStart,
              icon: OneBitIcons.camera,
              onPressed: onStart,
            ),
          ],
        ),
      ),
    );
  }
}

final class _PermissionView extends StatelessWidget {
  const _PermissionView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(OneBitSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(OneBitIcons.camera, size: 56, color: scheme.error),
            const SizedBox(height: OneBitSpacing.l),
            Text(
              l10n.qrScannerPermissionTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: OneBitSpacing.s),
            Text(
              l10n.qrScannerPermissionMessage,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: OneBitSpacing.l),
            OneBitButton(
              label: l10n.qrScannerAllow,
              icon: OneBitIcons.camera,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

final class _ScanningView extends ConsumerWidget {
  const _ScanningView({required this.onDetect, required this.decoding});

  final ValueChanged<String> onDetect;
  final bool decoding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final service = ref.read(qrScannerServiceProvider);

    return Stack(
      fit: StackFit.expand,
      children: [
        service.buildPreview(context, onDetect: onDetect),
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).colorScheme.primary,
              width: 3,
            ),
            borderRadius: BorderRadius.circular(OneBitRadius.lg),
          ),
          child: Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(OneBitRadius.lg),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary,
                  width: 3,
                ),
              ),
            ),
          ),
        ),
        if (decoding)
          Container(
            color: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.54),
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: OneBitSpacing.m),
                Text(
                  l10n.qrScannerScanning,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onInverseSurface,
                  ),
                ),
              ],
            ),
          ),
        SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(OneBitSpacing.l),
              child: Text(
                l10n.qrScannerScanning,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onInverseSurface,
                  shadows: [
                    Shadow(
                      color: Theme.of(context).colorScheme.shadow,
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

final class _SuccessView extends ConsumerWidget {
  const _SuccessView({required this.view});

  final QrScannerView view;

  Future<void> _copyFingerprint(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: view.card!.fingerprintHex));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final card = view.card!;
    final scheme = Theme.of(context).colorScheme;
    final controller = ref.read(qrScannerControllerProvider.notifier);

    return ListView(
      padding: EdgeInsets.fromLTRB(
        OneBitSpacing.m,
        OneBitSpacing.m,
        OneBitSpacing.m,
        OneBitScrollClearance.bottom(context),
      ),
      children: [
        Icon(OneBitIcons.verified, size: 64, color: scheme.primary),
        const SizedBox(height: OneBitSpacing.m),
        Text(
          l10n.qrScannerFoundTitle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: OneBitSpacing.xs),
        Text(
          l10n.qrScannerFoundMessage(card.displayName, card.nodeId),
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: OneBitSpacing.l),
        OneBitTechnicalCard(
          title: l10n.qrIdentityFingerprint,
          content: card.fingerprintHex,
          maxLines: 2,
        ),
        const SizedBox(height: OneBitSpacing.s),
        TextButton.icon(
          onPressed: () => _copyFingerprint(context),
          icon: const Icon(OneBitIcons.copy, size: 18),
          label: Text(l10n.qrIdentityCopyFingerprint),
        ),
        const SizedBox(height: OneBitSpacing.m),
        if (view.contactAdded)
          _StatusRow(icon: OneBitIcons.check, text: l10n.qrScannerContactAdded)
        else
          OneBitButton(
            label: l10n.qrScannerAddContact,
            icon: OneBitIcons.verified,
            onPressed: controller.addContact,
          ),
        const SizedBox(height: OneBitSpacing.s),
        OneBitButton(
          label: l10n.qrScannerScanAnother,
          icon: OneBitIcons.qrScanner,
          variant: OneBitButtonVariant.secondary,
          onPressed: controller.scanAgain,
        ),
      ],
    );
  }
}

final class _InvalidView extends StatelessWidget {
  const _InvalidView({required this.message, required this.onScanAgain});

  final String message;
  final VoidCallback onScanAgain;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(OneBitSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(OneBitIcons.warning, size: 56, color: scheme.error),
            const SizedBox(height: OneBitSpacing.l),
            Text(
              l10n.qrScannerInvalidTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: OneBitSpacing.s),
            Text(
              l10n.qrScannerInvalidMessage,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: OneBitSpacing.s),
            Text(
              message,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: OneBitTypography.technicalStyle(
                fontSize: OneBitTypography.caption,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: OneBitSpacing.l),
            OneBitButton(
              label: l10n.qrScannerScanAnother,
              icon: OneBitIcons.qrScanner,
              onPressed: onScanAgain,
            ),
          ],
        ),
      ),
    );
  }
}

final class _CancelledView extends StatelessWidget {
  const _CancelledView({required this.onScanAgain});

  final VoidCallback onScanAgain;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(OneBitSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(OneBitIcons.close, size: 56, color: scheme.onSurfaceVariant),
            const SizedBox(height: OneBitSpacing.l),
            Text(
              l10n.qrScannerCancelled,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: OneBitSpacing.l),
            OneBitButton(
              label: l10n.qrScannerScanAnother,
              icon: OneBitIcons.qrScanner,
              onPressed: onScanAgain,
            ),
          ],
        ),
      ),
    );
  }
}

final class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 18, color: scheme.primary),
        const SizedBox(width: OneBitSpacing.s),
        Text(
          text,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: scheme.primary),
        ),
      ],
    );
  }
}
