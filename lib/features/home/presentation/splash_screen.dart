import 'package:flutter/material.dart';
import 'package:onebit/core/extensions/build_context_extensions.dart';
import 'package:onebit/core/widgets/onebit_scaffold.dart';
import 'package:onebit/shared/design_system/spacing/onebit_spacing.dart';

/// Branded boot screen.
///
/// The router redirect leaves this screen as soon as the identity and the
/// restored tab resolve — this widget owns no timers or decision logic.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return OneBitScaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/icons/OneBit.png', width: 96, height: 96),
            const SizedBox(height: OneBitSpacing.l),
            Text(l10n.appTitle, style: context.textTheme.displaySmall),
            const SizedBox(height: OneBitSpacing.s),
            Text(l10n.splashTagline, style: context.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
