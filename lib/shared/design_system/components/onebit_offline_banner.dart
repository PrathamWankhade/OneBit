import 'package:flutter/material.dart';
import 'package:onebit/shared/design_system/animations/onebit_motion.dart';
import 'package:onebit/shared/design_system/icons/onebit_icons.dart';
import 'package:onebit/shared/design_system/spacing/onebit_spacing.dart';

/// Compact offline banner for lists that remain usable while disconnected.
///
/// Graphical state only — connectivity is never probed here. Callers localize
/// the strings. Slides in from the top when it appears.
class OneBitOfflineBanner extends StatefulWidget {
  const OneBitOfflineBanner({
    required this.title,
    required this.message,
    super.key,
  });

  /// Headline; callers localize.
  final String title;

  /// Supporting text; callers localize.
  final String message;

  @override
  State<OneBitOfflineBanner> createState() => _OneBitOfflineBannerState();
}

class _OneBitOfflineBannerState extends State<OneBitOfflineBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: OneBitMotion.medium,
    );
    _fade = CurvedAnimation(
      parent: _controller,
      curve: OneBitMotion.emphasized,
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: OneBitMotion.emphasized,
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

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Container(
          width: double.infinity,
          color: scheme.errorContainer,
          padding: const EdgeInsets.symmetric(
            horizontal: OneBitSpacing.m,
            vertical: OneBitSpacing.s,
          ),
          child: Row(
            children: [
              Icon(
                OneBitIcons.cloudOff,
                size: 20,
                color: scheme.onErrorContainer,
              ),
              const SizedBox(width: OneBitSpacing.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: textTheme.labelLarge?.copyWith(
                        color: scheme.onErrorContainer,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.message,
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onErrorContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
