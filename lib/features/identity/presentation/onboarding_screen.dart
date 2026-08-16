import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/core/extensions/build_context_extensions.dart';
import 'package:onebit/core/widgets/onebit_scaffold.dart';
import 'package:onebit/features/identity/presentation/identity_controller.dart';
import 'package:onebit/shared/design_system/components/onebit_button.dart';
import 'package:onebit/shared/design_system/components/onebit_inline_error.dart';
import 'package:onebit/shared/design_system/components/onebit_scroll_clearance.dart';
import 'package:onebit/shared/design_system/components/onebit_text_field.dart';
import 'package:onebit/shared/design_system/spacing/onebit_spacing.dart';

/// First-run onboarding: creates the node identity.
///
/// The router only lands here when no identity exists yet. Once
/// [IdentityController.create] succeeds, the identity provider updates and
/// the route guard redirects into the shell automatically.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

final class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final TextEditingController _nameController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool get _canCreate => !_submitting && _nameController.text.trim().isNotEmpty;

  Future<void> _create() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref
          .read(identityControllerProvider.notifier)
          .create(displayName: _nameController.text.trim(), avatarColor: 0);
    } on Object {
      if (mounted) {
        setState(() => _error = context.l10n.onboardingError);
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return OneBitScaffold(
      appBar: AppBar(title: Text(l10n.onboardingTitle)),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          OneBitSpacing.m,
          OneBitSpacing.m,
          OneBitSpacing.m,
          OneBitScrollClearance.bottom(context),
        ),
        children: [
          const SizedBox(height: OneBitSpacing.l),
          Text(l10n.onboardingTitle, style: context.textTheme.headlineMedium),
          const SizedBox(height: OneBitSpacing.s),
          Text(l10n.onboardingSubtitle, style: context.textTheme.bodyMedium),
          const SizedBox(height: OneBitSpacing.xl),
          OneBitTextField(
            controller: _nameController,
            label: l10n.onboardingDisplayNameLabel,
            hint: l10n.onboardingDisplayNameHint,
            textInputAction: TextInputAction.done,
            enabled: !_submitting,
            onChanged: (_) => setState(() {}),
          ),
          if (_error != null) ...[
            const SizedBox(height: OneBitSpacing.m),
            OneBitInlineError(message: _error!),
          ],
          const SizedBox(height: OneBitSpacing.xl),
          OneBitButton(
            label: l10n.onboardingCreateIdentity,
            onPressed: _canCreate ? _create : null,
            loading: _submitting,
          ),
        ],
      ),
    );
  }
}
