import 'package:flutter/material.dart';
import 'package:onebit/core/theme/app_theme.dart';

/// F9 — Full-screen media viewer.
///
/// Pinch to zoom, swipe for multi-image, tap to toggle chrome.
/// Actions: back, info, more, share, save, forward.
class MediaViewer extends StatefulWidget {
  const MediaViewer({
    this.imagePath,
    this.imageUrl,
    this.senderName,
    this.sentAt,
    this.fileSize,
    this.initialIndex = 0,
    this.imageCount = 1,
    super.key,
  });

  final String? imagePath;
  final String? imageUrl;
  final String? senderName;
  final DateTime? sentAt;
  final String? fileSize;
  final int initialIndex;
  final int imageCount;

  @override
  State<MediaViewer> createState() => _MediaViewerState();
}

class _MediaViewerState extends State<MediaViewer> {
  bool _showChrome = true;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgBase,
      body: GestureDetector(
        onTap: () => setState(() => _showChrome = !_showChrome),
        child: Stack(
          children: [
            // Image viewer
            PageView.builder(
              controller: _pageController,
              itemCount: widget.imageCount,
              itemBuilder: (context, index) => Center(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: _buildImage(),
                ),
              ),
            ),

            // Top bar
            if (_showChrome)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _TopBar(
                  onBack: () => Navigator.of(context).pop(),
                  onInfo: () {},
                  onMore: () {},
                ),
              ),

            // Bottom bar
            if (_showChrome)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _BottomBar(
                  senderName: widget.senderName,
                  sentAt: widget.sentAt,
                  fileSize: widget.fileSize,
                  onShare: () {},
                  onSave: () {},
                  onForward: () {},
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage() {
    // In production, use CachedNetworkImage or File image.
    // Here we show a placeholder.
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: AppTheme.bgBase,
      alignment: Alignment.center,
      child: const Icon(
        Icons.image_outlined,
        size: 64,
        color: AppTheme.textTertiary,
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.onBack,
    required this.onInfo,
    required this.onMore,
  });

  final VoidCallback onBack;
  final VoidCallback onInfo;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppTheme.bgBase, Colors.transparent],
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            onPressed: onBack,
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.info_outline, size: 20),
            onPressed: onInfo,
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, size: 20),
            onPressed: onMore,
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    this.senderName,
    this.sentAt,
    this.fileSize,
    required this.onShare,
    required this.onSave,
    required this.onForward,
  });

  final String? senderName;
  final DateTime? sentAt;
  final String? fileSize;
  final VoidCallback onShare;
  final VoidCallback onSave;
  final VoidCallback onForward;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [AppTheme.bgBase, Colors.transparent],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Info row
          if (senderName != null || sentAt != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    'Sent by ${senderName ?? "Unknown"}',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  if (sentAt != null) ...[
                    Text(
                      ' · ${_formatDate(sentAt!)}',
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          if (fileSize != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    'Encrypted · $fileSize',
                    style: AppTheme.caption.copyWith(
                      color: AppTheme.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),

          // Action row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _ActionButton(
                  icon: Icons.share,
                  label: 'Share',
                  onTap: onShare,
                ),
                _ActionButton(
                  icon: Icons.download,
                  label: 'Save',
                  onTap: onSave,
                ),
                _ActionButton(
                  icon: Icons.reply,
                  label: 'Forward',
                  onTap: onForward,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 24, color: AppTheme.textPrimary),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTheme.caption.copyWith(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}
