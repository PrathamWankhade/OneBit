import 'package:flutter/material.dart';
import 'package:onebit/shared/design_system/accessibility/onebit_accessibility.dart';
import 'package:onebit/shared/design_system/tokens/onebit_component_tokens.dart';

/// Tokenized icon button with a guaranteed 48dp interactive target.
///
/// Prefer this over raw `IconButton` so sizing, semantics and ink behavior
/// stay consistent.
class OneBitIconButton extends StatelessWidget {
  const OneBitIconButton({
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.size = OneBitIconSize.m,
    super.key,
  });

  /// The icon glyph.
  final IconData icon;

  /// Callback; `null` renders the button disabled.
  final VoidCallback? onPressed;

  /// Tooltip; provides the semantic label when present.
  final String? tooltip;

  /// Icon size in dp.
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      icon: Icon(icon, size: size),
      onPressed: onPressed,
      tooltip: tooltip,
      iconSize: size,
      constraints: const BoxConstraints(
        minWidth: OneBitAccessibility.minInteractiveSize,
        minHeight: OneBitAccessibility.minInteractiveSize,
      ),
      padding: EdgeInsets.zero,
      color: scheme.onSurfaceVariant,
      disabledColor: scheme.onSurface.withValues(alpha: 0.38),
      highlightColor: scheme.primary.withValues(alpha: 0.08),
      splashColor: scheme.primary.withValues(alpha: 0.08),
    );
  }
}
