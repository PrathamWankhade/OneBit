import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/core/extensions/build_context_extensions.dart';
import 'package:onebit/core/widgets/onebit_scaffold.dart';
import 'package:onebit/features/launch/domain/local_initializer.dart';
import 'package:onebit/features/launch/presentation/launch_providers.dart';
import 'package:onebit/features/launch/presentation/launch_theme.dart';
import 'package:onebit/shared/design_system/colors/onebit_color_schemes.dart';
import 'package:onebit/shared/design_system/components/onebit_button.dart';
import 'package:onebit/shared/design_system/components/onebit_loading_indicator.dart';
import 'package:onebit/shared/design_system/spacing/onebit_spacing.dart';
import 'package:onebit/shared/design_system/typography/onebit_typography.dart';

/// Local initialization.
///
/// Every status line shown here is backed by a real check emitted by the
/// [LocalInitializer] — there is no fake progress, no fabricated step, no
/// timer. When every check passes, the launch controller marks first-run
/// setup complete and enters Channels; when a check fails, the failure is
/// shown with a retry action.
///
/// The back gesture is blocked on this screen: initialization is the final
/// step and leaving it mid-run would leave setup unpersisted.
class InitializingScreen extends ConsumerStatefulWidget {
  const InitializingScreen({super.key});

  @override
  ConsumerState<InitializingScreen> createState() => _InitializingScreenState();
}

final class _InitializingScreenState extends ConsumerState<InitializingScreen> {
  @override
  void initState() {
    super.initState();
    // Run the real initialization once when the screen mounts. Retries are
    // explicit user actions below.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(launchControllerProvider.notifier).runInitialization();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(launchControllerProvider);

    return PopScope(
      // Initialization must not be interrupted by back navigation.
      canPop: false,
      child: LaunchTheme(
        child: OneBitScaffold(
          body: Padding(
            padding: const EdgeInsets.all(OneBitSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(flex: 2),
                Text(
                  l10n.initializingTitle,
                  style: context.textTheme.headlineMedium,
                ),
                const SizedBox(height: OneBitSpacing.xl),
                if (state.checks.isEmpty && !state.failed)
                  Text(
                    l10n.initializingIdle,
                    style: context.textTheme.bodyMedium,
                  ),
                for (final outcome in state.checks)
                  _CheckLine(outcome: outcome),
                if (state.failed) ...[
                  const SizedBox(height: OneBitSpacing.xl),
                  _Failure(detail: '${state.error}'),
                ],
                const Spacer(flex: 3),
                if (state.failed) ...[
                  Center(
                    child: OneBitButton(
                      label: l10n.commonRetry,
                      onPressed: () => ref
                          .read(launchControllerProvider.notifier)
                          .retryInitialization(),
                      variant: OneBitButtonVariant.secondary,
                    ),
                  ),
                ] else ...[
                  const OneBitLoadingIndicator(),
                ],
                const SizedBox(height: OneBitSpacing.xl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One `[OK] STATUS` / `[ERR] STATUS` terminal line.
final class _CheckLine extends StatelessWidget {
  const _CheckLine({required this.outcome});

  final LocalInitOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final colors = context.oneBitColors;
    final status = outcome.ok
        ? ('[OK]', colors.ansiGreen)
        : ('[ERR]', colors.ansiRed);
    final label = switch (outcome.check) {
      LocalInitCheck.identity => context.l10n.initializingIdentity,
      LocalInitCheck.storage => context.l10n.initializingStorage,
      LocalInitCheck.messaging => context.l10n.initializingMessaging,
      LocalInitCheck.media => context.l10n.initializingMedia,
      LocalInitCheck.mesh => context.l10n.initializingMesh,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: OneBitSpacing.s),
      child: Text.rich(
        TextSpan(
          style: OneBitTypography.technicalStyle(
            fontSize: OneBitTypography.technical,
            color: context.colorScheme.onSurface,
          ),
          children: [
            TextSpan(
              text: '${status.$1} ',
              style: TextStyle(color: status.$2, fontWeight: FontWeight.bold),
            ),
            TextSpan(text: label),
          ],
        ),
      ),
    );
  }
}

/// The failure block: title, technical detail, and a retry affordance.
final class _Failure extends StatelessWidget {
  const _Failure({required this.detail});

  final String detail;

  @override
  Widget build(BuildContext context) {
    final colors = context.oneBitColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.initializingFailed,
          style: context.textTheme.titleSmall?.copyWith(color: colors.ansiRed),
        ),
        const SizedBox(height: OneBitSpacing.s),
        Text(
          detail,
          style: OneBitTypography.technicalStyle(
            fontSize: OneBitTypography.caption,
            color: colors.ansiBrightBlack,
          ),
        ),
      ],
    );
  }
}
