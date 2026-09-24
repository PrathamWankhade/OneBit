/// I9.3 — Message composer widget.
///
/// A text input with a send button. Handles empty input,
/// creation state, and error display.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/core/theme/app_theme.dart';
import 'package:onebit/features/message/providers/message_providers.dart';

/// Message composer with text input and send button.
///
/// Fires [onSend] when the user submits a valid message.
/// Shows creation loading state and error feedback.
class MessageComposer extends ConsumerStatefulWidget {
  const MessageComposer({
    super.key,
    required this.onSend,
  });

  /// Called when the user sends a valid message.
  final ValueChanged<String> onSend;

  @override
  ConsumerState<MessageComposer> createState() => _MessageComposerState();
}

class _MessageComposerState extends ConsumerState<MessageComposer> {
  final _controller = TextEditingController();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final hasText = _controller.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    widget.onSend(text);

    // Clear input after successful send.
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final composerState = ref.watch(messageComposerProvider);

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 12,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.bgBase,
        border: Border(
          top: BorderSide(
            color: AppTheme.divider,
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (composerState.lastError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                composerState.lastError!,
                style: AppTheme.labelMedium.copyWith(color: AppTheme.red),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  textCapitalization: TextCapitalization.sentences,
                  enabled: !composerState.isCreating,
                  decoration: const InputDecoration(
                    hintText: 'Message...',
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  onSubmitted: (_) => _send(),
                ),
              ),
              const SizedBox(width: 8),
              composerState.isCreating
                  ? const SizedBox(
                      width: 40,
                      height: 40,
                      child: Padding(
                        padding: EdgeInsets.all(8),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton.filled(
                      onPressed: _hasText ? _send : null,
                      icon: const Icon(Icons.send, size: 20),
                    ),
            ],
          ),
        ],
      ),
    );
  }
}
