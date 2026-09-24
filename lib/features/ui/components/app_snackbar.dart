import 'package:flutter/material.dart';
import 'package:onebit/core/theme/app_theme.dart';

/// F10 — Reusable snackbar component.
///
/// Standard: 48px height, bg-elevated, 8px radius, 16px margin.
/// Variants: info, success, warning, error with appropriate icon/color.

enum SnackbarType { info, success, warning, error }

/// Show an app snackbar.
void showAppSnackbar(
  BuildContext context, {
  required String message,
  SnackbarType type = SnackbarType.info,
  Duration duration = const Duration(seconds: 3),
  String? actionLabel,
  VoidCallback? onAction,
}) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: _AppSnackbarContent(
        message: message,
        type: type,
      ),
      duration: duration,
      backgroundColor: AppTheme.bgElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      margin: const EdgeInsets.all(16),
      behavior: SnackBarBehavior.floating,
      action: actionLabel != null
          ? SnackBarAction(
              label: actionLabel,
              textColor: AppTheme.accent,
              onPressed: onAction ?? () {},
            )
          : null,
    ),
  );
}

/// Show a copy-to-clipboard snackbar.
void showCopySnackbar(BuildContext context) {
  showAppSnackbar(
    context,
    message: 'Copied to clipboard',
    type: SnackbarType.success,
  );
}

/// Show a save success snackbar.
void showSaveSnackbar(BuildContext context) {
  showAppSnackbar(
    context,
    message: 'Saved to device',
    type: SnackbarType.success,
  );
}

/// Show a send success snackbar.
void showSendSnackbar(BuildContext context) {
  showAppSnackbar(
    context,
    message: 'Message sent',
    type: SnackbarType.success,
    duration: const Duration(seconds: 2),
  );
}

/// Show a failure snackbar.
void showFailureSnackbar(BuildContext context, {String? detail}) {
  showAppSnackbar(
    context,
    message: detail ?? 'Failed to send',
    type: SnackbarType.error,
  );
}

/// Show a verification success snackbar.
void showVerifySnackbar(BuildContext context) {
  showAppSnackbar(
    context,
    message: 'Identity verified',
    type: SnackbarType.success,
  );
}

/// Show a block success snackbar.
void showBlockSnackbar(BuildContext context) {
  showAppSnackbar(
    context,
    message: 'Peer blocked',
    type: SnackbarType.warning,
  );
}

/// Show a delete success snackbar.
void showDeleteSnackbar(BuildContext context) {
  showAppSnackbar(
    context,
    message: 'Message deleted',
    type: SnackbarType.info,
  );
}

/// Show a connection restored snackbar.
void showRestoreSnackbar(BuildContext context) {
  showAppSnackbar(
    context,
    message: 'Connection restored',
    type: SnackbarType.success,
  );
}

// ── Internal widget ─────────────────────────────────────────────

class _AppSnackbarContent extends StatelessWidget {
  const _AppSnackbarContent({
    required this.message,
    required this.type,
  });

  final String message;
  final SnackbarType type;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          _iconForType(type),
          size: 20,
          color: _colorForType(type),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            message,
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  IconData _iconForType(SnackbarType type) {
    switch (type) {
      case SnackbarType.info:
        return Icons.info_outline;
      case SnackbarType.success:
        return Icons.check_circle_outline;
      case SnackbarType.warning:
        return Icons.warning_amber_outlined;
      case SnackbarType.error:
        return Icons.error_outline;
    }
  }

  Color _colorForType(SnackbarType type) {
    switch (type) {
      case SnackbarType.info:
        return AppTheme.textSecondary;
      case SnackbarType.success:
        return AppTheme.green;
      case SnackbarType.warning:
        return AppTheme.amber;
      case SnackbarType.error:
        return AppTheme.red;
    }
  }
}
