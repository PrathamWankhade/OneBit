import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:onebit/core/theme/app_theme.dart';
import 'package:onebit/features/identity/identity_providers.dart';

/// F7 — Edit Profile screen.
///
/// Edit display name and about/bio text for the local identity.
/// Display name: 2–30 characters, alphanumeric + spaces.
/// About/bio: 0–140 characters, free text.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _aboutController;
  late final FocusNode _nameFocus;
  late final FocusNode _aboutFocus;
  bool _isSaving = false;

  static const _maxNameLength = 30;
  static const _maxAboutLength = 140;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _aboutController = TextEditingController();
    _nameFocus = FocusNode();
    _aboutFocus = FocusNode();

    // Load current values after first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final identity = ref.read(localIdentityProvider).valueOrNull;
      if (identity != null) {
        setState(() {
          _nameController.text = identity.displayName;
          _aboutController.text = identity.about ?? '';
        });
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _aboutController.dispose();
    _nameFocus.dispose();
    _aboutFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final identityAsync = ref.watch(localIdentityProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgBase,
      appBar: AppBar(
        backgroundColor: AppTheme.bgBase,
        title: Text(
          'Edit Profile',
          style: AppTheme.titleLarge.copyWith(color: AppTheme.textPrimary),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: Text(
              'Save',
              style: AppTheme.bodyMedium.copyWith(
                color: _isSaving ? AppTheme.textTertiary : AppTheme.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: identityAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.accent),
        ),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppTheme.red),
              const SizedBox(height: 16),
              const Text('Failed to load identity', style: AppTheme.bodyMedium),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => context.pop(),
                child: const Text('Go back'),
              ),
            ],
          ),
        ),
        data: (identity) {
          if (identity == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.warning_amber,
                    size: 48,
                    color: AppTheme.amber,
                  ),
                  const SizedBox(height: 16),
                  const Text('No identity found', style: AppTheme.bodyLarge),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => context.pop(),
                    child: const Text('Go back'),
                  ),
                ],
              ),
            );
          }

          // Sync controllers on first load
          if (_nameController.text.isEmpty &&
              identity.displayName.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _nameController.text = identity.displayName;
                  _aboutController.text = identity.about ?? '';
                });
              }
            });
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar preview
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: const BoxDecoration(
                      color: AppTheme.bgElevated,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _nameController.text.isNotEmpty
                          ? _nameController.text[0].toUpperCase()
                          : '?',
                      style: AppTheme.displayLarge.copyWith(
                        color: AppTheme.accent,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

            // Display name field
            Text(
              'Display name',
              style: AppTheme.caption.copyWith(color: AppTheme.textTertiary),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              focusNode: _nameFocus,
              style: AppTheme.bodyLarge.copyWith(color: AppTheme.textPrimary),
              maxLength: _maxNameLength,
              decoration: InputDecoration(
                hintText: 'Enter display name',
                hintStyle: AppTheme.bodyLarge.copyWith(
                  color: AppTheme.textTertiary,
                ),
                counter: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _nameController,
                  builder: (context, value, _) {
                    return Text(
                      '${value.text.length}/$_maxNameLength',
                      style: AppTheme.caption.copyWith(
                        color: AppTheme.textTertiary,
                      ),
                    );
                  },
                ),
                filled: true,
                fillColor: AppTheme.bgSurface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: AppTheme.textTertiary.withValues(alpha: 0.2),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: AppTheme.textTertiary.withValues(alpha: 0.2),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: AppTheme.accent,
                    width: 1.5,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              onChanged: (_) {},
            ),
            const SizedBox(height: 4),
            Text(
              '2–30 characters. Letters, numbers, and spaces.',
              style: AppTheme.caption.copyWith(color: AppTheme.textTertiary),
            ),
            const SizedBox(height: 24),

            // About/bio field
            Text(
              'About',
              style: AppTheme.caption.copyWith(color: AppTheme.textTertiary),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _aboutController,
              focusNode: _aboutFocus,
              style: AppTheme.bodyLarge.copyWith(color: AppTheme.textPrimary),
              maxLength: _maxAboutLength,
              maxLines: 3,
              minLines: 2,
              decoration: InputDecoration(
                hintText: 'Tell others about yourself',
                hintStyle: AppTheme.bodyLarge.copyWith(
                  color: AppTheme.textTertiary,
                ),
                counter: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _aboutController,
                  builder: (context, value, _) {
                    return Text(
                      '${value.text.length}/$_maxAboutLength',
                      style: AppTheme.caption.copyWith(
                        color: AppTheme.textTertiary,
                      ),
                    );
                  },
                ),
                filled: true,
                fillColor: AppTheme.bgSurface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: AppTheme.textTertiary.withValues(alpha: 0.2),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: AppTheme.textTertiary.withValues(alpha: 0.2),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: AppTheme.accent,
                    width: 1.5,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              onChanged: (_) {},
            ),
            const SizedBox(height: 4),
            Text(
              'Optional. Max 140 characters.',
              style: AppTheme.caption.copyWith(color: AppTheme.textTertiary),
            ),
            const SizedBox(height: 32),

            // Validation feedback
            if (_nameController.text.trim().length < 2)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 16,
                      color: AppTheme.red,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Display name must be at least 2 characters.',
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.red,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
      },
    ),
    );
  }

  bool get _isValid {
    final name = _nameController.text.trim();
    return name.length >= 2 && name.length <= _maxNameLength;
  }

  Future<void> _save() async {
    if (!_isValid || _isSaving) return;

    setState(() => _isSaving = true);

    try {
      final identity = ref.read(localIdentityProvider).valueOrNull;
      if (identity == null) return;

      final repo = ref.read(identityRepositoryProvider);
      await repo.updateLocalIdentityProfile(
        id: identity.id,
        displayName: _nameController.text.trim(),
        about: _aboutController.text.trim().isEmpty
            ? null
            : _aboutController.text.trim(),
      );

      // Invalidate to refresh downstream UI.
      ref.invalidate(localIdentityProvider);

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}
