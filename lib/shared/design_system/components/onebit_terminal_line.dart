import 'package:flutter/material.dart';
import 'package:onebit/shared/design_system/colors/onebit_color_schemes.dart';
import 'package:onebit/shared/design_system/spacing/onebit_spacing.dart';
import 'package:onebit/shared/design_system/typography/onebit_typography.dart';

/// Semantic status types for [OneBitTerminalLine].
enum OneBitTerminalStatus {
  /// Success / OK.
  ok,

  /// Informational.
  info,

  /// Warning.
  warn,

  /// Error.
  err,

  /// Node reference.
  node,

  /// Transfer sent.
  tx,

  /// Transfer received.
  rx,

  /// Custom prefix (caller provides [prefix]).
  custom,
}

/// Single-line terminal-style status line with a bracketed prefix.
///
/// Renders: `[PREFIX] message`
///
/// Examples:
/// ```dart
/// OneBitTerminalLine(status: OneBitTerminalStatus.ok, message: 'NODE VERIFIED')
/// OneBitTerminalLine(status: OneBitTerminalStatus.info, message: 'SEARCHING FOR NODES')
/// OneBitTerminalLine(status: OneBitTerminalStatus.warn, message: 'MESH OFFLINE')
/// OneBitTerminalLine(status: OneBitTerminalStatus.err, message: 'TRANSFER FAILED')
/// OneBitTerminalLine(status: OneBitTerminalStatus.node, message: '7F4A...9C21')
/// OneBitTerminalLine(status: OneBitTerminalStatus.tx, message: '4.2 KB')
/// OneBitTerminalLine(status: OneBitTerminalStatus.rx, message: '2.1 KB')
/// ```
class OneBitTerminalLine extends StatelessWidget {
  const OneBitTerminalLine({
    required this.message,
    this.status = OneBitTerminalStatus.info,
    this.prefix,
    this.style,
    this.semanticsLabel,
    super.key,
  });

  /// The message text after the prefix.
  final String message;

  /// Semantic status type that determines the prefix and color.
  final OneBitTerminalStatus status;

  /// Custom prefix text; only used when [status] is [OneBitTerminalStatus.custom].
  final String? prefix;

  /// Optional text style override; defaults to [OneBitTypography.technicalStyle].
  final TextStyle? style;

  /// Optional semantic label for accessibility; defaults to the full line text.
  final String? semanticsLabel;

  String get _prefix => switch (status) {
    OneBitTerminalStatus.ok => 'OK',
    OneBitTerminalStatus.info => 'INFO',
    OneBitTerminalStatus.warn => 'WARN',
    OneBitTerminalStatus.err => 'ERR',
    OneBitTerminalStatus.node => 'NODE',
    OneBitTerminalStatus.tx => 'TX',
    OneBitTerminalStatus.rx => 'RX',
    OneBitTerminalStatus.custom => prefix ?? '',
  };

  Color _color(BuildContext context) {
    final colors = context.oneBitColors;
    return switch (status) {
      OneBitTerminalStatus.ok => colors.success,
      OneBitTerminalStatus.info => colors.info,
      OneBitTerminalStatus.warn => colors.warning,
      OneBitTerminalStatus.err => colors.ansiBrightRed,
      OneBitTerminalStatus.node => colors.identity,
      OneBitTerminalStatus.tx => colors.ansiBrightGreen,
      OneBitTerminalStatus.rx => colors.ansiBrightCyan,
      OneBitTerminalStatus.custom => colors.textSecondary,
    };
  }

  @override
  Widget build(BuildContext context) {
    final color = _color(context);
    final baseStyle = style ?? OneBitTypography.technicalStyle();

    return Semantics(
      label: semanticsLabel ?? '$_prefix $message',
      child: Row(
        children: [
          Text(
            '[$_prefix]',
            style: baseStyle.copyWith(
              color: color,
              fontWeight: OneBitTypography.semibold,
            ),
          ),
          const SizedBox(width: OneBitSpacing.s),
          Expanded(
            child: Text(
              message,
              style: baseStyle.copyWith(color: color),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
