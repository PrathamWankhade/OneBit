import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/l10n/app_localizations.dart';
import 'package:onebit/shared/design_system/components/onebit_error_state.dart';
import 'package:onebit/shared/design_system/components/onebit_loading_indicator.dart';

/// Boilerplate-free mapping of an [AsyncValue] into loading / error / data
/// states.
///
/// Use inside `ConsumerWidget`s whenever a feature watches an async
/// provider:
/// ```dart
/// final status = ref.watch(homeStatusProvider);
/// return OneBitAsyncView(
///   asyncValue: status,
///   onRetry: () => ref.invalidate(homeStatusProvider),
///   onData: (status) => HomeContent(status: status),
/// );
/// ```
class OneBitAsyncView<T> extends StatelessWidget {
  const OneBitAsyncView({
    required this.asyncValue,
    required this.onData,
    this.onRetry,
    this.loadingLabel,
    this.errorLabel,
    this.retryLabel,
    super.key,
  });

  /// The watched async state.
  final AsyncValue<T> asyncValue;

  /// Renders the resolved value.
  final Widget Function(T value) onData;

  /// Re-runs the provider; wired to the retry button.
  final VoidCallback? onRetry;

  /// Caption under the loading spinner.
  final String? loadingLabel;

  /// Message for the failure state.
  final String? errorLabel;

  /// Label of the retry action.
  final String? retryLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return switch (asyncValue) {
      AsyncValue(value: final value) when value != null => onData(value),
      AsyncError() => OneBitErrorState(
        message: errorLabel ?? l10n.commonError,
        detail: asyncValue.error.toString(),
        onRetry: onRetry,
        retryLabel: retryLabel ?? l10n.commonRetry,
      ),
      _ => OneBitLoadingIndicator(label: loadingLabel ?? l10n.commonLoading),
    };
  }
}
