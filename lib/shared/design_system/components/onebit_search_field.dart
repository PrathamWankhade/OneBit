import 'package:flutter/material.dart';
import 'package:onebit/shared/design_system/components/onebit_icon_button.dart';
import 'package:onebit/shared/design_system/icons/onebit_icons.dart';
import 'package:onebit/shared/design_system/tokens/onebit_component_tokens.dart';

/// Tokenized search field.
///
/// Renders a filled input with a leading search glyph and, while the field
/// is non-empty, a clear action. Clearing also resets the caret position.
class OneBitSearchField extends StatefulWidget {
  const OneBitSearchField({
    required this.controller,
    this.hintText,
    this.onChanged,
    this.onSubmitted,
    this.clearTooltip,
    super.key,
  });

  /// Controlled text value.
  final TextEditingController controller;

  /// Placeholder text.
  final String? hintText;

  /// Fired on every edit.
  final ValueChanged<String>? onChanged;

  /// Fired on keyboard submit.
  final ValueChanged<String>? onSubmitted;

  /// Semantic label for the clear action; screens localize this string.
  final String? clearTooltip;

  @override
  State<OneBitSearchField> createState() => _OneBitSearchFieldState();
}

final class _OneBitSearchFieldState extends State<OneBitSearchField> {
  void _clear() {
    widget.controller.clear();
    widget.onChanged?.call('');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TextField(
      controller: widget.controller,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: widget.hintText,
        prefixIcon: Icon(
          OneBitIcons.search,
          size: OneBitIconSize.s,
          color: scheme.onSurfaceVariant,
        ),
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: widget.controller,
          builder: (context, value, child) {
            if (value.text.isEmpty) return const SizedBox.shrink();
            return OneBitIconButton(
              icon: OneBitIcons.close,
              size: OneBitIconSize.s,
              tooltip: widget.clearTooltip,
              onPressed: _clear,
            );
          },
        ),
      ),
    );
  }
}
