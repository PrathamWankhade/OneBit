import 'package:flutter/material.dart';

/// Tokenized Material 3 text field.
///
/// Wraps a raw [TextField] so every input shares the same dressing; input
/// geometry is applied centrally via the theme builder.
class OneBitTextField extends StatelessWidget {
  const OneBitTextField({
    required this.controller,
    this.label,
    this.hint,
    this.prefixIcon,
    this.suffixIcon,
    this.enabled = true,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.maxLines = 1,
    this.onChanged,
    this.onSubmitted,
    this.validator,
    this.autofocus = false,
    super.key,
  });

  /// Controlled text value.
  final TextEditingController controller;

  /// Floating label.
  final String? label;

  /// Hint text.
  final String? hint;

  final Widget? prefixIcon;

  final Widget? suffixIcon;

  final bool enabled;

  final bool obscureText;

  final TextInputType? keyboardType;

  final TextInputAction? textInputAction;

  final int maxLines;

  final ValueChanged<String>? onChanged;

  /// Fired when the keyboard action is submitted.
  final ValueChanged<String>? onSubmitted;

  final FormFieldValidator<String>? validator;

  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      enabled: enabled,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      maxLines: maxLines,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        errorText: validator?.call(controller.text),
        prefixIconColor: WidgetStateColor.resolveWith((states) {
          if (states.contains(WidgetState.error)) return scheme.error;
          if (states.contains(WidgetState.focused)) return scheme.primary;
          return scheme.onSurfaceVariant;
        }),
        suffixIconColor: WidgetStateColor.resolveWith((states) {
          if (states.contains(WidgetState.error)) return scheme.error;
          if (states.contains(WidgetState.focused)) return scheme.primary;
          return scheme.onSurfaceVariant;
        }),
      ),
      autofocus: autofocus,
    );
  }
}
