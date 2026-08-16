import 'package:flutter/material.dart';
import 'package:onebit/shared/design_system/components/onebit_card.dart';
import 'package:onebit/shared/design_system/components/onebit_status_chip.dart';
import 'package:onebit/shared/design_system/spacing/onebit_spacing.dart';
import 'package:onebit/shared/design_system/themes/onebit_theme_extension.dart';
import 'package:onebit/shared/design_system/typography/onebit_typography.dart';

/// Peer node summary card.
///
/// Presentation-only: every field arrives from the caller as plain data.
/// Node IDs and fingerprints render in the technical (monospace) family.
class OneBitNodeCard extends StatelessWidget {
  const OneBitNodeCard({
    required this.name,
    required this.nodeId,
    this.fingerprint,
    this.verification,
    this.verificationLabel,
    this.connection,
    this.rssi,
    this.lastSeen,
    this.routeInfo,
    this.onTap,
    super.key,
  });

  /// Display name of the node.
  final String name;

  /// Dense node identifier (technical family).
  final String nodeId;

  /// Optional identity fingerprint (technical family).
  final String? fingerprint;

  /// Verification status chip; `null` hides the chip.
  final OneBitStatusPreset? verification;

  /// Overrides the verification chip's label (localized).
  final String? verificationLabel;

  /// Connection status chip; `null` hides the chip.
  final OneBitStatusPreset? connection;

  /// Last observed signal strength in dBm; `null` hides the value.
  final int? rssi;

  /// Preformatted "last seen" text (e.g. "2 min ago"); `null` hides it.
  final String? lastSeen;

  /// Optional route information (e.g. "1 hop"); `null` hides it.
  final String? routeInfo;

  /// Tap action; `null` renders the card non-interactive.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final colors = context.oneBitColors;

    return OneBitCard(
      onTap: onTap,
      semanticLabel: 'Node $name',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Name + connection chip
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: OneBitTypography.semibold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (connection != null) ...[
                const SizedBox(width: OneBitSpacing.s),
                OneBitStatusChip.preset(connection!),
              ],
            ],
          ),
          // Row 2: Node ID
          const SizedBox(height: 4),
          Text(
            nodeId,
            style: OneBitTypography.technicalStyle(
              color: scheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          // Row 3: Fingerprint
          if (fingerprint != null) ...[
            const SizedBox(height: 2),
            Text(
              fingerprint!,
              style: OneBitTypography.technicalStyle(
                fontSize: OneBitTypography.caption,
                color: colors.textMuted,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          // Row 4: Verification + route + signal + last seen
          const SizedBox(height: 8),
          Row(
            children: [
              if (verification != null)
                OneBitStatusChip.preset(verification!, label: verificationLabel)
              else
                const SizedBox.shrink(),
              if (routeInfo != null) ...[
                const SizedBox(width: OneBitSpacing.s),
                Text(
                  routeInfo!,
                  style: textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontFamily: OneBitTypography.technicalFamily,
                    fontFamilyFallback: OneBitTypography.technicalFallback,
                  ),
                ),
              ],
              const Spacer(),
              if (rssi != null)
                Text(
                  '$rssi dBm',
                  style: textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontFamily: OneBitTypography.technicalFamily,
                    fontFamilyFallback: OneBitTypography.technicalFallback,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              if (rssi != null && lastSeen != null)
                const SizedBox(width: OneBitSpacing.s),
              if (lastSeen != null)
                Text(
                  lastSeen!,
                  style: textTheme.labelSmall?.copyWith(
                    color: colors.textMuted,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
