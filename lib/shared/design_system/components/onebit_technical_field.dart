import 'package:flutter/material.dart';
import 'package:onebit/shared/design_system/typography/onebit_typography.dart';

/// Text input for technical values (node IDs, fingerprints, packet IDs).
///
/// The field renders its content in the technical family and stays narrow by
/// default; no validation or formatting logic lives here.
class OneBitTechnicalField extends StatelessWidget {
  const OneBitTechnicalField({
    required this.controller,
    this.label,
    this.hint,
    this.onChanged,
    this.enabled = true,
    this.maxLength,
    this.autocorrect = false,
    this.autofocus = false,
    super.key,
  });

  /// Controlled text value.
  final TextEditingController controller;

  /// Floating label.
  final String? label;

  /// Hint text.
  final String? hint;

  /// Fired on every edit.
  final ValueChanged<String>? onChanged;

  /// Disables the field.
  final bool enabled;

  /// Maximum accepted character count; `null` is unlimited.
  final int? maxLength;

  /// Technical values are identifiers — autocorrect is off by default.
  final bool autocorrect;

  /// Requests focus on mount.
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mono = OneBitTypography.technicalStyle(
      fontSize: OneBitTypography.technical,
      color: scheme.onSurface,
    );

    return TextField(
      controller: controller,
      enabled: enabled,
      onChanged: onChanged,
      autofocus: autofocus,
      autocorrect: autocorrect,
      maxLength: maxLength,
      style: mono,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        counterText: maxLength == null ? '' : null,
        labelStyle: mono.copyWith(
          fontSize: OneBitTypography.caption,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
