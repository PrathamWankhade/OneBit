import 'package:flutter/material.dart';
import 'package:onebit/core/theme/app_theme.dart';

/// F9 — Image message bubble.
///
/// Shows image preview (max 260×200px, 12px radius) with optional caption.
/// States: loading (skeleton), loaded, failed (retry overlay), sending.
enum ImageMessageState { loading, loaded, failed, sending }

class ImageMessageBubble extends StatelessWidget {
  const ImageMessageBubble({
    required this.isReceived,
    this.imagePath,
    this.imageUrl,
    this.caption,
    this.state = ImageMessageState.loaded,
    this.timestamp,
    this.status = 'sent',
    this.onTap,
    this.onRetry,
    super.key,
  });

  final bool isReceived;
  final String? imagePath;
  final String? imageUrl;
  final String? caption;
  final ImageMessageState state;
  final DateTime? timestamp;
  final String status;
  final VoidCallback? onTap;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isReceived ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.75,
        ),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          crossAxisAlignment:
              isReceived ? CrossAxisAlignment.start : CrossAxisAlignment.end,
          children: [
            // Image container
            GestureDetector(
              onTap: state == ImageMessageState.loaded ? onTap : null,
              child: Container(
                constraints: const BoxConstraints(
                  maxWidth: 260,
                  maxHeight: 200,
                ),
                decoration: BoxDecoration(
                  color: isReceived ? AppTheme.bgElevated : AppTheme.accentMuted,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(12),
                    topRight: const Radius.circular(12),
                    bottomLeft: Radius.circular(isReceived ? 4 : 12),
                    bottomRight: Radius.circular(isReceived ? 12 : 4),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _buildImageContent(),
                ),
              ),
            ),

            // Caption
            if (caption != null && caption!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  caption!,
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),

            // Timestamp + status
            if (timestamp != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatTime(timestamp!),
                      style: AppTheme.caption.copyWith(
                        color: AppTheme.textTertiary,
                      ),
                    ),
                    if (!isReceived) ...[
                      const SizedBox(width: 4),
                      _StatusIcon(status: status),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageContent() {
    switch (state) {
      case ImageMessageState.loading:
        return _LoadingSkeleton();
      case ImageMessageState.loaded:
        return _LoadedImage(imagePath: imagePath, imageUrl: imageUrl);
      case ImageMessageState.failed:
        return _FailedImage(onRetry: onRetry);
      case ImageMessageState.sending:
        return _SendingImage(imagePath: imagePath, imageUrl: imageUrl);
    }
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _LoadingSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      height: 180,
      color: AppTheme.bgOverlay,
      child: const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppTheme.accent,
        ),
      ),
    );
  }
}

class _LoadedImage extends StatelessWidget {
  const _LoadedImage({this.imagePath, this.imageUrl});

  final String? imagePath;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    // In production, use CachedNetworkImage or File image.
    // Here we show a placeholder.
    return Container(
      width: 260,
      height: 180,
      color: AppTheme.bgOverlay,
      alignment: Alignment.center,
      child: const Icon(
        Icons.image_outlined,
        size: 48,
        color: AppTheme.textTertiary,
      ),
    );
  }
}

class _FailedImage extends StatelessWidget {
  const _FailedImage({this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onRetry,
      child: Container(
        width: 260,
        height: 180,
        color: AppTheme.bgOverlay,
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 32,
              color: AppTheme.red,
            ),
            const SizedBox(height: 8),
            Text(
              'Failed to load',
              style: AppTheme.caption.copyWith(color: AppTheme.textTertiary),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap to retry',
              style: AppTheme.caption.copyWith(color: AppTheme.accent),
            ),
          ],
        ),
      ),
    );
  }
}

class _SendingImage extends StatelessWidget {
  const _SendingImage({this.imagePath, this.imageUrl});

  final String? imagePath;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 260,
          height: 180,
          color: AppTheme.bgOverlay,
          alignment: Alignment.center,
          child: const Icon(
            Icons.image_outlined,
            size: 48,
            color: AppTheme.textTertiary,
          ),
        ),
        Container(
          width: 260,
          height: 180,
          color: AppTheme.bgBase.withValues(alpha: 0.5),
          child: const Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppTheme.accent,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case 'sending':
        return const Icon(Icons.access_time, size: 12, color: AppTheme.textTertiary);
      case 'sent':
        return const Icon(Icons.done, size: 12, color: AppTheme.textTertiary);
      case 'delivered':
        return const Icon(Icons.done_all, size: 12, color: AppTheme.textTertiary);
      case 'read':
        return const Icon(Icons.done_all, size: 12, color: AppTheme.accent);
      case 'failed':
        return const Icon(Icons.error_outline, size: 12, color: AppTheme.red);
      default:
        return const SizedBox.shrink();
    }
  }
}
