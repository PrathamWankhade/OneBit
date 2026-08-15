import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:onebit/core/extensions/build_context_extensions.dart';
import 'package:onebit/core/widgets/onebit_scaffold.dart';
import 'package:onebit/features/identity/domain/user_profile.dart';
import 'package:onebit/features/identity/presentation/identity_controller.dart';
import 'package:onebit/features/launch/domain/display_name_validator.dart';
import 'package:onebit/shared/design_system/components/onebit_button.dart';
import 'package:onebit/shared/design_system/components/onebit_inline_error.dart';
import 'package:onebit/shared/design_system/components/onebit_snackbar.dart';
import 'package:onebit/shared/design_system/components/onebit_technical_field.dart';
import 'package:onebit/shared/design_system/components/onebit_text_field.dart';
import 'package:onebit/shared/design_system/spacing/onebit_spacing.dart';

/// Profile settings: edit the display name.
///
/// The display name is presentation metadata — editing it only updates the
/// profile through [IdentityController.updateProfile]; the Node ID and
/// cryptographic material are never touched.
class ProfileSettingsScreen extends ConsumerStatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  ConsumerState<ProfileSettingsScreen> createState() =>
      _ProfileSettingsScreenState();
}

final class _ProfileSettingsScreenState
    extends ConsumerState<ProfileSettingsScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _nodeIdController;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final identity = ref.read(identityControllerProvider).value;
    _nameController = TextEditingController(
      text: identity?.profile.displayName ?? '',
    );
    _nodeIdController = TextEditingController(
      text: identity?.nodeId.value ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nodeIdController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final validation = DisplayNameValidator.validate(_nameController.text);
      if (!validation.isValid) {
        if (mounted) {
          setState(() => _error = _messageFor(validation.issue));
        }
        return;
      }
      final identity = await ref.read(identityControllerProvider.future);
      if (identity == null || !mounted) return;
      await ref
          .read(identityControllerProvider.notifier)
          .updateProfile(
            UserProfile(
              displayName: validation.normalized,
              avatarColor: identity.profile.avatarColor,
            ),
          );
      if (!mounted) return;
      OneBitSnackBars.success(context, message: context.l10n.profileSaved);
      context.pop();
    } on Object {
      if (mounted) {
        setState(() => _error = context.l10n.profileError);
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
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

    return OneBitScaffold(
      appBar: AppBar(title: Text(l10n.profileTitle)),
      body: ListView(
        padding: const EdgeInsets.all(OneBitSpacing.m),
        children: [
          OneBitTechnicalField(
            controller: _nodeIdController,
            label: l10n.nodeIdLabel,
            enabled: false,
          ),
          const SizedBox(height: OneBitSpacing.l),
          OneBitTextField(
            controller: _nameController,
            label: l10n.profileDisplayNameLabel,
            hint: l10n.profileDisplayNameHint,
            textInputAction: TextInputAction.done,
            enabled: !_saving,
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onSubmitted: (_) => _save(),
          ),
          if (_error != null) ...[
            const SizedBox(height: OneBitSpacing.m),
            OneBitInlineError(message: _error!),
          ],
          const SizedBox(height: OneBitSpacing.s),
          Text(l10n.profileNote, style: context.textTheme.bodySmall),
          const SizedBox(height: OneBitSpacing.xl),
          OneBitButton(
            label: l10n.profileSave,
            onPressed: _saving ? null : _save,
            loading: _saving,
          ),
        ],
      ),
    );
  }
}
