import 'package:flutter/material.dart';
import 'package:onebit/shared/design_system/icons/onebit_icons.dart';
import 'package:onebit/shared/design_system/spacing/onebit_spacing.dart';
import 'package:onebit/shared/design_system/tokens/onebit_component_tokens.dart';

/// Standard offline presentation: the device has no transport connectivity.
///
/// Graphical state only — connectivity is never probed here.
class OneBitOfflineState extends StatelessWidget {
  const OneBitOfflineState({
    this.title = 'Offline',
    this.message,
    this.action,
    super.key,
  });

  /// Headline; callers localize.
  final String title;

  /// Optional supporting text.
  final String? message;

  /// Optional single action (retry, settings).
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      label: title,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(OneBitSpacing.xxxxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: Icon(
                  OneBitIcons.cloudOff,
                  size: OneBitIconSize.feature,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: OneBitSpacing.l),
              Text(
                title,
                style: textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              if (message != null) ...[
                const SizedBox(height: OneBitSpacing.s),
                Text(
                  message!,
                  style: textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
              if (action != null) ...[
                const SizedBox(height: OneBitSpacing.xl),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
