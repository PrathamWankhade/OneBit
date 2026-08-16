import 'package:flutter/material.dart';
import 'package:onebit/shared/design_system/components/onebit_button.dart';
import 'package:onebit/shared/design_system/icons/onebit_icons.dart';
import 'package:onebit/shared/design_system/spacing/onebit_spacing.dart';
import 'package:onebit/shared/design_system/themes/onebit_theme_extension.dart';
import 'package:onebit/shared/design_system/tokens/onebit_component_tokens.dart';

/// Permission request presentation.
///
/// Renders the mandatory rationale, a request action and — when [denied] —
/// an open-settings action. Permission state itself is never read here.
///
/// Content is vertically centered within the available region, consistent
/// with [OneBitEmptyState].
class OneBitPermissionState extends StatelessWidget {
  const OneBitPermissionState({
    required this.title,
    required this.message,
    required this.onRequest,
    this.requestLabel = 'Allow',
    this.denied = false,
    this.onOpenSettings,
    this.settingsLabel = 'Open settings',
    this.requesting = false,
    this.icon = OneBitIcons.bluetoothDisabled,
    this.secondaryInfo,
    super.key,
  });

  /// What the permission enables; callers localize.
  final String title;

  /// Rationale; callers localize.
  final String message;

  /// Requests the permission.
  final VoidCallback onRequest;

  /// Label of the request action (localize).
  final String requestLabel;

  /// When true the permission was refused and settings guidance shows.
  final bool denied;

  /// Opens system settings; required when [denied].
  final VoidCallback? onOpenSettings;

  /// Label of the settings action (localize).
  final String settingsLabel;

  /// Shows a progress state on the request action.
  final bool requesting;

  /// Icon shown above the title; defaults to bluetooth disabled.
  final IconData icon;

  /// Optional secondary information displayed below the actions.
  final Widget? secondaryInfo;

  @override
  Widget build(BuildContext context) {
    final colors = context.oneBitColors;
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      label: '$title. $message',
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
                    color: colors.infoContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: OneBitIconSize.xl,
                    color: colors.info,
                  ),
                ),
              ),
              const SizedBox(height: OneBitSpacing.xl),
              Text(
                title,
                style: textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: OneBitSpacing.sm),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Text(
                  message,
                  style: textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: OneBitSpacing.xl),
              OneBitButton(
                label: requestLabel,
                onPressed: requesting ? null : onRequest,
                loading: requesting,
                size: OneBitButtonSize.large,
              ),
              if (denied) ...[
                const SizedBox(height: OneBitSpacing.s),
                OneBitOutlinedButton(
                  label: settingsLabel,
                  onPressed: onOpenSettings ?? () {},
                  icon: OneBitIcons.shellSettings,
                ),
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
