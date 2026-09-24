import 'package:flutter/material.dart';
import 'package:onebit/core/theme/app_theme.dart';

/// WhatsApp-style Attachment menu bottom sheet.
enum AttachmentType {
  gallery,
  camera,
  document,
  location,
  contact,
  poll,
}

/// Shows the attachment bottom sheet and returns the selected type.
Future<AttachmentType?> showAttachmentSheet(BuildContext context) {
  return showModalBottomSheet<AttachmentType>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => const _AttachmentSheet(),
  );
}

class _AttachmentSheet extends StatefulWidget {
  const _AttachmentSheet();

  @override
  State<_AttachmentSheet> createState() => _AttachmentSheetState();
}

class _AttachmentSheetState extends State<_AttachmentSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _close() {
    _controller.reverse().then((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  void _select(AttachmentType type) {
    _controller.reverse().then((_) {
      if (mounted) Navigator.of(context).pop(type);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return GestureDetector(
          onTap: _close,
          child: Container(
            color: Colors.black.withValues(alpha: 0.5 * _fadeAnimation.value),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Transform.scale(
                scale: 0.9 + 0.1 * _scaleAnimation.value,
                child: Opacity(
                  opacity: _fadeAnimation.value,
                  child: _buildSheet(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSheet() {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.bgElevated,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.bgMuted,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),

            // Grid
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                children: [
                  _AttachmentOption(
                    icon: Icons.camera_alt,
                    label: 'Camera',
                    type: AttachmentType.camera,
                    color: AppTheme.purple,
                    delay: 0,
                    controller: _controller,
                    onTap: _select,
                  ),
                  _AttachmentOption(
                    icon: Icons.photo_library,
                    label: 'Gallery',
                    type: AttachmentType.gallery,
                    color: AppTheme.blue,
                    delay: 50,
                    controller: _controller,
                    onTap: _select,
                  ),
                  _AttachmentOption(
                    icon: Icons.description,
                    label: 'Document',
                    type: AttachmentType.document,
                    color: AppTheme.blue,
                    delay: 100,
                    controller: _controller,
                    onTap: _select,
                  ),
                  _AttachmentOption(
                    icon: Icons.location_on,
                    label: 'Location',
                    type: AttachmentType.location,
                    color: AppTheme.green,
                    delay: 150,
                    controller: _controller,
                    onTap: _select,
                  ),
                  _AttachmentOption(
                    icon: Icons.person,
                    label: 'Contact',
                    type: AttachmentType.contact,
                    color: AppTheme.cyan,
                    delay: 200,
                    controller: _controller,
                    onTap: _select,
                  ),
                  _AttachmentOption(
                    icon: Icons.poll,
                    label: 'Poll',
                    type: AttachmentType.poll,
                    color: AppTheme.yellow,
                    delay: 250,
                    controller: _controller,
                    onTap: _select,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _AttachmentOption extends StatelessWidget {
  const _AttachmentOption({
    required this.icon,
    required this.label,
    required this.type,
    required this.color,
    required this.delay,
    required this.controller,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final AttachmentType type;
  final Color color;
  final int delay;
  final AnimationController controller;
  final ValueChanged<AttachmentType> onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final delayMs = delay / 1000.0;
        final animValue = (controller.value - delayMs).clamp(0.0, 1.0);
        final scale = 0.5 + 0.5 * Curves.easeOutBack.transform(animValue);

        return Transform.scale(
          scale: scale,
          child: Opacity(
            opacity: animValue.clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: () => onTap(type),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 24, color: color),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: AppTheme.caption.copyWith(
                color: AppTheme.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
