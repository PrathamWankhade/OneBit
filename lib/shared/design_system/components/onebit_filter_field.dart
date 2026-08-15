import 'package:flutter/material.dart';
import 'package:onebit/shared/design_system/components/onebit_badge.dart';
import 'package:onebit/shared/design_system/components/onebit_icon_button.dart';
import 'package:onebit/shared/design_system/icons/onebit_icons.dart';
import 'package:onebit/shared/design_system/tokens/onebit_component_tokens.dart';

/// Filter input: search-style field with a filter glyph, an active-filter
/// badge and a clear action.
///
/// Presentation-only — the caller owns the controller and maps [onChanged]
/// onto its filter state.
class OneBitFilterField extends StatefulWidget {
  const OneBitFilterField({
    required this.controller,
    this.hintText,
    this.onChanged,
    this.onClear,
    this.activeCount,
    this.clearTooltip,
    super.key,
  });

  /// Controlled text value.
  final TextEditingController controller;

  /// Placeholder text.
  final String? hintText;

  /// Fired on every edit.
  final ValueChanged<String>? onChanged;

  /// Extra clearing behavior; the field clears its own text first.
  final VoidCallback? onClear;

  /// Number of active non-text filters; badge hidden when `null` or zero.
  final int? activeCount;

  /// Semantic label for the clear action; callers localize.
  final String? clearTooltip;

  @override
  State<OneBitFilterField> createState() => _OneBitFilterFieldState();
}

final class _OneBitFilterFieldState extends State<OneBitFilterField> {
  void _clear() {
    widget.controller.clear();
    widget.onChanged?.call('');
    widget.onClear?.call();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TextField(
      controller: widget.controller,
      onChanged: widget.onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: widget.hintText,
        prefixIcon: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Icon(
              OneBitIcons.filter,
              size: OneBitIconSize.s,
              color: scheme.onSurfaceVariant,
            ),
            if (widget.activeCount != null && widget.activeCount! > 0)
              Positioned(
                right: -4,
                top: -8,
                child: OneBitBadge(count: widget.activeCount),
              ),
          ],
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
