import 'package:flutter/material.dart';
import 'package:onebit/shared/design_system/animations/onebit_motion.dart';
import 'package:onebit/shared/design_system/spacing/onebit_spacing.dart';
import 'package:onebit/shared/design_system/themes/onebit_theme_extension.dart';
import 'package:onebit/shared/design_system/typography/onebit_typography.dart';

/// Consistent page header for all primary pages.
///
/// Renders a compact header with:
/// * Page title — left-aligned, strong, 28px, Consolas
/// * Optional right-aligned action icons (24dp visual, 48dp touch target)
/// * Optional status indicator (dot + label)
/// * Optional subtitle under the title
///
/// This header replaces the Material [AppBar] on primary pages, keeping
/// the design language uniform without consuming unnecessary vertical space.
///
/// ## Variants
///
/// * [OneBitPageHeader.status] — includes a status dot and label
/// * [OneBitPageHeader.minimal] — title + actions only, no status
class OneBitPageHeader extends StatelessWidget {
  const OneBitPageHeader({
    required this.title,
    this.actions = const [],
    this.status,
    this.statusColor,
    this.subtitle,
    this.animate = true,
    super.key,
  });

  /// Status variant with a colored dot and label.
  factory OneBitPageHeader.status({
    required String title,
    required String status,
    Color? statusColor,
    List<Widget> actions = const [],
    String? subtitle,
    bool animate = true,
    Key? key,
  }) {
    return OneBitPageHeader(
      key: key,
      title: title,
      actions: actions,
      status: status,
      statusColor: statusColor,
      subtitle: subtitle,
      animate: animate,
    );
  }

  /// Minimal variant: title + actions only, no status line.
  factory OneBitPageHeader.minimal({
    required String title,
    List<Widget> actions = const [],
    String? subtitle,
    bool animate = true,
    Key? key,
  }) {
    return OneBitPageHeader(
      key: key,
      title: title,
      actions: actions,
      subtitle: subtitle,
      animate: animate,
    );
  }

  /// Page title rendered in the monospace family.
  final String title;

  /// Right-aligned action icons (archive, search, settings, etc.).
  ///
  /// Each action should be an [IconButton] or similar widget with a
  /// minimum 48dp touch target.
  final List<Widget> actions;

  /// Optional status label (e.g. "connected", "scanning", "3 nodes").
  final String? status;

  /// Color of the status dot; defaults to `info` (cyan).
  final Color? statusColor;

  /// Optional subtitle under the title.
  final String? subtitle;

  /// Whether to animate the header entry.
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final colors = context.oneBitColors;

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(
        OneBitSpacing.lg,
        OneBitSpacing.sm,
        OneBitSpacing.sm,
        OneBitSpacing.xs,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Title
              Text(
                title,
                style: OneBitTypography.oneBitPageTitle(
                  color: colors.textPrimary,
                ),
              ),
              // Right actions
              const Spacer(),
              if (actions.isNotEmpty) ...actions,
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: OneBitTypography.oneBitCaption(
                color: colors.textMuted,
              ),
            ),
          ],
          if (status != null) ...[
            const SizedBox(height: OneBitSpacing.xxs),
            Row(
              children: [
                _StatusDot(
                  color: statusColor ?? colors.info,
                ),
                const SizedBox(width: OneBitSpacing.xs),
                Text(
                  status!,
                  style: OneBitTypography.oneBitCaption(
                    color: colors.textMuted,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );

    if (!animate) return header;

    return _AnimatedHeader(child: header);
  }
}

/// Small colored status dot with a subtle pulse animation.
class _StatusDot extends StatefulWidget {
  const _StatusDot({required this.color});

  final Color color;

  @override
  State<_StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<_StatusDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: OneBitMotion.statusPulse,
    );
    _pulse = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        return Opacity(
          opacity: _pulse.value,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}

/// Fade-in + slide-up entry animation for the header.
class _AnimatedHeader extends StatelessWidget {
  const _AnimatedHeader({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: OneBitMotion.resolve(context, OneBitMotion.medium),
      curve: OneBitMotion.emphasized,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 8 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
