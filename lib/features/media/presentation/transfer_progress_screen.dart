import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/core/extensions/build_context_extensions.dart';
import 'package:onebit/core/widgets/onebit_scaffold.dart';
import 'package:onebit/features/media/presentation/transfer_progress_controller.dart';
import 'package:onebit/features/media/transfer/transfer_state.dart';
import 'package:onebit/shared/design_system/components/onebit_button.dart';
import 'package:onebit/shared/design_system/components/onebit_dialogs.dart';
import 'package:onebit/shared/design_system/components/onebit_empty_state.dart';
import 'package:onebit/shared/design_system/components/onebit_error_state.dart';
import 'package:onebit/shared/design_system/components/onebit_loading_indicator.dart';
import 'package:onebit/shared/design_system/components/onebit_progress.dart';
import 'package:onebit/shared/design_system/components/onebit_status_chip.dart';
import 'package:onebit/shared/design_system/components/onebit_technical_card.dart';
import 'package:onebit/shared/design_system/components/onebit_transfer_card.dart';
import 'package:onebit/shared/design_system/formatting/onebit_formatters.dart';
import 'package:onebit/shared/design_system/icons/onebit_icons.dart';
import 'package:onebit/shared/design_system/spacing/onebit_spacing.dart';

/// Live progress of one media transfer (deep-linkable via
/// [AppRoutePaths.transfer]).
class TransferProgressScreen extends ConsumerWidget {
  const TransferProgressScreen({required this.sessionId, super.key});

  /// Transfer session identifier from the route.
  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final view = ref.watch(transferProgressControllerProvider(sessionId));

    return OneBitScaffold(
      appBar: AppBar(title: Text(l10n.transferProgressTitle)),
      body: switch (view) {
        AsyncData(:final value) when value.loading =>
          const OneBitLoadingIndicator(),
        AsyncData(:final value) when value.notFound => OneBitEmptyState(
          title: l10n.transferNotFound,
          icon: OneBitIcons.upload,
        ),
        AsyncData(:final value) when value.session == null => OneBitErrorState(
          message: l10n.commonError,
          detail: '${value.failure ?? ''}',
        ),
        AsyncData(:final value) => _TransferView(value: value),
        AsyncError(:final error) => OneBitErrorState(
          message: l10n.commonError,
          detail: '$error',
        ),
        _ => const OneBitLoadingIndicator(),
      },
    );
  }
}

final class _TransferView extends ConsumerWidget {
  const _TransferView({required this.value});

  final TransferProgressView value;

  OneBitStatusPreset? get _statusPreset => switch (value.session!.state) {
    TransferState.queued => OneBitStatusPreset.pending,
    TransferState.transferring => OneBitStatusPreset.connecting,
    TransferState.paused => OneBitStatusPreset.pending,
    TransferState.resuming => OneBitStatusPreset.connecting,
    TransferState.verifying => OneBitStatusPreset.connecting,
    TransferState.completed => OneBitStatusPreset.completed,
    TransferState.failed => OneBitStatusPreset.failed,
    TransferState.cancelled => OneBitStatusPreset.pending,
    TransferState.expired => OneBitStatusPreset.failed,
  };

  Future<void> _confirmCancel(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final confirmed = await OneBitDialogs.destructive(
      context,
      title: l10n.transferCancelTitle,
      message: l10n.transferCancelMessage,
      confirmLabel: l10n.commonDelete,
    );
    if (confirmed) {
      await ref
          .read(
            transferProgressControllerProvider(
              value.session!.sessionId,
            ).notifier,
          )
          .cancel();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final session = value.session!;
    final controller = ref.read(
      transferProgressControllerProvider(session.sessionId).notifier,
    );
    final direction = session.direction == TransferDirection.send
        ? OneBitTransferDirection.upload
        : OneBitTransferDirection.download;
    final transferred = OneBitFormatters.bytes(session.bytesTransferred);
    final total = OneBitFormatters.bytes(value.sizeBytes);
    final rate = value.speedBytesPerSecond > 0
        ? OneBitFormatters.speed(value.speedBytesPerSecond)
        : null;

    return ListView(
      padding: const EdgeInsets.all(OneBitSpacing.m),
      children: [
        OneBitTransferCard(
          title: value.fileName ?? session.attachmentId,
          direction: direction,
          progress: session.progress,
          transferred: transferred,
          total: total,
          rate: rate,
          status: _statusPreset,
        ),
        const SizedBox(height: OneBitSpacing.m),
        if (value.failure != null)
          OneBitTechnicalCard(
            title: l10n.transferError,
            content: '$value.failure',
            maxLines: 3,
          ),
        const SizedBox(height: OneBitSpacing.m),
        if (session.state.isActive) ...[
          OneBitButton(
            label: session.state == TransferState.paused
                ? l10n.commonResume
                : l10n.commonPause,
            icon: session.state == TransferState.paused
                ? OneBitIcons.play
                : OneBitIcons.pause,
            variant: OneBitButtonVariant.tonal,
            onPressed: session.state == TransferState.paused
                ? controller.resume
                : controller.pause,
          ),
          const SizedBox(height: OneBitSpacing.s),
        ],
        if (session.state == TransferState.failed) ...[
          OneBitButton(
            label: l10n.commonRetry,
            icon: OneBitIcons.retry,
            variant: OneBitButtonVariant.tonal,
            onPressed: controller.retry,
          ),
          const SizedBox(height: OneBitSpacing.s),
        ],
        if (session.state.isActive || session.state == TransferState.failed)
          OneBitButton(
            label: l10n.commonDelete,
            icon: OneBitIcons.delete,
            variant: OneBitButtonVariant.destructive,
            onPressed: () => _confirmCancel(context, ref),
          ),
        const SizedBox(height: OneBitSpacing.m),
        OneBitTechnicalCard(
          title: l10n.sessionIdLabel,
          content: session.sessionId,
          maxLines: 2,
        ),
        const SizedBox(height: OneBitSpacing.m),
        OneBitTechnicalCard(
          title: l10n.transferPeer,
          content: session.peerNodeId,
          maxLines: 2,
        ),
        const SizedBox(height: OneBitSpacing.m),
        OneBitTechnicalCard(
          title: l10n.transferSize,
          content:
              '${session.totalChunks} × ${OneBitFormatters.bytes(session.chunkSize)}',
          maxLines: 2,
        ),
        const SizedBox(height: OneBitSpacing.m),
        OneBitTechnicalCard(
          title: l10n.transferStarted,
          content: '${session.createdAt.toLocal()}',
          maxLines: 2,
        ),
        const SizedBox(height: OneBitSpacing.m),
        OneBitTechnicalCard(
          title: l10n.transferAttempts(session.attemptCount),
          content:
              '${l10n.transferEta}: ${OneBitFormatters.duration(value.eta)}',
          maxLines: 2,
        ),
        if (session.lastError != null) ...[
          const SizedBox(height: OneBitSpacing.m),
          OneBitTechnicalCard(
            title: l10n.transferError,
            content: session.lastError!,
            maxLines: 3,
          ),
        ],
      ],
    );
  }
}
