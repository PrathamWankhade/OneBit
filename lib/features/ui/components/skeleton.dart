import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:onebit/core/theme/app_theme.dart';

/// Reusable shimmer skeleton widget for loading states.
class SkeletonShimmer extends StatelessWidget {
  const SkeletonShimmer({
    required this.child,
    this.baseColor,
    this.highlightColor,
    super.key,
  });

  final Widget child;
  final Color? baseColor;
  final Color? highlightColor;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: baseColor ?? AppTheme.bgElevated,
      highlightColor: highlightColor ?? AppTheme.bgOverlay,
      child: child,
    );
  }
}

/// Skeleton circle for avatars.
class SkeletonCircle extends StatelessWidget {
  const SkeletonCircle({required this.size, this.baseColor, super.key});

  final double size;
  final Color? baseColor;

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      baseColor: baseColor,
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: AppTheme.bgMuted,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

/// Skeleton line for text placeholders.
class SkeletonLine extends StatelessWidget {
  const SkeletonLine({
    required this.width,
    required this.height,
    this.borderRadius,
    this.baseColor,
    super.key,
  });

  final double width;
  final double height;
  final BorderRadius? borderRadius;
  final Color? baseColor;

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      baseColor: baseColor,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppTheme.bgMuted,
          borderRadius: borderRadius ?? BorderRadius.circular(4),
        ),
      ),
    );
  }
}

/// Full skeleton for conversation list item.
class ConversationSkeleton extends StatelessWidget {
  const ConversationSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: const Row(
        children: [
          SkeletonCircle(size: 52),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SkeletonLine(width: 120, height: 16),
                    Spacer(),
                    SkeletonLine(width: 40, height: 12),
                  ],
                ),
                SizedBox(height: 10),
                SkeletonLine(width: 180, height: 13),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Full skeleton for chat message bubble.
class MessageSkeleton extends StatelessWidget {
  const MessageSkeleton({required this.isReceived, super.key});

  final bool isReceived;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isReceived ? Alignment.centerLeft : Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: SkeletonShimmer(
          child: Container(
            width: MediaQuery.sizeOf(context).width * 0.65,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isReceived ? AppTheme.bgElevated : AppTheme.accentMuted,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isReceived ? 4 : 16),
                bottomRight: Radius.circular(isReceived ? 16 : 4),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonLine(
                  width: 160,
                  height: 14,
                  borderRadius: BorderRadius.circular(2),
                ),
                const SizedBox(height: 8),
                SkeletonLine(
                  width: 100,
                  height: 14,
                  borderRadius: BorderRadius.circular(2),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: SkeletonLine(
                    width: 50,
                    height: 10,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Chat screen skeleton with mixed messages.
class ChatSkeleton extends StatelessWidget {
  const ChatSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: 8,
      itemBuilder: (context, index) {
        final isReceived = index.isEven;
        return MessageSkeleton(isReceived: isReceived);
      },
    );
  }
}

/// Conversation list skeleton with multiple items.
class ConversationListSkeleton extends StatelessWidget {
  const ConversationListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: 6,
      itemBuilder: (context, index) => const ConversationSkeleton(),
    );
  }
}
