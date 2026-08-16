import 'package:flutter/material.dart';
import 'package:onebit/shared/design_system/animations/onebit_motion.dart';
import 'package:onebit/shared/design_system/icons/onebit_icons.dart';
import 'package:onebit/shared/design_system/spacing/onebit_spacing.dart';
import 'package:onebit/shared/design_system/themes/onebit_theme_extension.dart';
import 'package:onebit/shared/design_system/tokens/onebit_component_tokens.dart';

/// Standard empty-state presentation (no content yet in a region).
///
/// Renders with a staggered fade-in animation so the icon, title, message
/// and action appear in sequence — creating a calm, intentional entrance.
///
/// Content is vertically centered within the available region, accounting
/// for page headers and floating navigation without drifting to extremes.
class OneBitEmptyState extends StatefulWidget {
  const OneBitEmptyState({
    required this.title,
    this.message,
    this.action,
    this.secondaryInfo,
    this.icon = OneBitIcons.signal,
    super.key,
  });

  /// Icon shown above the text.
  final IconData icon;

  /// Primary title.
  final String title;

  /// Optional supporting text.
  final String? message;

  /// Optional single action (usually a [OneBitButton]).
  final Widget? action;

  /// Optional secondary information displayed below the action.
  final Widget? secondaryInfo;

  @override
  State<OneBitEmptyState> createState() => _OneBitEmptyStateState();
}

class _OneBitEmptyStateState extends State<OneBitEmptyState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _iconFade;
  late final Animation<double> _titleFade;
  late final Animation<double> _messageFade;
  late final Animation<double> _actionFade;
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
    _messageFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.35, 0.75, curve: OneBitMotion.emphasized),
    );
    _actionFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.5, 0.9, curve: OneBitMotion.emphasized),
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
    final colors = context.oneBitColors;
    final textTheme = Theme.of(context).textTheme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: OneBitIconSize.feature,
          height: OneBitIconSize.feature,
          decoration: BoxDecoration(
            color: colors.infoContainer,
            shape: BoxShape.circle,
          ),
          child: ExcludeSemantics(
            child: Icon(
              widget.icon,
              size: OneBitIconSize.xl,
              color: colors.info,
            ),
          ),
        ),
        const SizedBox(height: OneBitSpacing.xl),
        Text(
          widget.title,
          style: textTheme.headlineMedium,
          textAlign: TextAlign.center,
        ),
        if (widget.message != null) ...[
          const SizedBox(height: OneBitSpacing.sm),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Text(
              widget.message!,
              style: textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ),
        ],
        if (widget.action != null) ...[
          const SizedBox(height: OneBitSpacing.xl),
          widget.action!,
        ],
        if (widget.secondaryInfo != null) ...[
          const SizedBox(height: OneBitSpacing.s),
          widget.secondaryInfo!,
        ],
      ],
    );

    return Semantics(
      label: widget.title,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: OneBitSpacing.xxxxl,
            vertical: OneBitSpacing.xxxl,
          ),
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
                          width: OneBitIconSize.feature,
                          height: OneBitIconSize.feature,
                          decoration: BoxDecoration(
                            color: colors.infoContainer,
                            shape: BoxShape.circle,
                          ),
                          child: ExcludeSemantics(
                            child: Icon(
                              widget.icon,
                              size: OneBitIconSize.xl,
                              color: colors.info,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: OneBitSpacing.xl),
                      FadeTransition(
                        opacity: _titleFade,
                        child: Text(
                          widget.title,
                          style: textTheme.headlineMedium,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      if (widget.message != null) ...[
                        const SizedBox(height: OneBitSpacing.sm),
                        FadeTransition(
                          opacity: _messageFade,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 320),
                            child: Text(
                              widget.message!,
                              style: textTheme.bodyMedium,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                      if (widget.action != null) ...[
                        const SizedBox(height: OneBitSpacing.xl),
                        FadeTransition(
                          opacity: _actionFade,
                          child: widget.action,
                        ),
                      ],
                      if (widget.secondaryInfo != null) ...[
                        const SizedBox(height: OneBitSpacing.s),
                        FadeTransition(
                          opacity: _actionFade,
                          child: widget.secondaryInfo,
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
