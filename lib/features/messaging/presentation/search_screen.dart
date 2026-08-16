import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:onebit/core/extensions/build_context_extensions.dart';
import 'package:onebit/core/extensions/date_time_extensions.dart';
import 'package:onebit/core/navigation/app_route_paths.dart';
import 'package:onebit/core/widgets/onebit_scaffold.dart';
import 'package:onebit/features/messaging/presentation/search_controller.dart';
import 'package:onebit/shared/design_system/components/onebit_empty_state.dart';
import 'package:onebit/shared/design_system/components/onebit_error_state.dart';
import 'package:onebit/shared/design_system/components/onebit_list_item.dart';
import 'package:onebit/shared/design_system/components/onebit_loading_indicator.dart';
import 'package:onebit/shared/design_system/components/onebit_scroll_clearance.dart';
import 'package:onebit/shared/design_system/components/onebit_search_field.dart';
import 'package:onebit/shared/design_system/components/onebit_status_chip.dart';
import 'package:onebit/shared/design_system/icons/onebit_icons.dart';
import 'package:onebit/shared/design_system/spacing/onebit_spacing.dart';

/// Local full-text search over the message store.
///
/// Query state, debounce and paging live in [MessageSearchController]; this
/// screen only renders states and forwards input.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

final class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final view = ref.watch(messageSearchProvider);
    final controller = ref.read(messageSearchProvider.notifier);

    return OneBitScaffold(
      appBar: AppBar(title: Text(l10n.searchTitle)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(OneBitSpacing.m),
            child: OneBitSearchField(
              controller: _controller,
              hintText: l10n.searchHint,
              clearTooltip: l10n.commonClear,
              onChanged: controller.onQueryChanged,
            ),
          ),
          Expanded(child: _results(l10n.searchTitle, view)),
        ],
      ),
    );
  }

  Widget _results(String searchTitle, MessageSearchView view) {
    final l10n = context.l10n;
    if (view.error != null && view.results.isEmpty) {
      return OneBitErrorState(
        message: l10n.commonError,
        detail: view.error.toString(),
        retryLabel: l10n.commonRetry,
        onRetry: () => ref.read(messageSearchProvider.notifier).retry(),
      );
    }
    if (!view.hasQuery) {
      return OneBitEmptyState(
        icon: OneBitIcons.search,
        title: l10n.searchEmptyTitle,
        message: l10n.searchEmptyMessage,
      );
    }
    if (view.loading && view.results.isEmpty) {
      return const OneBitLoadingIndicator(label: '');
    }
    if (view.results.isEmpty) {
      return OneBitEmptyState(
        icon: OneBitIcons.search,
        title: l10n.searchNoResults(view.query),
      );
    }
    return ListView.separated(
      padding: EdgeInsets.only(
        bottom: OneBitScrollClearance.bottom(context),
      ),
      itemCount: view.results.length + (view.hasMore ? 1 : 0),
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        if (index == view.results.length) {
          return const Padding(
            padding: EdgeInsets.all(OneBitSpacing.m),
            child: Center(child: OneBitLoadingIndicator(label: '', size: 24)),
          );
        }
        final result = view.results[index];
        final title = result.snippet.isNotEmpty ? result.snippet : result.body;
        final subtitle =
            '${result.channelTitle} · ${result.sender}'
            ' · ${clockLabel(result.timestamp)}';
        return OneBitListItem(
          leading: OneBitIcons.search,
          title: title,
          subtitle: subtitle,
          trailing: result.pinned
              ? OneBitStatusChip.preset(
                  OneBitStatusPreset.pending,
                  label: 'Pinned',
                )
              : null,
          showChevron: true,
          onTap: () => context.go(
            AppRoutePaths.messageOf(result.channelId, result.messageId),
          ),
        );
      },
    );
  }
}
