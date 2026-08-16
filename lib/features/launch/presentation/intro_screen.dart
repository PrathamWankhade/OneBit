import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/core/config/app_config_provider.dart';
import 'package:onebit/core/extensions/build_context_extensions.dart';
import 'package:onebit/core/widgets/onebit_scaffold.dart';
import 'package:onebit/features/launch/presentation/launch_providers.dart';
import 'package:onebit/features/launch/presentation/launch_theme.dart';
import 'package:onebit/shared/design_system/colors/onebit_palette.dart';
import 'package:onebit/shared/design_system/components/onebit_button.dart';
import 'package:onebit/shared/design_system/components/onebit_inline_error.dart';
import 'package:onebit/shared/design_system/spacing/onebit_spacing.dart';
import 'package:onebit/shared/design_system/typography/onebit_typography.dart';

/// First-run intro: brand, promise, and the single way forward.
///
/// No account language -- OneBit is local-first, so the copy only explains
/// what the product is. "Continue" advances the state machine; the system
/// back gesture on this screen behaves normally (this is the root of the
/// setup stack, so it exits the app).
class IntroScreen extends ConsumerStatefulWidget {
  const IntroScreen({super.key});

  @override
  ConsumerState<IntroScreen> createState() => _IntroScreenState();
}

final class _IntroScreenState extends ConsumerState<IntroScreen> {
  bool _submitting = false;
  String? _error;

  Future<void> _continue() async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(launchControllerProvider.notifier).proceedFromIntro();
    } on Object {
      if (mounted) {
        setState(() => _error = context.l10n.commonUnknownError);
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final version = ref.watch(appConfigProvider).version;

    return LaunchTheme(
      child: OneBitScaffold(
        body: Padding(
          padding: const EdgeInsets.all(OneBitSpacing.xl),
          child: Column(
            children: [
              const Spacer(flex: 2),
              Image.asset('assets/icons/OneBit.png', width: 96, height: 96),
              const SizedBox(height: OneBitSpacing.l),
              Text(l10n.appTitle, style: context.textTheme.displaySmall),
              const SizedBox(height: OneBitSpacing.l),
              Text(
                l10n.introTagline,
                textAlign: TextAlign.center,
                style: context.textTheme.bodyLarge,
              ),
              const SizedBox(height: OneBitSpacing.l),
              Text(
                l10n.introPrinciples,
                textAlign: TextAlign.center,
                style: context.textTheme.bodyLarge?.copyWith(
                  color: OneBitPalette.ansiWhite,
                ),
              ),
              const Spacer(flex: 2),
              Text(
                l10n.introInitLine(version),
                style: OneBitTypography.technicalStyle(
                  fontSize: OneBitTypography.caption,
                  color: OneBitPalette.ansiBrightBlack,
                ),
              ),
              const SizedBox(height: OneBitSpacing.m),
              if (_error != null) ...[
                OneBitInlineError(message: _error!),
                const SizedBox(height: OneBitSpacing.m),
              ],
              SizedBox(
                width: double.infinity,
                child: OneBitButton(
                  label: l10n.commonContinue,
                  onPressed: _submitting ? null : _continue,
                  loading: _submitting,
                ),
              ),
              const SizedBox(height: OneBitSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}
