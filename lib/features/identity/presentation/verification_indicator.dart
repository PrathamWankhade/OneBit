import 'package:flutter/material.dart';
import 'package:onebit/core/theme/app_theme.dart';

/// F7 — Verification indicator components.
///
/// Inline badge: shield icon + text label for verification status.
/// Avatar ring: colored border around avatar based on verification state.

/// Verification status for display purposes.
enum VerificationDisplayStatus {
  unverified,
  verified,
  pending,
  changed,
  blocked,
}

/// Inline verification badge — shield icon + status text.
///
/// Compact badge for use in lists, cards, and profiles.
class VerificationBadge extends StatelessWidget {
  const VerificationBadge({
    required this.status,
    this.text,
    super.key,
  });

  final VerificationDisplayStatus status;
  final String? text;

  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = _resolveStyle();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          text ?? label,
          style: AppTheme.caption.copyWith(color: color),
        ),
      ],
    );
  }

  (IconData, Color, String) _resolveStyle() {
    switch (status) {
      case VerificationDisplayStatus.verified:
        return (Icons.verified, AppTheme.green, 'Verified');
      case VerificationDisplayStatus.pending:
        return (Icons.shield_outlined, AppTheme.amber, 'Pending');
      case VerificationDisplayStatus.changed:
        return (Icons.shield, AppTheme.amber, 'Identity changed');
      case VerificationDisplayStatus.blocked:
        return (Icons.block, AppTheme.red, 'Blocked');
      case VerificationDisplayStatus.unverified:
        return (Icons.shield_outlined, AppTheme.textTertiary, '');
    }
  }
}

/// Avatar with verification ring.
///
/// Wraps a child widget (typically an avatar) with a colored border
/// based on the verification state.
class VerificationAvatar extends StatelessWidget {
  const VerificationAvatar({
    required this.child,
    this.status = VerificationDisplayStatus.unverified,
    this.size = 80,
    super.key,
  });

  final Widget child;
  final VerificationDisplayStatus status;
  final double size;

  @override
  Widget build(BuildContext context) {
    final borderColor = _resolveBorderColor();
    final borderWidth = borderColor != null ? 2.0 : 0.0;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: borderColor != null
            ? Border.all(color: borderColor, width: borderWidth)
            : null,
      ),
      child: ClipOval(child: child),
    );
  }

  Color? _resolveBorderColor() {
    switch (status) {
      case VerificationDisplayStatus.verified:
        return AppTheme.green;
      case VerificationDisplayStatus.pending:
        return AppTheme.amber;
      case VerificationDisplayStatus.changed:
        return AppTheme.amber;
      case VerificationDisplayStatus.blocked:
        return AppTheme.red;
      case VerificationDisplayStatus.unverified:
        return null;
    }
  }
}

/// Avatar with connection status dot.
///
/// Shows a small colored dot at the bottom-right of the avatar
/// indicating online/offline status.
class ConnectionDot extends StatelessWidget {
  const ConnectionDot({
    required this.child,
    this.isConnected = false,
    this.size = 80,
    super.key,
  });

  final Widget child;
  final bool isConnected;
  final double size;

  @override
  Widget build(BuildContext context) {
    final dotSize = size * 0.2;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          ClipOval(child: child),
          if (isConnected)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: dotSize,
                height: dotSize,
                decoration: BoxDecoration(
                  color: AppTheme.green,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.bgBase,
                    width: 2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
