import 'package:flutter/material.dart';
import 'package:onebit/shared/design_system/colors/onebit_color_schemes.dart';
import 'package:onebit/shared/design_system/components/onebit_status_chip.dart';

/// Reusable snackbar emitter.
///
/// All toast-like transient feedback routes through these helpers so the
/// floating inverse-surface snackbar theme stays consistent. Callers localize
/// labels and action labels.
abstract final class OneBitSnackBars {
  const OneBitSnackBars._();

  /// Neutral transient message.
  static void show(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(seconds: 4),
  }) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), duration: duration));
  }

  /// Success variant with a check glyph.
  static void success(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(seconds: 4),
  }) {
    _showVariant(
      context,
      message: message,
      tone: OneBitStatusTone.success,
      duration: duration,
    );
  }

  /// Error variant with the error color; optionally offers a retry action.
  static void error(
    BuildContext context, {
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 6),
  }) {
    _showVariant(
      context,
      message: message,
      tone: OneBitStatusTone.error,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  static void _showVariant(
    BuildContext context, {
    required String message,
    required OneBitStatusTone tone,
    Duration duration = const Duration(seconds: 4),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (tone) {
      OneBitStatusTone.success => context.oneBitColors.success,
      OneBitStatusTone.error => scheme.error,
      _ => scheme.onSurfaceVariant,
    };

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
          duration: duration,
          action: actionLabel == null || onAction == null
              ? null
              : SnackBarAction(label: actionLabel, onPressed: onAction),
        ),
      );
  }
}
