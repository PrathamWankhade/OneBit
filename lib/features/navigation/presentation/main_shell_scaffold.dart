import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:onebit/core/theme/app_theme.dart';
import 'package:onebit/features/navigation/presentation/floating_nav_bar.dart';

/// Shell scaffold with floating nav bar and contextual FAB.
///
/// 3 tabs: Chats, Nearby, Identity.
/// FAB (compose) only visible on Chats tab.
/// Supports swipe gestures and slide transitions between tabs.
class MainShellScaffold extends StatefulWidget {
  const MainShellScaffold({
    super.key,
    required this.navigationShell,
    required this.onCenterAction,
  });

  final StatefulNavigationShell navigationShell;
  final VoidCallback onCenterAction;

  @override
  State<MainShellScaffold> createState() => _MainShellScaffoldState();
}

class _MainShellScaffoldState extends State<MainShellScaffold>
    with SingleTickerProviderStateMixin {
  double _dragStartX = 0;
  bool _isDragging = false;
  late final AnimationController _slideController;
  late final Animation<Offset> _slideAnimation;

  static const int _chatsTabIndex = 0;
  static const int _tabCount = 3;

  int get _currentIndex => widget.navigationShell.currentIndex;
  bool get _showFab => _currentIndex == _chatsTabIndex;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.08, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOut,
    ));
    _slideController.value = 1.0;
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  void _onTap(int index) {
    if (index == _currentIndex) return;
    _slideController.forward(from: 0.0);
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  void _onHorizontalDragStart(DragStartDetails details) {
    _dragStartX = details.globalPosition.dx;
    _isDragging = true;
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {}

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (!_isDragging) return;
    _isDragging = false;

    final delta = details.globalPosition.dx - _dragStartX;
    final velocity = details.primaryVelocity ?? 0;
    final isSwipe = delta.abs() > 50 || velocity.abs() > 300;

    if (!isSwipe) return;

    if (delta > 0 && _currentIndex > 0) {
      _onTap(_currentIndex - 1);
    } else if (delta < 0 && _currentIndex < _tabCount - 1) {
      _onTap(_currentIndex + 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onHorizontalDragStart: _onHorizontalDragStart,
        onHorizontalDragUpdate: _onHorizontalDragUpdate,
        onHorizontalDragEnd: _onHorizontalDragEnd,
        child: SlideTransition(
          position: _slideAnimation,
          child: widget.navigationShell,
        ),
      ),
      bottomNavigationBar: FloatingNavBar(
        currentIndex: _currentIndex,
        onTap: _onTap,
        items: const [
          NavBarItem(
            icon: Icons.chat_bubble_outline,
            activeIcon: Icons.chat_bubble,
            label: 'Chats',
          ),
          NavBarItem(
            icon: Icons.location_searching_outlined,
            activeIcon: Icons.location_searching,
            label: 'Nearby',
          ),
          NavBarItem(
            icon: Icons.vpn_key_outlined,
            activeIcon: Icons.vpn_key,
            label: 'Identity',
          ),
        ],
      ),
      floatingActionButton: _showFab
          ? FloatingActionButton(
              onPressed: widget.onCenterAction,
              backgroundColor: AppTheme.accent,
              foregroundColor: AppTheme.bgBase,
              child: const Icon(Icons.edit),
            )
          : null,
    );
  }
}
