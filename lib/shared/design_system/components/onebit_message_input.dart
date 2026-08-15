import 'package:flutter/material.dart';
import 'package:onebit/shared/design_system/components/onebit_icon_button.dart';
import 'package:onebit/shared/design_system/icons/onebit_icons.dart';
import 'package:onebit/shared/design_system/spacing/onebit_spacing.dart';
import 'package:onebit/shared/design_system/tokens/onebit_component_tokens.dart';

/// Message composer foundation (single-line, enter-to-send).
///
/// Presentation-only: the caller owns the controller, localizes the hint and
/// handles [onSend]. The send action stays disabled while the field is
/// empty, the widget is disabled, or [sending] is true.
class OneBitMessageInput extends StatefulWidget {
  const OneBitMessageInput({
    required this.controller,
    required this.onSend,
    this.hintText,
    this.onChanged,
    this.enabled = true,
    this.sending = false,
    this.sendTooltip,
    super.key,
  });

  /// Controlled text value.
  final TextEditingController controller;

  /// Called with the draft on send; called only when non-empty.
  final ValueChanged<String> onSend;

  /// Placeholder text.
  final String? hintText;

  /// Fired on every edit.
  final ValueChanged<String>? onChanged;

  /// Disables the whole composer.
  final bool enabled;

  /// Shows an in-field progress state and disables sending.
  final bool sending;

  /// Semantic label for the send action; callers localize.
  final String? sendTooltip;

  @override
  State<OneBitMessageInput> createState() => _OneBitMessageInputState();
}

final class _OneBitMessageInputState extends State<OneBitMessageInput> {
  bool _empty = true;

  @override
  void initState() {
    super.initState();
    _empty = widget.controller.text.isEmpty;
    widget.controller.addListener(_sync);
  }

  @override
  void didUpdateWidget(OneBitMessageInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller.removeListener(_sync);
      widget.controller.addListener(_sync);
      _sync();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_sync);
    super.dispose();
  }

  void _sync() => setState(() => _empty = widget.controller.text.isEmpty);

  void _submit(String value) {
    if (!_empty && widget.enabled && !widget.sending) widget.onSend(value);
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.enabled && !widget.sending;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: TextField(
            controller: widget.controller,
            enabled: active,
            onChanged: (value) {
              _sync();
              widget.onChanged?.call(value);
            },
            onSubmitted: _submit,
            textInputAction: TextInputAction.send,
            maxLines: 1,
            decoration: InputDecoration(hintText: widget.hintText),
          ),
        ),
        const SizedBox(width: OneBitSpacing.xs),
        if (widget.sending)
          const Padding(
            padding: EdgeInsets.all(12),
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          )
        else
          OneBitIconButton(
            icon: OneBitIcons.send,
            onPressed: _empty ? null : () => _submit(widget.controller.text),
            tooltip: widget.sendTooltip,
            size: OneBitIconSize.m,
          ),
      ],
    );
  }
}
