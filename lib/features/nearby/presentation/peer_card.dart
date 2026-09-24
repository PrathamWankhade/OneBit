import 'package:flutter/material.dart';
import 'package:onebit/core/theme/app_theme.dart';

/// F5 Signal strength indicator — 3 bars, color-coded by RSSI.
///
/// Strong: green, 3 filled. Good: green, 2 filled.
/// Fair: amber, 1 filled. Weak: amber, 1 dim. None: 0 filled.
class SignalBars extends StatelessWidget {
  const SignalBars({required this.rssi, super.key});

  final int rssi;

  @override
  Widget build(BuildContext context) {
    final level = _signalLevel(rssi);
    final color = level >= 3
        ? AppTheme.green
        : level >= 1
            ? AppTheme.amber
            : AppTheme.textTertiary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _bar(0, level, color),
        const SizedBox(width: 2),
        _bar(1, level, color),
        const SizedBox(width: 2),
        _bar(2, level, color),
      ],
    );
  }

  Widget _bar(int index, int level, Color color) {
    final filled = index < level;
    return Container(
      width: 4,
      height: 8.0 + (index * 3),
      decoration: BoxDecoration(
        color: filled ? color : color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }

  /// Returns 0–3 bars based on RSSI.
  static int _signalLevel(int rssi) {
    if (rssi >= -50) return 3;
    if (rssi >= -65) return 3;
    if (rssi >= -80) return 2;
    if (rssi >= -90) return 1;
    return 0;
  }

  static String signalLabel(int rssi) {
    if (rssi >= -50) return 'Strong';
    if (rssi >= -65) return 'Strong';
    if (rssi >= -80) return 'Fair';
    if (rssi >= -90) return 'Weak';
    return 'None';
  }
}

/// F5 Peer card — 72px height, avatar, name, status, signal bars.
class PeerCard extends StatelessWidget {
  const PeerCard({
    required this.name,
    required this.initials,
    required this.rssi,
    required this.isVerified,
    required this.isConnected,
    required this.lastSeen,
    this.onTap,
    this.onLongPress,
    super.key,
  });

  final String name;
  final String initials;
  final int rssi;
  final bool isVerified;
  final bool isConnected;
  final String lastSeen;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isConnected ? AppTheme.accent.withValues(alpha: 0.12) : AppTheme.bgElevated,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isConnected
                      ? AppTheme.accent
                      : isVerified
                          ? AppTheme.green
                          : AppTheme.borderSubtle,
                  width: isConnected || isVerified ? 2 : 1,
                ),
              ),
              child: Center(
                child: Text(
                  initials,
                  style: AppTheme.titleLarge.copyWith(
                    color: isConnected ? AppTheme.accent : AppTheme.textSecondary,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Name + status
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          style: AppTheme.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isVerified) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.verified,
                          size: 14,
                          color: AppTheme.green,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.lock_outline,
                        size: 10,
                        color: AppTheme.trust.withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        lastSeen,
                        style: AppTheme.caption.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Signal bars
            SignalBars(rssi: rssi),
          ],
        ),
      ),
    );
  }
}
