import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:onebit/core/extensions/build_context_extensions.dart';
import 'package:onebit/core/navigation/app_route_paths.dart';
import 'package:onebit/core/platform/platform_capabilities.dart';
import 'package:onebit/core/widgets/onebit_async_view.dart';
import 'package:onebit/core/widgets/onebit_scaffold.dart';
import 'package:onebit/features/home/domain/home_status.dart';
import 'package:onebit/features/home/presentation/home_controller.dart';
import 'package:onebit/l10n/app_localizations.dart';
import 'package:onebit/shared/design_system/components/onebit_card.dart';
import 'package:onebit/shared/design_system/components/onebit_empty_state.dart';
import 'package:onebit/shared/design_system/icons/onebit_icons.dart';
import 'package:onebit/shared/design_system/spacing/onebit_spacing.dart';

/// The home console: a read-only operator dashboard describing the running
/// node and the capabilities this build really provides.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(homeControllerProvider);

    return OneBitScaffold(
      body: OneBitAsyncView<HomeStatus>(
        asyncValue: status,
        onRetry: () => ref.invalidate(homeControllerProvider),
        onData: (status) => _HomeDashboard(status: status),
      ),
    );
  }
}

final class _HomeDashboard extends StatelessWidget {
  const _HomeDashboard({required this.status});

  final HomeStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return ListView(
      padding: const EdgeInsets.all(OneBitSpacing.m),
      children: [
        Text(l10n.homeTitle, style: context.textTheme.displayLarge),
        const SizedBox(height: OneBitSpacing.xs),
        Text(l10n.homeSubtitle, style: context.textTheme.bodyMedium),
        const SizedBox(height: OneBitSpacing.xl),
        OneBitCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InfoRow(
                label: l10n.homeFlavor,
                value: status.config.flavor.rawName,
              ),
              _InfoRow(
                label: l10n.homeEnvironment,
                value: status.config.environment.rawName,
              ),
              _InfoRow(
                label: l10n.homeVersion,
                value: status.config.displayVersion,
              ),
              _InfoRow(label: l10n.homeNodeStatus, value: l10n.homeNodeIdle),
            ],
          ),
        ),
        const SizedBox(height: OneBitSpacing.m),
        _CapabilitiesCard(capabilities: status.capabilities),
        const SizedBox(height: OneBitSpacing.m),
        OneBitCard(
          child: ListTile(
            title: Text('Developer tools', style: context.textTheme.titleSmall),
            subtitle: Text(
              'Inspection, diagnostics and performance',
              style: context.textTheme.bodySmall,
            ),
            trailing: const Icon(OneBitIcons.chevronRight),
            onTap: () => context.go(AppRoutePaths.developer),
          ),
        ),
        const SizedBox(height: OneBitSpacing.m),
        OneBitCard(
          outlined: true,
          child: OneBitEmptyState(
            icon: OneBitIcons.radar,
            title: l10n.homeNoneNearby,
            message: l10n.homeNoData,
          ),
        ),
      ],
    );
  }
}

final class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: OneBitSpacing.s),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: context.textTheme.bodyMedium),
          Text(value, style: context.textTheme.titleMedium),
        ],
      ),
    );
  }
}

final class _CapabilitiesCard extends StatelessWidget {
  const _CapabilitiesCard({required this.capabilities});

  final PlatformCapabilities capabilities;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    Widget tile(String label, bool available) {
      return _InfoRow(
        label: label,
        value: available
            ? l10n.developerCapabilityAvailable
            : l10n.developerCapabilityUnavailable,
      );
    }

    return OneBitCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.developerCapabilitiesTitle,
            style: context.textTheme.titleLarge,
          ),
          const SizedBox(height: OneBitSpacing.s),
          tile(
            l10n.developerCapabilityNativeCore,
            capabilities.nativeCoreAvailable,
          ),
          tile(
            l10n.developerCapabilityChannelBridge,
            capabilities.channelBridgeAvailable,
          ),
        ],
      ),
    );
  }
}
