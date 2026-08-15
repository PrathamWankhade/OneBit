import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/core/extensions/build_context_extensions.dart';
import 'package:onebit/features/launch/presentation/launch_controller.dart';
import 'package:onebit/features/launch/presentation/launch_providers.dart';
import 'package:onebit/features/launch/presentation/launch_theme.dart';
import 'package:onebit/shared/design_system/animations/onebit_motion.dart';
import 'package:onebit/shared/design_system/components/onebit_button.dart';
import 'package:onebit/shared/design_system/spacing/onebit_spacing.dart';

/// The brand opening: the OneBit logo fades in, holds, and the whole screen
/// fades out — then the resolved first-run destination is entered.
///
/// The animation is the only motion on this screen (1.4s total, logo fade
/// 350ms), and it collapses to nothing under reduced motion. The screen
/// owns no decision logic: when both the animation and the launch flow
/// have completed, it hands off to [LaunchController.finishOpening].
class OpeningScreen extends ConsumerStatefulWidget {
  const OpeningScreen({super.key});

  @override
  ConsumerState<OpeningScreen> createState() => _OpeningScreenState();
}

final class _OpeningScreenState extends ConsumerState<OpeningScreen>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  bool _animationDone = false;
  bool _navigated = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) return;
    if (context.reduceMotion) {
      // Reduced motion: show the logo immediately, no animation needed.
      _animationDone = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _leaveIfPossible();
      });
      return;
    }
    _controller = AnimationController(
      vsync: this,
      duration: OneBitMotion.opening,
    )..addStatusListener(_onStatus);
    _controller!.forward();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _animationDone = true;
      _leaveIfPossible();
    }
  }

  void _leaveIfPossible() {
    if (_navigated || !_animationDone) return;
    final flow = ref.read(launchFlowProvider);
    if (!flow.hasValue) return;
    _navigated = true;
    ref.read(launchControllerProvider.notifier).finishOpening(flow.value!);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(launchFlowProvider, (previous, next) {
      if (next.hasValue) _leaveIfPossible();
    });
    final flow = ref.watch(launchFlowProvider);
    final l10n = context.l10n;

    return LaunchTheme(
      child: Scaffold(
        body: Center(
          child: flow.hasError
              ? _Error(
                  detail: l10n.openingErrorDetail,
                  onRetry: () => ref.invalidate(launchFlowProvider),
                )
              : _Logo(
                  controller: _controller,
                  reduceMotion: context.reduceMotion,
                ),
        ),
      ),
    );
  }
}

/// The animated logo + wordmark.
final class _Logo extends StatelessWidget {
  const _Logo({required this.controller, required this.reduceMotion});

  final AnimationController? controller;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'OneBit',
      image: true,
      child: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (reduceMotion || controller == null) {
      // Reduced motion: show the logo immediately at full opacity.
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset('assets/icons/OneBit.png', width: 96, height: 96),
          const SizedBox(height: OneBitSpacing.l),
          Text('OneBit', style: context.textTheme.displaySmall),
        ],
      );
    }

    final fadeIn = CurvedAnimation(
      parent: controller!,
      curve: const Interval(0.0, 0.25, curve: OneBitMotion.emphasized),
    );
    // The reverse fade runs over the last 15% of the animation.
    final fadeOut = CurvedAnimation(
      parent: controller!,
      curve: const Interval(0.85, 1.0, curve: OneBitMotion.standard),
    );

    return FadeTransition(
      opacity: ReverseAnimation(fadeOut),
      child: FadeTransition(
        opacity: fadeIn,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/icons/OneBit.png', width: 96, height: 96),
            const SizedBox(height: OneBitSpacing.l),
            Text('OneBit', style: context.textTheme.displaySmall),
          ],
        ),
      ),
    );
  }
}

/// Rendered when the launch flow itself could not resolve.
final class _Error extends StatelessWidget {
  const _Error({required this.detail, required this.onRetry});

  final String detail;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.all(OneBitSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.openingErrorTitle, style: context.textTheme.headlineMedium),
          const SizedBox(height: OneBitSpacing.m),
          Text(
            detail,
            textAlign: TextAlign.center,
            style: context.textTheme.bodyMedium,
          ),
          const SizedBox(height: OneBitSpacing.xl),
          OneBitButton(
            label: l10n.commonRetry,
            onPressed: onRetry,
            variant: OneBitButtonVariant.secondary,
          ),
        ],
      ),
    );
  }
}
