import 'package:flutter/material.dart';

/// Elevation tokens: shadow definitions at discrete levels.
///
/// OneBit favors flat surfaces and hairline borders over shadow depth; these
/// levels exist so components never invent their own shadow values.
abstract final class OneBitElevation {
  /// Flat — no shadow.
  static const BoxShadow none = BoxShadow();

  /// Resting surface shadow.
  static const BoxShadow level1 = BoxShadow(
    color: Color(0x14000000),
    blurRadius: 8,
    offset: Offset(0, 1),
  );

  /// Elevated surface shadow.
  static const BoxShadow level2 = BoxShadow(
    color: Color(0x1C000000),
    blurRadius: 16,
    offset: Offset(0, 2),
  );

  /// Floating surface shadow (menus, sheets).
  static const BoxShadow level3 = BoxShadow(
    color: Color(0x26000000),
    blurRadius: 24,
    offset: Offset(0, 4),
  );

  const OneBitElevation._();
}
