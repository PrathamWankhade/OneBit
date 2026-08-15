import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/core/extensions/build_context_extensions.dart';
import 'package:onebit/core/widgets/onebit_scaffold.dart';
import 'package:onebit/features/launch/domain/display_name_validator.dart';
import 'package:onebit/features/launch/presentation/launch_providers.dart';
import 'package:onebit/features/launch/presentation/launch_theme.dart';
import 'package:onebit/shared/design_system/colors/onebit_color_schemes.dart';
import 'package:onebit/shared/design_system/components/onebit_button.dart';
import 'package:onebit/shared/design_system/components/onebit_inline_error.dart';
import 'package:onebit/shared/design_system/components/onebit_text_field.dart';
import 'package:onebit/shared/design_system/spacing/onebit_spacing.dart';
import 'package:onebit/shared/design_system/typography/onebit_typography.dart';

/// First-run display-name setup.
///
/// The name is local presentation metadata (never an account): it is
/// persisted through the existing identity use cases — on a fresh node
/// creating the identity stores it; otherwise only the profile updates,
/// never the Node ID or keys.
///
/// The system back gesture returns to the intro stage; the keyboard "Done"
/// action submits when the name is valid.
class DisplayNameSetupScreen extends ConsumerStatefulWidget {
  const DisplayNameSetupScreen({super.key});

  @override
  ConsumerState<DisplayNameSetupScreen> createState() =>
      _DisplayNameSetupScreenState();
}

final class _DisplayNameSetupScreenState
    extends ConsumerState<DisplayNameSetupScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final issue = await ref
          .read(launchControllerProvider.notifier)
          .submitDisplayName(_controller.text);
      if (issue != null && issue != DisplayNameIssue.none && mounted) {
        setState(() => _error = _messageFor(issue));
      }
    } on Object {
      if (mounted) {
        setState(() => _error = context.l10n.displayNameSaveError);
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  String _messageFor(DisplayNameIssue issue) {
    final l10n = context.l10n;
    return switch (issue) {
      DisplayNameIssue.empty => l10n.displayNameEmpty,
      DisplayNameIssue.tooLong => l10n.displayNameTooLong(
        DisplayNameRules.maxLength,
      ),
      DisplayNameIssue.controlCharacters => l10n.displayNameControlCharacters,
      DisplayNameIssue.invalidUnicode => l10n.displayNameInvalidUnicode,
      DisplayNameIssue.none => '',
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.oneBitColors;

    return PopScope(
      // The back gesture navigates the state machine back to intro instead
      // of leaving the route to the system.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        ref.read(launchControllerProvider.notifier).returnToIntro();
      },
      child: LaunchTheme(
        child: OneBitScaffold(
          body: Padding(
            padding: const EdgeInsets.all(OneBitSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(flex: 2),
                Text(
                  l10n.displayNameTitle,
                  style: context.textTheme.headlineMedium,
                ),
                const SizedBox(height: OneBitSpacing.s),
                Text(
                  l10n.displayNameSubtitle,
                  style: context.textTheme.bodyMedium,
                ),
                const SizedBox(height: OneBitSpacing.xl),
                OneBitTextField(
                  controller: _controller,
                  hint: l10n.displayNameHint,
                  textInputAction: TextInputAction.done,
                  enabled: !_submitting,
                  autofocus: true,
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: OneBitSpacing.m),
                if (_error != null) OneBitInlineError(message: _error!),
                const Spacer(flex: 3),
                Text(
                  l10n.displayNamePrivacy,
                  textAlign: TextAlign.center,
                  style: OneBitTypography.technicalStyle(
                    fontSize: OneBitTypography.caption,
                    color: colors.ansiBrightBlack,
                  ),
                ),
                const SizedBox(height: OneBitSpacing.m),
                OneBitButton(
                  label: l10n.commonContinue,
                  onPressed: _submitting ? null : _submit,
                  loading: _submitting,
                ),
                const SizedBox(height: OneBitSpacing.xl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
