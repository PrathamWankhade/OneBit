import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:onebit/core/theme/app_theme.dart';
import 'package:onebit/features/identity/identity_fingerprint.dart' as fp;

/// F6 — Fingerprint display components.
///
/// Compact: inline truncated fingerprint with copy button.
/// Full: multiline grid with copy, share, verify actions.

/// Compact fingerprint display — inline with copy button.
///
/// Shows truncated fingerprint (8 groups) with a copy action.
class FingerprintCompact extends StatelessWidget {
  const FingerprintCompact({
    required this.fingerprint,
    this.onCopy,
    super.key,
  });

  final String fingerprint;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    final compact = fp.fingerprintCompact(fingerprint);
    return Row(
      children: [
        const Icon(Icons.key, size: 14, color: AppTheme.textTertiary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            compact,
            style: AppTheme.technical.copyWith(color: AppTheme.textSecondary),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        GestureDetector(
          onTap: onCopy ?? () => _copyToClipboard(context, fingerprint),
          child: const Icon(
            Icons.copy_rounded,
            size: 14,
            color: AppTheme.textTertiary,
          ),
        ),
      ],
    );
  }
}

/// Full fingerprint display — multiline grid with actions.
///
/// Shows 4 groups per line across 4 lines, with copy/share/verify buttons.
class FingerprintFull extends StatelessWidget {
  const FingerprintFull({
    required this.fingerprint,
    this.onCopy,
    this.onShare,
    this.onVerify,
    super.key,
  });

  final String fingerprint;
  final VoidCallback? onCopy;
  final VoidCallback? onShare;
  final VoidCallback? onVerify;

  @override
  Widget build(BuildContext context) {
    final lines = fp.fingerprintLines(fingerprint).split('\n');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Fingerprint',
          style: AppTheme.labelMedium.copyWith(color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.bgSurface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: lines.map((line) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  line,
                  style: AppTheme.technical.copyWith(
                    color: AppTheme.textPrimary,
                    letterSpacing: 1.2,
                  ),
                  textAlign: TextAlign.center,
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _ActionChip(
              icon: Icons.copy_rounded,
              label: 'Copy',
              onTap: onCopy ?? () => _copyToClipboard(context, fingerprint),
            ),
            const SizedBox(width: 8),
            if (onShare != null)
              _ActionChip(
                icon: Icons.share_rounded,
                label: 'Share',
                onTap: onShare!,
              ),
            if (onShare != null) const SizedBox(width: 8),
            if (onVerify != null)
              _ActionChip(
                icon: Icons.verified_user,
                label: 'Verify',
                onTap: onVerify!,
              ),
          ],
        ),
      ],
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.bgElevated,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppTheme.textSecondary),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppTheme.caption.copyWith(color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet that shows the full fingerprint.
Future<void> showFingerprintSheet(
  BuildContext context, {
  required String fingerprint,
  VoidCallback? onVerify,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: AppTheme.bgElevated,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => Padding(
      padding: const EdgeInsets.all(24),
      child: FingerprintFull(
        fingerprint: fingerprint,
        onVerify: onVerify,
      ),
    ),
  );
}

void _copyToClipboard(BuildContext context, String text) {
  Clipboard.setData(ClipboardData(text: text));
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Fingerprint copied'),
      duration: Duration(seconds: 1),
    ),
  );
}
