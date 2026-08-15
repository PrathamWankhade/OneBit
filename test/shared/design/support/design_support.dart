import 'package:flutter/material.dart';
import 'package:onebit/core/theme/onebit_theme.dart';

/// Shared harness for design-system widget tests.
///
/// Every component test mounts under the OneBit light identity so failures
/// cannot be masked by a half-configured `MaterialApp`.
Widget oneBitApp(Widget child) => MaterialApp(
  theme: OneBitTheme.light,
  home: Scaffold(body: Center(child: child)),
);

/// Harness for tests that exercise the dark identity.
Widget oneBitDarkApp(Widget child) => MaterialApp(
  theme: OneBitTheme.dark,
  home: Scaffold(body: Center(child: child)),
);
