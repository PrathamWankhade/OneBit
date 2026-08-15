import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:onebit/core/extensions/build_context_extensions.dart';
import 'package:onebit/core/navigation/app_route_paths.dart';
import 'package:onebit/core/widgets/onebit_scaffold.dart';
import 'package:onebit/features/identity/domain/trust_level.dart';
import 'package:onebit/features/nodes/presentation/node_details_controller.dart';
import 'package:onebit/features/nodes/presentation/node_details/widgets/node_info_sections.dart';
import 'package:onebit/features/nodes/presentation/nodes_controller.dart';
import 'package:onebit/shared/design_system/typography/onebit_typography.dart';
import 'package:onebit/shared/design_system/components/onebit_bottom_sheets.dart';
import 'package:onebit/shared/design_system/components/onebit_button.dart';
import 'package:onebit/shared/design_system/components/onebit_dialogs.dart';
import 'package:onebit/shared/design_system/components/onebit_empty_state.dart';
import 'package:onebit/shared/design_system/components/onebit_error_state.dart';
import 'package:onebit/shared/design_system/components/onebit_icon_button.dart';
import 'package:onebit/shared/design_system/components/onebit_loading_indicator.dart';
import 'package:onebit/shared/design_system/components/onebit_offline_banner.dart';
import 'package:onebit/shared/design_system/icons/onebit_icons.dart';
import 'package:onebit/shared/design_system/spacing/onebit_spacing.dart';

/// Node details: identity, verification, connection and available actions.
///
/// Read-only surface over [nodeDetailsViewProvider]; every action delegates
/// to the controller (existing use cases and repositories). Technical
/// identifiers render in the Consolas family.
class NodeDetailsScreen extends ConsumerWidget {
  const NodeDetailsScreen({required this.nodeId, super.key});

  /// Node identifier from the route.
  final String nodeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final view = ref.watch(nodeDetailsViewProvider(nodeId)).value;

    return OneBitScaffold(
      appBar: AppBar(
        title: Text(
          view?.model?.name ?? nodeId,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          OneBitIconButton(
            icon: OneBitIcons.moreVert,
            tooltip: l10n.nodeActionsTitle,
            onPressed: () => _showActions(context, ref, view),
          ),
        ],
      ),
      body: _body(context, ref, view),
    );
  }

  Widget _body(BuildContext context, WidgetRef ref, NodeDetailsView? view) {
    final l10n = context.l10n;
    if (view == null) {
      return const OneBitLoadingIndicator(label: '');
    }
    if (view.error != null) {
      return OneBitErrorState(
        message: l10n.nodesLoadError,
        detail: view.error.toString(),
        retryLabel: l10n.commonRetry,
        onRetry: () =>
            ref.read(nodeDetailsViewProvider(nodeId).notifier).retry(),
      );
    }
    if (!view.loaded) {
      return const OneBitLoadingIndicator(label: '');
    }
    final model = view.model;
    if (model == null || (model.contact == null && model.neighbor == null)) {
      return OneBitEmptyState(
        icon: OneBitIcons.shellNodes,
        title: l10n.nodeNotFound,
        message: l10n.nodeUnknownNode,
      );
    }

    final contact = model.contact;
    final neighbor = model.neighbor;

    return Column(
      children: [
        if (view.offline)
          OneBitOfflineBanner(
            title: l10n.nodesOfflineTitle,
            message: l10n.nodesOfflineMessage,
          ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(OneBitSpacing.m),
            children: [
              // ---- Identity ----
              NodeIdentitySection(model: model, l10n: l10n),

              // ---- Verification ----
              if (contact != null)
                NodeVerificationSection(
                  contact: contact,
                  l10n: l10n,
                  onPickTrustLevel: () =>
                      _pickTrustLevel(context, ref, contact.trustLevel),
                  onShowVerificationCode: () => _showVerificationCode(
                    context,
                    ref,
                    contact.fingerprintHex,
                  ),
                ),

              // ---- Connection ----
              NodeConnectionSection(neighbor: neighbor, l10n: l10n),

              // ---- Route ----
              NodeRouteSection(neighbor: neighbor, l10n: l10n),

              // ---- Actions ----
              const SizedBox(height: OneBitSpacing.l),
              OneBitButton(
                label: l10n.nodeOpenConversation,
                icon: OneBitIcons.chat,
                onPressed: () => unawaited(_openConversation(context, ref)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showActions(
    BuildContext context,
    WidgetRef ref,
    NodeDetailsView? view,
  ) async {
    final l10n = context.l10n;
    final model = view?.model;
    if (model == null || model.contact == null) return;

    final action = await showOneBitActionSheet<_NodeAction>(
      context,
      title: l10n.nodeActionsTitle,
      actions: [
        OneBitSheetAction(
          label: l10n.nodeShowVerificationCode,
          value: _NodeAction.verificationCode,
          icon: OneBitIcons.security,
        ),
        OneBitSheetAction(
          label: l10n.nodeTrustSelectionTitle,
          value: _NodeAction.trustLevel,
          icon: OneBitIcons.verified,
        ),
        OneBitSheetAction(
          label: l10n.nodeViewIdentity,
          value: _NodeAction.viewIdentity,
          icon: OneBitIcons.qrIdentity,
        ),
        if (view?.model?.neighbor != null)
          OneBitSheetAction(
            label: l10n.nodeViewRoute,
            value: _NodeAction.viewRoute,
            icon: OneBitIcons.shellMesh,
          ),
        OneBitSheetAction(
          label: l10n.nodeRemoveContact,
          value: _NodeAction.remove,
          icon: OneBitIcons.block,
          destructive: true,
        ),
      ],
    );
    if (action == null || !context.mounted) return;

    switch (action) {
      case _NodeAction.verificationCode:
        await _showVerificationCode(
          context,
          ref,
          model.contact!.fingerprintHex,
        );
      case _NodeAction.trustLevel:
        await _pickTrustLevel(context, ref, model.contact!.trustLevel);
      case _NodeAction.viewIdentity:
        context.go(AppRoutePaths.qrIdentity);
      case _NodeAction.viewRoute:
        context.go(AppRoutePaths.routeInspector);
      case _NodeAction.remove:
        await _confirmRemove(context, ref, model);
    }
  }

  Future<void> _pickTrustLevel(
    BuildContext context,
    WidgetRef ref,
    TrustLevel current,
  ) async {
    final l10n = context.l10n;
    final selected = await showOneBitSelectionSheet<TrustLevel>(
      context,
      title: l10n.nodeTrustSelectionTitle,
      selected: current,
      options: [
        OneBitSheetAction(
          label: l10n.nodeTrustKnown,
          value: TrustLevel.known,
          icon: OneBitIcons.info,
        ),
        OneBitSheetAction(
          label: l10n.nodeTrustVerified,
          value: TrustLevel.verified,
          icon: OneBitIcons.verified,
        ),
        OneBitSheetAction(
          label: l10n.nodeTrustBlocked,
          value: TrustLevel.blocked,
          icon: OneBitIcons.block,
          destructive: true,
        ),
      ],
    );
    if (selected == null || selected == current || !context.mounted) return;
    await ref
        .read(nodeDetailsViewProvider(nodeId).notifier)
        .setTrustLevel(selected);
  }

  Future<void> _showVerificationCode(
    BuildContext context,
    WidgetRef ref,
    String fingerprint,
  ) async {
    final l10n = context.l10n;
    final result = await ref
        .read(nodeDetailsViewProvider(nodeId).notifier)
        .verificationCode();
    if (!context.mounted) return;
    if (result.isErr) {
      await OneBitDialogs.error(
        context,
        title: l10n.nodeVerificationCodeError,
        dismissLabel: l10n.commonDone,
      );
      return;
    }
    await showOneBitSheetContent(
      context,
      title: l10n.nodeVerificationCodeTitle,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            result.value!.value,
            style: OneBitTypography.technicalStyle(
              fontSize: OneBitTypography.display,
              weight: OneBitTypography.semibold,
            ),
          ),
          const SizedBox(height: OneBitSpacing.m),
          Text(l10n.nodeVerificationNote, style: context.textTheme.bodySmall),
        ],
      ),
    );
  }

  Future<void> _confirmRemove(
    BuildContext context,
    WidgetRef ref,
    NodeDetailsModel model,
  ) async {
    final l10n = context.l10n;
    final confirmed = await showOneBitDialog<bool>(
      context,
      title: l10n.nodeRemoveContactTitle,
      message: l10n.nodeRemoveContactMessage,
      variant: OneBitDialogVariant.error,
      actions: [
        OneBitDialogAction(label: l10n.commonCancel, value: false),
        OneBitDialogAction(label: l10n.nodeRemoveContact, value: true),
      ],
    );
    if (confirmed != true || !context.mounted) return;

    final ok = await ref
        .read(nodeDetailsViewProvider(nodeId).notifier)
        .removeContact();
    if (!context.mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.nodeContactRemoved)));
    }
  }

  Future<void> _openConversation(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final channelId = await ref
        .read(nodeDetailsViewProvider(nodeId).notifier)
        .openConversation();
    if (!context.mounted) return;
    if (channelId == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.nodeChannelCreateError)));
      return;
    }
    context.go(AppRoutePaths.channelOf(channelId));
  }
}

enum _NodeAction {
  verificationCode,
  trustLevel,
  viewIdentity,
  viewRoute,
  remove,
}
