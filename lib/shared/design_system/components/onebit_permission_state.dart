import 'package:flutter/material.dart';
import 'package:onebit/shared/design_system/components/onebit_button.dart';
import 'package:onebit/shared/design_system/icons/onebit_icons.dart';
import 'package:onebit/shared/design_system/spacing/onebit_spacing.dart';
import 'package:onebit/shared/design_system/tokens/onebit_component_tokens.dart';

/// Permission request presentation.
///
/// Renders the mandatory rationale, a request action and — when [denied] —
/// an open-settings action. Permission state itself is never read here.
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      label: '$title. $message',
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
              const SizedBox(height: OneBitSpacing.s),
              Text(
                message,
                style: textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: OneBitSpacing.xl),
              OneBitButton(
                label: requestLabel,
                onPressed: requesting ? null : onRequest,
                loading: requesting,
              ),
              if (denied) ...[
                const SizedBox(height: OneBitSpacing.s),
                OneBitOutlinedButton(
                  label: settingsLabel,
                  onPressed: onOpenSettings ?? () {},
                  icon: OneBitIcons.shellSettings,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
