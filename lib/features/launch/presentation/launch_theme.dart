import 'package:flutter/material.dart';
import 'package:onebit/shared/design_system/themes/onebit_theme_data.dart';

/// Forces the dark (black) identity on the launch experience.
///
/// The brand opening, intro, display-name and initialization screens are
/// always rendered on the pure-black terminal background regardless of the
/// user's appearance preference — the launch experience is part of the
/// brand identity, not of the theme switch.
class LaunchTheme extends StatelessWidget {
  const LaunchTheme({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Theme(data: OneBitDarkTheme.build(), child: child);
  }
}
