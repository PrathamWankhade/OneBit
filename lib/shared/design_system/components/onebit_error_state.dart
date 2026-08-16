import 'package:flutter/material.dart';
import 'package:onebit/shared/design_system/animations/onebit_motion.dart';
import 'package:onebit/shared/design_system/components/onebit_button.dart';
import 'package:onebit/shared/design_system/icons/onebit_icons.dart';
import 'package:onebit/shared/design_system/spacing/onebit_spacing.dart';
import 'package:onebit/shared/design_system/tokens/onebit_component_tokens.dart';
import 'package:onebit/shared/design_system/typography/onebit_typography.dart';

/// Standard failure presentation.
///
/// Shows the failure's message with an optional technical detail and a
/// retry action. Renders with a staggered fade-in animation matching
/// [OneBitEmptyState]'s entrance pattern.
class OneBitErrorState extends StatefulWidget {
  const OneBitErrorState({
    required this.message,
    this.onRetry,
    this.detail,
    this.retryLabel = 'Retry',
    super.key,
  });

  /// Primary message shown to the user.
  final String message;

  /// Optional supporting detail (failure code, technical hint).
  final String? detail;

  /// Retry action; `null` hides the retry button.
  final VoidCallback? onRetry;

  /// Label for the retry action; screens localize this string.
  final String retryLabel;

  factory OneBitErrorState.fromFailure({
    required Object failure,
    VoidCallback? onRetry,
    String retryLabel = 'Retry',
  }) {
    return OneBitErrorState(
      message: failure.toString(),
      detail: failure.runtimeType.toString(),
      onRetry: onRetry,
      retryLabel: retryLabel,
    );
  }

  @override
  State<OneBitErrorState> createState() => _OneBitErrorStateState();
}

class _OneBitErrorStateState extends State<OneBitErrorState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _iconFade;
  late final Animation<double> _titleFade;
  late final Animation<double> _detailFade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: OneBitMotion.medium * 2,
    );

    _iconFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.4, curve: OneBitMotion.emphasized),
    );
    _titleFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.2, 0.6, curve: OneBitMotion.emphasized),
    );
    _detailFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.35, 0.75, curve: OneBitMotion.emphasized),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.6, curve: OneBitMotion.emphasized),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: scheme.errorContainer,
            shape: BoxShape.circle,
          ),
          child: ExcludeSemantics(
            child: Icon(
              OneBitIcons.error,
              size: OneBitIconSize.xl,
              color: scheme.error,
            ),
          ),
        ),
        const SizedBox(height: OneBitSpacing.xl),
        Text(
          widget.message,
          textAlign: TextAlign.center,
          style: textTheme.titleLarge,
        ),
        if (widget.detail != null) ...[
          const SizedBox(height: OneBitSpacing.s),
          Text(
            widget.detail!,
            textAlign: TextAlign.center,
            style: OneBitTypography.technicalStyle(
              fontSize: OneBitTypography.caption,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
        if (widget.onRetry != null) ...[
          const SizedBox(height: OneBitSpacing.xl),
          OneBitOutlinedButton(
            label: widget.retryLabel,
            icon: OneBitIcons.retry,
            onPressed: widget.onRetry,
          ),
        ],
      ],
    );

    return Semantics(
      label: widget.message,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(OneBitSpacing.xxxxl),
          child: reduceMotion
              ? content
              : SlideTransition(
                  position: _slide,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FadeTransition(
                        opacity: _iconFade,
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: scheme.errorContainer,
                            shape: BoxShape.circle,
                          ),
                          child: ExcludeSemantics(
                            child: Icon(
                              OneBitIcons.error,
                              size: OneBitIconSize.xl,
                              color: scheme.error,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: OneBitSpacing.xl),
                      FadeTransition(
                        opacity: _titleFade,
                        child: Text(
                          widget.message,
                          textAlign: TextAlign.center,
                          style: textTheme.titleLarge,
                        ),
                      ),
                      if (widget.detail != null) ...[
                        const SizedBox(height: OneBitSpacing.s),
                        FadeTransition(
                          opacity: _detailFade,
                          child: Text(
                            widget.detail!,
                            textAlign: TextAlign.center,
                            style: OneBitTypography.technicalStyle(
                              fontSize: OneBitTypography.caption,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                      if (widget.onRetry != null) ...[
                        const SizedBox(height: OneBitSpacing.xl),
                        FadeTransition(
                          opacity: _detailFade,
                          child: OneBitOutlinedButton(
                            label: widget.retryLabel,
                            icon: OneBitIcons.retry,
                            onPressed: widget.onRetry,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
