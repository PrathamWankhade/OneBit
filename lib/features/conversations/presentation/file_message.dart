import 'package:flutter/material.dart';
import 'package:onebit/core/theme/app_theme.dart';

/// F9 — File message bubble.
///
/// 72px height, bg-elevated, 8px radius.
/// File icon 32px (color by type), filename, size, progress bar, action button.
enum FileMessageType { pdf, document, spreadsheet, presentation, archive, code, other }

enum FileTransferState { waiting, transferring, complete, failed, paused }

class FileMessageBubble extends StatelessWidget {
  const FileMessageBubble({
    required this.fileName,
    required this.fileSize,
    required this.isReceived,
    this.fileType = FileMessageType.other,
    this.transferState = FileTransferState.complete,
    this.progress = 0.0,
    this.timestamp,
    this.status = 'sent',
    this.onTap,
    this.onAction,
    super.key,
  });

  final String fileName;
  final String fileSize;
  final bool isReceived;
  final FileMessageType fileType;
  final FileTransferState transferState;
  final double progress;
  final DateTime? timestamp;
  final String status;
  final VoidCallback? onTap;
  final VoidCallback? onAction;

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
            // File container
            GestureDetector(
              onTap: onTap,
              child: Container(
                height: 72,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isReceived ? AppTheme.bgElevated : AppTheme.accentMuted,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(8),
                    topRight: const Radius.circular(8),
                    bottomLeft: Radius.circular(isReceived ? 4 : 8),
                    bottomRight: Radius.circular(isReceived ? 8 : 4),
                  ),
                ),
                child: Row(
                  children: [
                    // File icon
                    _FileIcon(type: fileType),
                    const SizedBox(width: 12),

                    // File info
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fileName,
                            style: AppTheme.bodyMedium.copyWith(
                              color: AppTheme.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            fileSize,
                            style: AppTheme.caption.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Action button
                    _ActionButton(
                      state: transferState,
                      onTap: onAction,
                    ),
                  ],
                ),
              ),
            ),

            // Progress bar (during transfer)
            if (transferState == FileTransferState.transferring)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: SizedBox(
                  width: 200,
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: AppTheme.bgMuted,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accent),
                    minHeight: 2,
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

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _FileIcon extends StatelessWidget {
  const _FileIcon({required this.type});

  final FileMessageType type;

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;

    switch (type) {
      case FileMessageType.pdf:
        icon = Icons.picture_as_pdf;
        color = AppTheme.red;
      case FileMessageType.document:
        icon = Icons.description_outlined;
        color = AppTheme.blue;
      case FileMessageType.spreadsheet:
        icon = Icons.table_chart_outlined;
        color = AppTheme.green;
      case FileMessageType.presentation:
        icon = Icons.slideshow_outlined;
        color = AppTheme.amber;
      case FileMessageType.archive:
        icon = Icons.archive_outlined;
        color = AppTheme.textSecondary;
      case FileMessageType.code:
        icon = Icons.code;
        color = AppTheme.purple;
      case FileMessageType.other:
        icon = Icons.attach_file;
        color = AppTheme.textSecondary;
    }

    return Icon(icon, size: 32, color: color);
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.state, this.onTap});

  final FileTransferState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    String label;
    Color color;

    switch (state) {
      case FileTransferState.waiting:
        label = 'Waiting...';
        color = AppTheme.textTertiary;
      case FileTransferState.transferring:
        label = '${(0 * 100).toInt()}%';
        color = AppTheme.accent;
      case FileTransferState.complete:
        label = 'Open';
        color = AppTheme.accent;
      case FileTransferState.failed:
        label = 'Retry';
        color = AppTheme.red;
      case FileTransferState.paused:
        label = 'Resume';
        color = AppTheme.accent;
    }

    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: AppTheme.bodySmall.copyWith(
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
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
