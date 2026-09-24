import 'package:flutter/material.dart';
import 'package:onebit/core/theme/app_theme.dart';

/// F10 — Reusable dialog components.
///
/// Confirmation, destructive, security warning, and identity verification dialogs.
/// Standard: 312px width (or 80%), bg-elevated, 16px radius, 24px padding.

/// Show a confirmation dialog.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String body,
  String confirmLabel = 'Confirm',
  bool isDestructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierColor: AppTheme.overlayDark,
    builder: (_) => _AppDialog(
      title: title,
      body: body,
      cancelLabel: 'Cancel',
      confirmLabel: confirmLabel,
      isDestructive: isDestructive,
    ),
  );
  return result ?? false;
}

/// Show a security warning dialog.
Future<bool> showSecurityWarningDialog(
  BuildContext context, {
  required String peerName,
  required String reason,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierColor: AppTheme.overlayDark,
    builder: (_) => _SecurityWarningDialog(
      peerName: peerName,
      reason: reason,
    ),
  );
  return result ?? false;
}

/// Show an identity verification dialog with fingerprint.
Future<bool> showVerificationDialog(
  BuildContext context, {
  required String peerName,
  required String fingerprint,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierColor: AppTheme.overlayDark,
    builder: (_) => _VerificationDialog(
      peerName: peerName,
      fingerprint: fingerprint,
    ),
  );
  return result ?? false;
}

/// Show a destructive confirmation dialog.
Future<bool> showDestructiveDialog(
  BuildContext context, {
  required String title,
  required String body,
  String confirmLabel = 'Delete',
}) async {
  return showConfirmDialog(
    context,
    title: title,
    body: body,
    confirmLabel: confirmLabel,
    isDestructive: true,
  );
}

// ── Internal dialog widgets ─────────────────────────────────────

class _AppDialog extends StatelessWidget {
  const _AppDialog({
    required this.title,
    required this.body,
    required this.cancelLabel,
    required this.confirmLabel,
    required this.isDestructive,
  });

  final String title;
  final String body;
  final String cancelLabel;
  final String confirmLabel;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.bgElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.borderSubtle, width: 1),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 312),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title
              Text(
                title,
                style: AppTheme.titleLarge.copyWith(
                  color: AppTheme.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              // Body
              Text(
                body,
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(
                      cancelLabel,
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text(
                      confirmLabel,
                      style: AppTheme.bodyMedium.copyWith(
                        color: isDestructive ? AppTheme.red : AppTheme.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SecurityWarningDialog extends StatelessWidget {
  const _SecurityWarningDialog({
    required this.peerName,
    required this.reason,
  });

  final String peerName;
  final String reason;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.bgElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.borderSubtle, width: 1),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 312),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Warning icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.amber.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_amber,
                  color: AppTheme.amber,
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Text(
                'Identity changed',
                style: AppTheme.titleLarge.copyWith(
                  color: AppTheme.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              // Body
              Text(
                "$peerName's identity has changed since you last verified it.",
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                reason,
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.textTertiary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(
                      'Ignore',
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text(
                      'Verify identity',
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VerificationDialog extends StatelessWidget {
  const _VerificationDialog({
    required this.peerName,
    required this.fingerprint,
  });

  final String peerName;
  final String fingerprint;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.bgElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.borderSubtle, width: 1),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 312),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title
              Text(
                "Verify $peerName's identity?",
                style: AppTheme.titleLarge.copyWith(
                  color: AppTheme.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              // Body
              Text(
                'Compare the fingerprint shown with $peerName\'s device.',
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Fingerprint display
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.bgSurface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  fingerprint,
                  style: AppTheme.technical.copyWith(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    letterSpacing: 1.2,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(
                      'Cancel',
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text(
                      'Verify',
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
