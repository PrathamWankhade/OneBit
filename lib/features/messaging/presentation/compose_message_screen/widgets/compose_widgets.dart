import 'package:flutter/material.dart';
import 'package:onebit/core/extensions/build_context_extensions.dart';
import 'package:onebit/features/media/attachments/attachment.dart';
import 'package:onebit/features/messaging/presentation/compose_message_controller.dart';
import 'package:onebit/shared/design_system/components/onebit_icon_button.dart';
import 'package:onebit/shared/design_system/icons/onebit_icons.dart';
import 'package:onebit/shared/design_system/spacing/onebit_radius.dart';
import 'package:onebit/shared/design_system/spacing/onebit_spacing.dart';
import 'package:onebit/shared/design_system/tokens/onebit_component_tokens.dart';
import 'package:onebit/shared/design_system/typography/onebit_typography.dart';

/// Banner shown when replying to a message.
final class ReplyBanner extends StatelessWidget {
  const ReplyBanner({
    required this.preview,
    required this.onDismiss,
    super.key,
  });

  final String preview;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(OneBitSpacing.m),
      color: scheme.primaryContainer,
      child: Row(
        children: [
          Icon(OneBitIcons.reply, size: 18, color: scheme.onPrimaryContainer),
          const SizedBox(width: OneBitSpacing.s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.composeReplyingTo,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onPrimaryContainer,
                    fontWeight: OneBitTypography.medium,
                  ),
                ),
                const SizedBox(height: OneBitSpacing.xs),
                Text(
                  preview,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(OneBitIcons.close, size: 20),
            onPressed: onDismiss,
            tooltip: l10n.commonCancel,
            color: scheme.onPrimaryContainer,
          ),
        ],
      ),
    );
  }
}

/// Banner shown when editing a message.
final class EditBanner extends StatelessWidget {
  const EditBanner({required this.onDismiss, super.key});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(OneBitSpacing.m),
      color: scheme.secondaryContainer,
      child: Row(
        children: [
          Icon(OneBitIcons.edit, size: 18, color: scheme.onSecondaryContainer),
          const SizedBox(width: OneBitSpacing.s),
          Expanded(
            child: Text(
              l10n.composeEditingMessage,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: scheme.onSecondaryContainer,
                fontWeight: OneBitTypography.medium,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(OneBitIcons.close, size: 20),
            onPressed: onDismiss,
            tooltip: l10n.commonCancel,
            color: scheme.onSecondaryContainer,
          ),
        ],
      ),
    );
  }
}

/// Horizontal list of attachment preview chips.
final class AttachmentsBar extends StatelessWidget {
  const AttachmentsBar({
    required this.attachments,
    required this.onRemove,
    super.key,
  });

  final List<ComposeAttachment> attachments;
  final ValueChanged<String> onRemove;

  static IconData _iconFor(ComposeAttachment attachment) =>
      switch (attachment.category) {
        MediaCategory.image => OneBitIcons.image,
        MediaCategory.video => OneBitIcons.video,
        MediaCategory.audio => OneBitIcons.audio,
        MediaCategory.voice => OneBitIcons.voiceNote,
        MediaCategory.document => OneBitIcons.document,
        MediaCategory.archive => OneBitIcons.archiveFile,
        MediaCategory.binary => OneBitIcons.binaryFile,
        MediaCategory.custom => OneBitIcons.file,
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(
        horizontal: OneBitSpacing.m,
        vertical: OneBitSpacing.s,
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: attachments.length,
        separatorBuilder: (_, _) => const SizedBox(width: OneBitSpacing.s),
        itemBuilder: (context, index) {
          final attachment = attachments[index];

          return Container(
            padding: const EdgeInsets.symmetric(
              horizontal: OneBitSpacing.m,
              vertical: OneBitSpacing.s,
            ),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(OneBitRadius.md),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _iconFor(attachment),
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: OneBitSpacing.s),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 150),
                  child: Text(
                    attachment.fileName,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: OneBitSpacing.s),
                Semantics(
                  button: true,
                  label: context.l10n.commonDelete,
                  child: InkWell(
                    onTap: () => onRemove(attachment.attachmentId),
                    borderRadius: BorderRadius.circular(OneBitRadius.sm),
                    child: const Padding(
                      padding: EdgeInsets.all(OneBitSpacing.s),
                      child: Icon(
                        OneBitIcons.close,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Voice note attachment bar.
final class VoiceNoteBar extends StatelessWidget {
  const VoiceNoteBar({
    required this.durationMs,
    required this.onRemove,
    super.key,
  });

  final int durationMs;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final seconds = (durationMs / 1000).toStringAsFixed(1);

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: OneBitSpacing.m),
      child: Row(
        children: [
          Icon(OneBitIcons.mic, size: 24, color: scheme.primary),
          const SizedBox(width: OneBitSpacing.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  context.l10n.composeVoiceNoteAttached,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Text(
                  '$seconds s',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Semantics(
            button: true,
            label: context.l10n.commonDelete,
            child: InkWell(
              onTap: onRemove,
              borderRadius: BorderRadius.circular(OneBitRadius.sm),
              child: const Padding(
                padding: EdgeInsets.all(OneBitSpacing.s),
                child: Icon(
                  OneBitIcons.close,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Composer action bar (attach, voice, emoji).
final class ComposerActions extends StatelessWidget {
  const ComposerActions({
    required this.onAttach,
    required this.onVoice,
    required this.onEmoji,
    required this.enabled,
    super.key,
  });

  final VoidCallback onAttach;
  final VoidCallback onVoice;
  final VoidCallback onEmoji;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        OneBitSpacing.m,
        OneBitSpacing.s,
        OneBitSpacing.m,
        OneBitSpacing.m,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          OneBitIconButton(
            icon: OneBitIcons.attachFile,
            onPressed: enabled ? onAttach : null,
            tooltip: l10n.composeAttachFile,
            size: OneBitIconSize.m,
          ),
          const SizedBox(width: OneBitSpacing.s),
          OneBitIconButton(
            icon: OneBitIcons.mic,
            onPressed: enabled ? onVoice : null,
            tooltip: l10n.composeVoiceNote,
            size: OneBitIconSize.m,
          ),
          const Spacer(),
          if (enabled)
            OneBitIconButton(
              icon: OneBitIcons.emoji,
              onPressed: onEmoji,
              tooltip: l10n.composeEmoji,
              size: OneBitIconSize.m,
            ),
        ],
      ),
    );
  }
}

/// Quick emoji insertion sheet.
final class EmojiSheet extends StatelessWidget {
  const EmojiSheet({required this.onSelected, super.key});

  final ValueChanged<String> onSelected;

  static const List<String> _emoji = [
    '😀',
    '😁',
    '😂',
    '😊',
    '😍',
    '🥰',
    '😎',
    '🤔',
    '😅',
    '😢',
    '😡',
    '🙏',
    '👍',
    '👎',
    '👏',
    '🙌',
    '💪',
    '👋',
    '❤️',
    '🔥',
    '✨',
    '🎉',
    '💯',
    '✅',
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(OneBitSpacing.m),
        child: Wrap(
          spacing: OneBitSpacing.xs,
          runSpacing: OneBitSpacing.xs,
          children: [
            for (final emoji in _emoji)
              Semantics(
                button: true,
                label: emoji,
                child: InkWell(
                  onTap: () {
                    onSelected(emoji);
                    Navigator.of(context).pop();
                  },
                  borderRadius: BorderRadius.circular(OneBitRadius.md),
                  child: Padding(
                    padding: const EdgeInsets.all(OneBitSpacing.s),
                    child: Text(emoji, style: const TextStyle(fontSize: 24)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
