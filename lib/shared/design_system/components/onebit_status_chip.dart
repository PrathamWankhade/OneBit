import 'package:flutter/material.dart';
import 'package:onebit/shared/design_system/accessibility/onebit_accessibility.dart';
import 'package:onebit/shared/design_system/spacing/onebit_spacing.dart';
import 'package:onebit/shared/design_system/themes/onebit_theme_extension.dart';
import 'package:onebit/shared/design_system/tokens/onebit_component_tokens.dart';
import 'package:onebit/shared/design_system/typography/onebit_typography.dart';

/// Tones of [OneBitStatusChip].
enum OneBitStatusTone {
  /// Neutral — no state implied.
  neutral,

  /// Positive outcome.
  success,

  /// Caution.
  warning,

  /// Failure.
  error,

  /// Informational.
  info,
}

/// Preset statuses with a fixed [OneBitStatusTone] and default label.
///
/// Presentation-only vocabulary: connection, verification and delivery
/// statuses map to these presets; callers may override the [label] with
/// localized text. No feature enum leaks into the component.
enum OneBitStatusPreset {
  /// Device reachable and communicating.
  online,

  /// Device not reachable.
  offline,

  /// Handshake in progress.
  connecting,

  /// Connection dropped.
  disconnected,

  /// Identity cryptographically verified.
  verified,

  /// Identity not yet verified.
  unverified,

  /// Operation queued or waiting.
  pending,

  /// Operation failed.
  failed,

  /// Operation finished successfully.
  completed,

  /// Node is nearby but not yet trusted.
  nearby;

  /// Default (English) label; callers pass a localized [label] override.
  String get defaultLabel => switch (this) {
    OneBitStatusPreset.online => 'Online',
    OneBitStatusPreset.offline => 'Offline',
    OneBitStatusPreset.connecting => 'Connecting',
    OneBitStatusPreset.disconnected => 'Disconnected',
    OneBitStatusPreset.verified => 'Verified',
    OneBitStatusPreset.unverified => 'Unverified',
    OneBitStatusPreset.pending => 'Pending',
    OneBitStatusPreset.failed => 'Failed',
    OneBitStatusPreset.completed => 'Completed',
    OneBitStatusPreset.nearby => 'Nearby',
  };

  /// The tone each preset renders in.
  OneBitStatusTone get tone => switch (this) {
    OneBitStatusPreset.online ||
    OneBitStatusPreset.verified ||
    OneBitStatusPreset.completed => OneBitStatusTone.success,
    OneBitStatusPreset.connecting ||
    OneBitStatusPreset.pending => OneBitStatusTone.warning,
    OneBitStatusPreset.failed => OneBitStatusTone.error,
    OneBitStatusPreset.nearby => OneBitStatusTone.info,
    OneBitStatusPreset.offline ||
    OneBitStatusPreset.disconnected ||
    OneBitStatusPreset.unverified => OneBitStatusTone.neutral,
  };
}

/// Compact pill for a status (connected, syncing, degraded, …).
///
/// Colors resolve exclusively from the theme: the tone's semantic color for
/// foreground and the matching container tint behind it. The leading dot is
/// decorative and excluded from semantics.
class OneBitStatusChip extends StatelessWidget {
  const OneBitStatusChip({
    required this.label,
    this.tone = OneBitStatusTone.neutral,
    super.key,
  });

  /// Status text.
  final String label;

  /// Semantic tone.
  final OneBitStatusTone tone;

  /// Preset status chip: resolves [tone] and defaults [label] from [preset];
  /// pass a localized [label] override when a custom status name is needed.
  factory OneBitStatusChip.preset(
    OneBitStatusPreset preset, {
    String? label,
    Key? key,
  }) {
    return OneBitStatusChip(
      key: key,
      label: label ?? preset.defaultLabel,
      tone: preset.tone,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.oneBitColors;
    final textTheme = Theme.of(context).textTheme;

    final Color foreground = switch (tone) {
      OneBitStatusTone.neutral => scheme.onSurfaceVariant,
      OneBitStatusTone.success => colors.success,
      OneBitStatusTone.warning => colors.warning,
      OneBitStatusTone.error => scheme.error,
      OneBitStatusTone.info => colors.info,
    };

    final Color background = switch (tone) {
      OneBitStatusTone.neutral => scheme.surfaceContainerHighest,
      OneBitStatusTone.success => colors.successContainer,
      OneBitStatusTone.warning => colors.warningContainer,
      OneBitStatusTone.error => scheme.errorContainer,
      OneBitStatusTone.info => colors.infoContainer,
    };

    return Semantics(
      container: true,
      label: label,
      child: Container(
        constraints: const BoxConstraints(
          minHeight: OneBitStatusTokens.chipHeight,
        ),
        padding: OneBitStatusTokens.chipPadding,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(OneBitShapeTokens.chipRadius),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            OneBitSemantics.decorative(
              Container(
                width: OneBitStatusTokens.dotSize,
                height: OneBitStatusTokens.dotSize,
                decoration: BoxDecoration(
                  color: foreground,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(width: OneBitSpacing.s),
            OneBitSemantics.decorative(
              Text(
                label,
                style: textTheme.labelMedium?.copyWith(
                  color: foreground,
                  fontWeight: OneBitTypography.semibold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
