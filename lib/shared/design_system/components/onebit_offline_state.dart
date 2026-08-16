import 'package:flutter/material.dart';
import 'package:onebit/shared/design_system/icons/onebit_icons.dart';
import 'package:onebit/shared/design_system/spacing/onebit_spacing.dart';
import 'package:onebit/shared/design_system/themes/onebit_theme_extension.dart';
import 'package:onebit/shared/design_system/tokens/onebit_component_tokens.dart';

/// Standard offline presentation: the device has no transport connectivity.
///
/// Graphical state only — connectivity is never probed here.
///
/// Content is vertically centered within the available region, consistent
/// with [OneBitEmptyState].
class OneBitOfflineState extends StatelessWidget {
  const OneBitOfflineState({
    this.title = 'Offline',
    this.message,
    this.action,
    this.secondaryInfo,
    super.key,
  });

  /// Headline; callers localize.
  final String title;

  /// Optional supporting text.
  final String? message;

  /// Optional single action (retry, settings).
  final Widget? action;

  /// Optional secondary information displayed below the action.
  final Widget? secondaryInfo;

  @override
  Widget build(BuildContext context) {
    final colors = context.oneBitColors;
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      label: title,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: OneBitSpacing.xxxxl,
            vertical: OneBitSpacing.xxxl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: Container(
                  width: OneBitIconSize.feature,
                  height: OneBitIconSize.feature,
                  decoration: BoxDecoration(
                    color: colors.warningContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    OneBitIcons.cloudOff,
                    size: OneBitIconSize.xl,
                    color: colors.warning,
                  ),
                ),
              ),
              const SizedBox(height: OneBitSpacing.xl),
              Text(
                title,
                style: textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              if (message != null) ...[
                const SizedBox(height: OneBitSpacing.sm),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: Text(
                    message!,
                    style: textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              if (action != null) ...[
                const SizedBox(height: OneBitSpacing.xl),
                action!,
              ],
              if (secondaryInfo != null) ...[
                const SizedBox(height: OneBitSpacing.s),
                secondaryInfo!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
