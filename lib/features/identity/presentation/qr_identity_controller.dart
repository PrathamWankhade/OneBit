import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/features/identity/domain/node_identity.dart';
import 'package:onebit/features/identity/presentation/identity_controller.dart';
import 'package:onebit/features/identity/presentation/identity_providers.dart';
import 'package:onebit/shared/base/use_case.dart';

/// Presentation state of this node's identity QR card.
final class QrIdentityView {
  const QrIdentityView({required this.identity, required this.cardText});

  final NodeIdentity identity;

  /// Signed `OB1:` wire text rendered as the QR pattern.
  final String cardText;
}

/// Builds the signed identity card payload for the QR screen.
final qrIdentityControllerProvider =
    AsyncNotifierProvider<QrIdentityController, QrIdentityView>(
      QrIdentityController.new,
    );

final class QrIdentityController extends AsyncNotifier<QrIdentityView> {
  @override
  Future<QrIdentityView> build() async {
    final identity = await ref.watch(identityControllerProvider.future);
    if (identity == null) {
      throw StateError('identity not created yet');
    }
    final card = await ref
        .read(buildIdentityCardProvider)
        .call(NoParams.instance);
    if (card.isErr) {
      throw card.failure!;
    }
    return QrIdentityView(identity: identity, cardText: card.value!);
  }
}
