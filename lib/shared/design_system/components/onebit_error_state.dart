import 'package:flutter/material.dart';
import 'package:onebit/shared/design_system/components/onebit_button.dart';
import 'package:onebit/shared/design_system/icons/onebit_icons.dart';
import 'package:onebit/shared/design_system/spacing/onebit_spacing.dart';
import 'package:onebit/shared/design_system/tokens/onebit_component_tokens.dart';

/// Standard failure presentation.
///
/// Shows the failure's message with an optional technical detail and a
/// retry action. Never throws when given a malformed failure — it always
/// renders.
class OneBitErrorState extends StatelessWidget {
  const OneBitErrorState({
    required this.message,
    this.onRetry,
    this.detail,
    this.retryLabel = 'Retry',
    super.key,
  });

  /// Primary message shown to the user.
  final String message;

  /// Optional supporting detail (failure code, technical hint).
  final String? detail;

  /// Retry action; `null` hides the retry button.
  final VoidCallback? onRetry;

  /// Label for the retry action; screens localize this string.
  final String retryLabel;

  factory OneBitErrorState.fromFailure({
    required Object failure,
    VoidCallback? onRetry,
    String retryLabel = 'Retry',
  }) {
    return OneBitErrorState(
      message: failure.toString(),
      detail: failure.runtimeType.toString(),
      onRetry: onRetry,
      retryLabel: retryLabel,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      label: message,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(OneBitSpacing.xxxxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: Icon(
                  OneBitIcons.error,
                  size: OneBitIconSize.feature,
                  color: scheme.error,
                ),
              ),
              const SizedBox(height: OneBitSpacing.l),
              Text(
                message,
                textAlign: TextAlign.center,
                style: textTheme.titleLarge,
              ),
              if (detail != null) ...[
                const SizedBox(height: OneBitSpacing.s),
                Text(
                  detail!,
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium,
                ),
              ],
              if (onRetry != null) ...[
                const SizedBox(height: OneBitSpacing.xl),
                OneBitOutlinedButton(
                  label: retryLabel,
                  icon: OneBitIcons.retry,
                  onPressed: onRetry,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
