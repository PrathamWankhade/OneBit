import 'package:flutter/material.dart';
import 'package:onebit/shared/design_system/icons/onebit_icons.dart';
import 'package:onebit/shared/design_system/spacing/onebit_spacing.dart';
import 'package:onebit/shared/design_system/tokens/onebit_component_tokens.dart';

/// Standard empty-state presentation (no content yet in a region).
class OneBitEmptyState extends StatelessWidget {
  const OneBitEmptyState({
    required this.title,
    this.message,
    this.action,
    this.icon = OneBitIcons.signal,
    super.key,
  });

  /// Icon shown above the text.
  final IconData icon;

  /// Primary title.
  final String title;

  /// Optional supporting text.
  final String? message;

  /// Optional single action (usually a [OneBitButton]).
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
                  icon,
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
