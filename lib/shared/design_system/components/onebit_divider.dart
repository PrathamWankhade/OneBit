import 'package:flutter/material.dart';

/// Tokenized hairline divider.
///
/// Color and thickness come from the ambient `DividerThemeData` (bound to
/// the border tokens in the theme builder); only length overrides are
/// allowed here.
class OneBitDivider extends StatelessWidget {
  const OneBitDivider({this.height, this.indent, this.endIndent, super.key});

  /// Divider height; defaults to the theme's divider space.
  final double? height;

  /// Space before the line (dense rows, list items).
  final double? indent;

  /// Space after the line.
  final double? endIndent;

  @override
  Widget build(BuildContext context) {
    return Divider(height: height, indent: indent, endIndent: endIndent);
  }
}
