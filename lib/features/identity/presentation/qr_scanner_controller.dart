import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/core/crypto/identity/node_id.dart';
import 'package:onebit/core/crypto/identity/qr_domain.dart';
import 'package:onebit/features/identity/domain/trust_contact.dart';
import 'package:onebit/features/identity/domain/use_cases/decode_identity_card.dart';
import 'package:onebit/features/identity/presentation/identity_providers.dart';
import 'package:onebit/features/identity/presentation/qr_scanner_service.dart';

/// Phase machine of the QR scanner.
enum QrScannerPhase {
  /// Nothing happened yet.
  idle,

  /// The user refused camera access.
  permissionDenied,

  /// Camera is live and searching.
  scanning,

  /// A payload was captured and is being authenticated.
  decoding,

  /// A valid identity card was found.
  success,

  /// The captured payload was not a valid identity card.
  invalid,

  /// The scan was stopped by the user.
  cancelled,

  /// The camera or decode pipeline failed.
  error,
}

/// Presentation state of the QR scanner.
final class QrScannerView {
  const QrScannerView({
    this.phase = QrScannerPhase.idle,
    this.card,
    this.error,
    this.contactAdded = false,
  });

  final QrScannerPhase phase;

  /// The authenticated identity card, when [phase] is [QrScannerPhase.success].
  final QrIdentityCard? card;

  /// Failure detail, when [phase] is [QrScannerPhase.error].
  final Object? error;

  /// Whether the found card was added as a contact.
  final bool contactAdded;

  bool get isScanning => phase == QrScannerPhase.scanning;
  bool get isDecoding => phase == QrScannerPhase.decoding;

  QrScannerView copyWith({
    QrScannerPhase? phase,
    QrIdentityCard? card,
    Object? error,
    bool? contactAdded,
    bool clearError = false,
  }) => QrScannerView(
    phase: phase ?? this.phase,
    card: card ?? this.card,
    error: clearError ? null : (error ?? this.error),
    contactAdded: contactAdded ?? this.contactAdded,
  );
}

/// Drives the scanner service and authenticates captured cards.
final qrScannerControllerProvider =
    NotifierProvider.autoDispose<QrScannerController, QrScannerView>(
      QrScannerController.new,
    );

final class QrScannerController extends Notifier<QrScannerView> {
  @override
  QrScannerView build() {
    final service = ref.read(qrScannerServiceProvider);
    ref.onDispose(() {
      unawaited(service.stop());
    });
    return const QrScannerView();
  }

  /// Requests camera access and starts scanning.
  Future<void> startScanning() async {
    final service = ref.read(qrScannerServiceProvider);
    final granted = await service.ensurePermission();
    if (!granted) {
      state = state.copyWith(
        phase: QrScannerPhase.permissionDenied,
        clearError: true,
      );
      return;
    }
    state = state.copyWith(
      phase: QrScannerPhase.scanning,
      card: null,
      contactAdded: false,
      clearError: true,
    );
  }

  /// Handles one decoded payload: authenticates it and moves the machine.
  Future<void> onDetected(String text) async {
    if (state.phase != QrScannerPhase.scanning) return;
    state = state.copyWith(phase: QrScannerPhase.decoding, clearError: true);
    final result = await ref
        .read(decodeIdentityCardProvider)
        .call(DecodeIdentityCardParams(text));
    if (result.isErr) {
      state = state.copyWith(
        phase: QrScannerPhase.invalid,
        error: result.failure,
      );
      return;
    }
    await ref.read(qrScannerServiceProvider).stop();
    state = state.copyWith(phase: QrScannerPhase.success, card: result.value);
  }

  /// Reopens the camera after an invalid or cancelled result.
  Future<void> scanAgain() async {
    state = state.copyWith(
      phase: QrScannerPhase.scanning,
      card: null,
      contactAdded: false,
      clearError: true,
    );
    await ref.read(qrScannerServiceProvider).start();
  }

  /// Stops scanning and returns to the idle phase.
  Future<void> cancelScan() async {
    await ref.read(qrScannerServiceProvider).stop();
    state = state.copyWith(
      phase: QrScannerPhase.cancelled,
      card: null,
      clearError: true,
    );
  }

  /// Returns to the idle entry phase (permission untouched).
  Future<void> reset() async {
    await ref.read(qrScannerServiceProvider).stop();
    state = const QrScannerView();
  }

  /// Adds the authenticated card as a trust contact.
  Future<void> addContact() async {
    final card = state.card;
    if (card == null) return;
    final contact = TrustContact(
      nodeId: NodeId.parse(card.nodeId),
      displayName: card.displayName,
      fingerprintHex: card.fingerprintHex,
      ed25519PublicKey: Uint8List.fromList(card.ed25519PublicKey),
      x25519PublicKey: Uint8List.fromList(card.x25519PublicKey),
    );
    final result = await ref.read(addTrustContactProvider).call(contact);
    if (result.isErr) {
      state = state.copyWith(
        phase: QrScannerPhase.error,
        error: result.failure,
      );
      return;
    }
    state = state.copyWith(contactAdded: true, clearError: true);
  }
}
