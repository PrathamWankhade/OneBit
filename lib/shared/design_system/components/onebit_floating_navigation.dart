import 'package:flutter/material.dart';
import 'package:onebit/shared/design_system/animations/onebit_motion.dart';
import 'package:onebit/shared/design_system/components/onebit_navigation_bar.dart';
import 'package:onebit/shared/design_system/spacing/onebit_elevation.dart';
import 'package:onebit/shared/design_system/spacing/onebit_radius.dart';
import 'package:onebit/shared/design_system/spacing/onebit_spacing.dart';
import 'package:onebit/shared/design_system/themes/onebit_theme_extension.dart';

/// Floating bottom navigation bar for the OneBit shell.
///
/// Icon-only capsule design — no text labels. An animated selection pill
/// smoothly travels behind the active icon. Handles safe-area insets
/// internally via [MediaQuery.paddingOf].
///
/// The capsule fills the available screen width between horizontal margins,
/// with each destination receiving an equal share (clamped to 48–72dp per
/// item) so four balanced destinations occupy the pill without empty space.
class FloatingBottomNavigation extends StatelessWidget {
  const FloatingBottomNavigation({
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    super.key,
  });

  /// The navigation destinations.
  final List<OneBitNavigationDestination> destinations;

  /// Currently selected index.
  final int selectedIndex;

  /// Callback when a destination is tapped.
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final safeAreaBottom = MediaQuery.paddingOf(context).bottom;
    const horizontalMargin = OneBitSpacing.lg;
    final availableWidth = screenWidth - (horizontalMargin * 2);

    return Padding(
      padding: EdgeInsets.only(
        left: horizontalMargin,
        right: horizontalMargin,
        bottom: OneBitSpacing.m + safeAreaBottom,
      ),
      child: _FloatingBar(
        destinations: destinations,
        selectedIndex: selectedIndex,
        onDestinationSelected: onDestinationSelected,
        availableWidth: availableWidth,
      ),
    );
  }
}

class _FloatingBar extends StatefulWidget {
  const _FloatingBar({
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.availableWidth,
  });

  final List<OneBitNavigationDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final double availableWidth;

  @override
  State<_FloatingBar> createState() => _FloatingBarState();
}

class _FloatingBarState extends State<_FloatingBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _anim;
  final _itemKeys = <GlobalKey>[];

  Rect? _fromRect;
  Rect? _toRect;
  Rect? _currentRect;

  @override
  void initState() {
    super.initState();
    _itemKeys.addAll(
      List.generate(widget.destinations.length, (_) => GlobalKey()),
    );
    _animController = AnimationController(
      vsync: this,
      duration: OneBitMotion.medium,
    );
    _anim = CurvedAnimation(
      parent: _animController,
      curve: OneBitMotion.emphasized,
    );
    _anim.addListener(_onAnimTick);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateSelectedRect());
  }

  @override
  void didUpdateWidget(covariant _FloatingBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _fromRect = _currentRect;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _updateSelectedRect();
        if (_fromRect != null && _toRect != null) {
          _animController.forward(from: 0);
        }
      });
    }
  }

  void _onAnimTick() {
    setState(() {
      if (_fromRect != null && _toRect != null) {
        _currentRect = Rect.lerp(_fromRect, _toRect, _anim.value);
      }
    });
  }

  void _updateSelectedRect() {
    final key = _itemKeys[widget.selectedIndex];
    final ctx = key.currentContext;
    if (ctx == null) return;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null) return;
    final stackBox = context.findRenderObject() as RenderBox?;
    if (stackBox == null) return;
    final pos = box.localToGlobal(Offset.zero, ancestor: stackBox);
    final rect = Rect.fromLTWH(pos.dx, pos.dy, box.size.width, box.size.height);
    _toRect = rect;
    _currentRect = rect;
  }

  @override
  void dispose() {
    _anim.removeListener(_onAnimTick);
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<OneBitThemeExtension>()!;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final dim = _FloatingNavDimensions.calculate(
      itemCount: widget.destinations.length,
      availableWidth: widget.availableWidth,
    );

    return SizedBox(
      width: widget.availableWidth,
      height: dim.capsuleHeight,
      child: DecoratedBox(
        decoration: _barDecoration(colors, dim),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Animated selection pill
            if (_currentRect != null && !reduceMotion)
              Positioned(
                left: _currentRect!.left,
                top: _currentRect!.top,
                width: _currentRect!.width,
                height: _currentRect!.height,
                child: _SelectionPill(dim: dim),
              ),
            // Static pill for initial frame / reduced motion
            if (_currentRect != null && reduceMotion)
              Positioned(
                left: _toRect?.left ?? _currentRect!.left,
                top: _toRect?.top ?? _currentRect!.top,
                width: _toRect?.width ?? _currentRect!.width,
                height: _toRect?.height ?? _currentRect!.height,
                child: _SelectionPill(dim: dim),
              ),
            // Nav items
            Padding(
              padding: EdgeInsets.all(dim.itemPadding),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (int i = 0; i < widget.destinations.length; i++)
                    _FloatingNavItem(
                      key: _itemKeys[i],
                      destination: widget.destinations[i],
                      isSelected: i == widget.selectedIndex,
                      onTap: () => widget.onDestinationSelected(i),
                      dim: dim,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  BoxDecoration _barDecoration(
    OneBitThemeExtension colors,
    _FloatingNavDimensions dim,
  ) {
    return BoxDecoration(
      color: colors.surfaceElevated,
      borderRadius: BorderRadius.circular(dim.capsuleRadius),
      border: Border.all(color: colors.border, width: 1),
      boxShadow: const [OneBitElevation.navigation],
    );
  }
}

class _SelectionPill extends StatelessWidget {
  const _SelectionPill({required this.dim});

  final _FloatingNavDimensions dim;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(OneBitRadius.xxl),
        border: Border.all(
          color: primary.withValues(alpha: 0.18),
          width: 1.5,
        ),
      ),
    );
  }
}

class _FloatingNavItem extends StatelessWidget {
  const _FloatingNavItem({
    required this.destination,
    required this.isSelected,
    required this.onTap,
    required this.dim,
    super.key,
  });

  final OneBitNavigationDestination destination;
  final bool isSelected;
  final VoidCallback onTap;
  final _FloatingNavDimensions dim;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<OneBitThemeExtension>()!;
    final iconColor = isSelected ? colors.selectedIcon : colors.iconSecondary;

    return SizedBox(
      width: dim.itemWidth,
      height: dim.itemHeight,
      child: Semantics(
        button: true,
        selected: isSelected,
        label: isSelected
            ? '${destination.label}, selected'
            : '${destination.label}, not selected',
        child: Tooltip(
          message: destination.label,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(OneBitRadius.xxl),
            child: Center(
              child: AnimatedSwitcher(
                duration: OneBitMotion.resolve(
                  context,
                  OneBitMotion.fast,
                ),
                transitionBuilder: (child, animation) {
                  return ScaleTransition(scale: animation, child: child);
                },
                child: Icon(
                  isSelected ? destination.selectedIcon : destination.icon,
                  key: ValueKey(
                    '${destination.id}-${isSelected ? "sel" : "unsel"}',
                  ),
                  size: dim.iconSize,
                  color: iconColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pre-computed dimensions for the floating navigation layout.
class _FloatingNavDimensions {
  const _FloatingNavDimensions({
    required this.capsuleHeight,
    required this.capsuleRadius,
    required this.itemWidth,
    required this.itemHeight,
    required this.itemPadding,
    required this.iconSize,
  });

  /// Layout from item count and available width.
  factory _FloatingNavDimensions.calculate({
    required int itemCount,
    required double availableWidth,
  }) {
    const capsuleHeight = 60.0;
    const capsuleRadius = 28.0;
    const iconSize = 24.0;
    const itemPadding = 6.0;
    const minItemWidth = 48.0;
    const maxItemWidth = 72.0;

    final innerWidth = availableWidth - (itemPadding * 2);
    final rawItemWidth = innerWidth / itemCount;
    final itemWidth = rawItemWidth.clamp(minItemWidth, maxItemWidth);

    return _FloatingNavDimensions(
      capsuleHeight: capsuleHeight,
      capsuleRadius: capsuleRadius,
      itemWidth: itemWidth,
      itemHeight: capsuleHeight - (itemPadding * 2),
      itemPadding: itemPadding,
      iconSize: iconSize,
    );
  }

  final double capsuleHeight;
  final double capsuleRadius;
  final double itemWidth;
  final double itemHeight;
  final double itemPadding;
  final double iconSize;
}
