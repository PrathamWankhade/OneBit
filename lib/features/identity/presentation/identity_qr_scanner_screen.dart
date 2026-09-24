import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:onebit/core/theme/app_theme.dart';
import 'package:onebit/features/identity/identity_export.dart';
import 'package:onebit/features/identity/identity_fingerprint.dart';
import 'package:onebit/features/identity/identity_models.dart';
import 'package:onebit/features/identity/identity_providers.dart';
import 'package:onebit/features/identity/identity_repository.dart';
import 'package:onebit/features/trust/peer_trust.dart';
import 'package:onebit/features/trust/trust_providers.dart';

/// F6 — QR code scanner for importing peer identities.
///
/// Camera-based QR detection. Shows confirmation with fingerprint
/// after a valid identity is scanned.
class IdentityQrScannerScreen extends ConsumerStatefulWidget {
  const IdentityQrScannerScreen({super.key});

  @override
  ConsumerState<IdentityQrScannerScreen> createState() =>
      _IdentityQrScannerScreenState();
}

class _IdentityQrScannerScreenState
    extends ConsumerState<IdentityQrScannerScreen> {
  MobileScannerController? _scannerController;
  bool _hasDetected = false;
  PublicIdentity? _detectedIdentity;
  String? _error;
  AssociationResult? _associationResult;
  PeerInfo? _peerInfo;
  bool? _isVerified;
  String? _verificationError;
  Future<String>? _fingerprintFuture;

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
    );
  }

  @override
  void dispose() {
    _scannerController?.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasDetected) return;

    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null || raw.isEmpty) continue;

      if (raw.length > 4096) {
        setState(() => _error = 'QR payload too large.');
        return;
      }

      try {
        final localKeyHex = ref.read(identityServiceProvider).identityId;
        final result = importPublicIdentity(
          raw,
          localPublicKeyHex: localKeyHex,
        );

        setState(() {
          _hasDetected = true;
          _detectedIdentity = result.identity;
          _fingerprintFuture = computeFingerprint(result.identity.publicKeyBytes);
        });
        _scannerController?.stop();
        return;
      } catch (e) {
        setState(() => _error = 'Not a valid OneBit identity.');
      }
    }
  }

  void _resetScanner() {
    setState(() {
      _hasDetected = false;
      _detectedIdentity = null;
      _error = null;
      _associationResult = null;
      _peerInfo = null;
      _isVerified = null;
      _verificationError = null;
      _fingerprintFuture = null;
    });
    _scannerController?.start();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgBase,
      appBar: AppBar(
        backgroundColor: AppTheme.bgBase,
        title: Text(
          'Scan QR Code',
          style: AppTheme.titleLarge.copyWith(color: AppTheme.textPrimary),
        ),
      ),
      body: _hasDetected && _detectedIdentity != null
          ? _buildConfirmation()
          : _buildScanner(),
    );
  }

  Widget _buildScanner() {
    return Stack(
      children: [
        MobileScanner(
          controller: _scannerController!,
          onDetect: _onDetect,
        ),
        // Scan overlay
        Center(
          child: Container(
            width: 256,
            height: 256,
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.accent, width: 3),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        // Instructions
        Positioned(
          bottom: 48,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            margin: const EdgeInsets.symmetric(horizontal: 32),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Point camera at a OneBit QR code',
              style: AppTheme.bodyMedium.copyWith(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        // Error
        if (_error != null)
          Positioned(
            bottom: 120,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              margin: const EdgeInsets.symmetric(horizontal: 32),
              decoration: BoxDecoration(
                color: AppTheme.red.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _error!,
                style: AppTheme.bodyMedium.copyWith(color: AppTheme.red),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildConfirmation() {
    final identity = _detectedIdentity!;
    final isLocal = identity.publicKeyHex.toLowerCase() ==
        ref.read(identityServiceProvider).identityId?.toLowerCase();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Icon(
            isLocal ? Icons.person : Icons.person_add,
            size: 64,
            color: AppTheme.accent,
          ),
          const SizedBox(height: 16),
          Text(
            isLocal ? 'Your Identity' : 'Identity Found',
            style: AppTheme.headlineMedium.copyWith(
              color: AppTheme.textPrimary,
            ),
          ),
          if (identity.displayName != null) ...[
            const SizedBox(height: 8),
            Text(
              identity.displayName!,
              style: AppTheme.titleLarge.copyWith(color: AppTheme.textSecondary),
            ),
          ],
          const SizedBox(height: 24),

          // Fingerprint
          Text(
            'Fingerprint',
            style: AppTheme.labelMedium.copyWith(color: AppTheme.textTertiary),
          ),
          const SizedBox(height: 8),
          FutureBuilder<String>(
            future: _fingerprintFuture!,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.accent,
                );
              }
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.bgSurface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  snapshot.data!,
                  style: AppTheme.technical.copyWith(
                    color: AppTheme.textPrimary,
                    letterSpacing: 1.2,
                  ),
                  textAlign: TextAlign.center,
                ),
              );
            },
          ),
          const SizedBox(height: 32),

          // Association result
          if (_associationResult != null) ...[
            _buildResultMessage(),
            const SizedBox(height: 12),
          ],

          // Verification error
          if (_verificationError != null) ...[
            _buildVerificationError(),
            const SizedBox(height: 12),
          ],

          // Verification success
          if (_isVerified == true) ...[
            _buildVerifiedMessage(),
            const SizedBox(height: 12),
          ],

          // Action buttons
          if (isLocal)
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  foregroundColor: AppTheme.bgBase,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Done'),
              ),
            )
          else if (_associationResult == null) ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _importIdentity,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  foregroundColor: AppTheme.bgBase,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Import Identity'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _resetScanner,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.textPrimary,
                  side: const BorderSide(color: AppTheme.bgOverlay),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Scan Another'),
              ),
            ),
          ] else ...[
            if (_associationResult != AssociationResult.conflict &&
                _associationResult != AssociationResult.invalid &&
                _isVerified != true)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _verifyIdentity,
                  icon: const Icon(Icons.verified_user),
                  label: const Text('Verify Identity'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: AppTheme.bgBase,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            if (_isVerified != true) const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  foregroundColor: AppTheme.bgBase,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Done'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResultMessage() {
    final String message;
    final Color color;

    switch (_associationResult!) {
      case AssociationResult.created:
        message = 'Identity added';
        color = AppTheme.accent;
      case AssociationResult.existing:
        message = 'Already known';
        color = AppTheme.textSecondary;
      case AssociationResult.self:
        message = 'This is your OneBit identity.';
        color = AppTheme.textSecondary;
      case AssociationResult.conflict:
        message = 'Identity conflicts with an existing record.';
        color = AppTheme.red;
      case AssociationResult.invalid:
        message = 'Invalid identity.';
        color = AppTheme.red;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        message,
        style: AppTheme.bodyMedium.copyWith(color: color),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildVerificationError() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _verificationError!,
        style: AppTheme.bodyMedium.copyWith(color: AppTheme.red),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildVerifiedMessage() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.verified, size: 18, color: AppTheme.green),
          const SizedBox(width: 8),
          Text(
            'Identity verified',
            style: AppTheme.bodyMedium.copyWith(color: AppTheme.green),
          ),
        ],
      ),
    );
  }

  Future<void> _importIdentity() async {
    final identity = _detectedIdentity;
    if (identity == null) return;

    final service = ref.read(identityServiceProvider);
    final (peer, result) = await service.associatePeer(identity);

    if (mounted) {
      setState(() {
        _associationResult = result;
        _peerInfo = peer;
      });
    }
  }

  Future<void> _verifyIdentity() async {
    final peer = _peerInfo;
    final identity = _detectedIdentity;
    if (peer == null || identity == null) return;
    if (peer.identityId == null) return;

    final trustService = ref.read(trustServiceProvider);

    if (trustService.isVerified(peer.identityId!)) {
      if (mounted) setState(() => _isVerified = true);
      return;
    }

    try {
      trustService.verifyIdentity(
        peerIdentityId: peer.identityId!,
        at: DateTime.now(),
        publicKeyHex: identity.publicKeyHex,
        method: VerificationMethod.qrScan,
      );

      if (mounted) setState(() => _isVerified = true);
    } catch (e) {
      if (mounted) setState(() => _verificationError = 'Verification failed: $e');
    }
  }
}
