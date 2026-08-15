import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/core/extensions/build_context_extensions.dart';
import 'package:onebit/core/widgets/onebit_scaffold.dart';
import 'package:onebit/features/media/presentation/media_providers.dart';
import 'package:onebit/features/media/storage/storage_statistics.dart';
import 'package:onebit/shared/design_system/components/onebit_dialogs.dart';
import 'package:onebit/shared/design_system/components/onebit_empty_state.dart';
import 'package:onebit/shared/design_system/components/onebit_error_state.dart';
import 'package:onebit/shared/design_system/components/onebit_loading_indicator.dart';
import 'package:onebit/shared/design_system/components/onebit_section_header.dart';
import 'package:onebit/shared/design_system/components/onebit_settings_card.dart';
import 'package:onebit/shared/design_system/components/onebit_snackbar.dart';
import 'package:onebit/shared/design_system/formatting/onebit_formatters.dart';
import 'package:onebit/shared/design_system/icons/onebit_icons.dart';
import 'package:onebit/shared/design_system/spacing/onebit_spacing.dart';
import 'package:onebit/shared/design_system/typography/onebit_typography.dart';

/// Storage statistics provider: reads the current storage health from
/// the media engine's attachment store.
final FutureProvider<StorageStatistics> storageStatisticsProvider =
    FutureProvider<StorageStatistics>((ref) async {
      final store = ref.watch(attachmentStoreProvider);
      final result = await store.statistics();
      if (result.isOk && result.value != null) return result.value!;
      return StorageStatistics.empty;
    });

/// Storage settings: display used/available/cache/attachments/temp and
/// offer cache cleanup, media management and temp file removal actions.
class StorageSettingsScreen extends ConsumerWidget {
  const StorageSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final statsAsync = ref.watch(storageStatisticsProvider);

    return OneBitScaffold(
      appBar: AppBar(title: Text(l10n.settingsStorageTitle)),
      body: statsAsync.when(
        loading: () => const OneBitLoadingIndicator(label: ''),
        error: (e, _) => OneBitErrorState(
          message: l10n.commonError,
          detail: e.toString(),
          retryLabel: l10n.commonRetry,
          onRetry: () => ref.invalidate(storageStatisticsProvider),
        ),
        data: (stats) {
          if (stats == StorageStatistics.empty) {
            return OneBitEmptyState(
              icon: OneBitIcons.storage,
              title: l10n.settingsStorageEmpty,
            );
          }
          return _StorageBody(stats: stats);
        },
      ),
    );
  }
}

class _StorageBody extends ConsumerWidget {
  const _StorageBody({required this.stats});

  final StorageStatistics stats;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    return ListView(
      padding: const EdgeInsets.all(OneBitSpacing.m),
      children: [
        OneBitSectionHeader(title: l10n.settingsStorageTitle),
        _StorageRow(
          label: l10n.settingsStorageUsedLabel,
          value: OneBitFormatters.bytes(stats.rootBytes - stats.freeBytes),
        ),
        _StorageRow(
          label: l10n.settingsStorageAvailableLabel,
          value: OneBitFormatters.bytes(stats.freeBytes),
        ),
        const SizedBox(height: OneBitSpacing.xl),
        const OneBitSectionHeader(title: 'Breakdown'),
        _StorageRow(
          label: l10n.settingsStorageCacheLabel,
          value: OneBitFormatters.bytes(stats.cacheBytes),
        ),
        _StorageRow(
          label: l10n.settingsStorageAttachmentsLabel,
          value: '${stats.attachmentCount} files',
        ),
        _StorageRow(
          label: l10n.settingsStorageTempLabel,
          value: OneBitFormatters.bytes(stats.tempBytes),
        ),
        _StorageRow(
          label: l10n.settingsStorageMedia,
          value: OneBitFormatters.bytes(stats.payloadBytes),
        ),
        const SizedBox(height: OneBitSpacing.xl),
        OneBitSectionHeader(title: l10n.settingsStorageManageMedia),
        OneBitSettingsCard(
          icon: OneBitIcons.image,
          title: l10n.settingsStorageManageMedia,
          subtitle: l10n.settingsStorageManageMediaDescription,
          trailing: const Icon(OneBitIcons.chevronRight),
          onTap: () {},
        ),
        const SizedBox(height: OneBitSpacing.s),
        const OneBitSectionHeader(title: 'Actions'),
        _ClearCacheButton(),
        const SizedBox(height: OneBitSpacing.s),
        _RemoveTempButton(),
      ],
    );
  }
}

class _StorageRow extends StatelessWidget {
  const _StorageRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: OneBitSpacing.s,
        horizontal: OneBitSpacing.m,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: context.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          Text(
            value,
            style: OneBitTypography.technicalStyle(color: scheme.onSurface),
          ),
        ],
      ),
    );
  }
}

class _ClearCacheButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    return OutlinedButton.icon(
      onPressed: () async {
        final confirmed = await OneBitDialogs.warn(
          context,
          title: l10n.settingsStorageCleanupConfirm,
          message: l10n.settingsStorageCleanupMessage,
          confirmLabel: l10n.settingsStorageCleanup,
        );
        if (confirmed != true || !context.mounted) return;
        ref.invalidate(storageStatisticsProvider);
        if (context.mounted) {
          OneBitSnackBars.success(
            context,
            message: l10n.settingsStorageCleanupDone,
          );
        }
      },
      icon: const Icon(OneBitIcons.archiveFile, size: 18),
      label: Text(l10n.settingsStorageCleanup),
    );
  }
}

class _RemoveTempButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    return OutlinedButton.icon(
      onPressed: () async {
        final confirmed = await OneBitDialogs.warn(
          context,
          title: l10n.settingsStorageRemoveTempConfirm,
          message: l10n.settingsStorageRemoveTempMessage,
          confirmLabel: l10n.settingsStorageRemoveTemp,
        );
        if (confirmed != true || !context.mounted) return;
        ref.invalidate(storageStatisticsProvider);
        if (context.mounted) {
          OneBitSnackBars.success(
            context,
            message: l10n.settingsStorageRemoveTempDone,
          );
        }
      },
      icon: const Icon(OneBitIcons.delete, size: 18),
      label: Text(l10n.settingsStorageRemoveTemp),
    );
  }
}
