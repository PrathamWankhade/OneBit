import 'package:flutter/material.dart';

/// Standard page container.
///
/// The surface background (the identity background token) comes from the
/// theme's `scaffoldBackgroundColor`; the shell and feature screens compose
/// into [OneBitScaffold] instead of raw `Scaffold` so chrome stays uniform.
class OneBitScaffold extends StatelessWidget {
  const OneBitScaffold({
    required this.body,
    this.appBar,
    this.bottomNavigationBar,
    super.key,
  });

  /// Feature content.
  final Widget body;

  /// Optional app bar (branded by the shell when `null`).
  final PreferredSizeWidget? appBar;

  /// Optional navigation bar.
  final Widget? bottomNavigationBar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar,
      body: SafeArea(child: body),
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}
