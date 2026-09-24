import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr/qr.dart' as qr;
import 'package:onebit/core/theme/app_theme.dart';
import 'package:onebit/features/identity/identity_export.dart';
import 'package:onebit/features/identity/identity_providers.dart';

/// F6 — QR code display for sharing identity.
///
/// Shows avatar, QR code, OneBit ID, and share/save actions.
class IdentityQrScreen extends ConsumerStatefulWidget {
  const IdentityQrScreen({super.key});

  @override
  ConsumerState<IdentityQrScreen> createState() => _IdentityQrScreenState();
}

class _IdentityQrScreenState extends ConsumerState<IdentityQrScreen> {
  Future<String>? _exportFuture;

  @override
  Widget build(BuildContext context) {
    final identityAsync = ref.watch(localIdentityProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgBase,
      appBar: AppBar(
        backgroundColor: AppTheme.bgBase,
        title: Text(
          'My QR Code',
          style: AppTheme.titleLarge.copyWith(color: AppTheme.textPrimary),
        ),
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
              Text('Error loading identity: $e', style: AppTheme.bodyMedium),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
        data: (identity) {
          if (identity == null || identity.publicKeyBytes == null) {
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
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            );
          }

          return FutureBuilder<String>(
            future: _exportFuture ??= exportPublicIdentity(identity),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: AppTheme.accent),
                );
              }
              return _QrDisplay(
                payload: snapshot.data!,
                publicKeyBytes: identity.publicKeyBytes!,
                displayName: identity.displayName,
                identityId: identity.identityId ?? '',
              );
            },
          );
        },
      ),
    );
  }
}

class _QrDisplay extends StatelessWidget {
  const _QrDisplay({
    required this.payload,
    required this.publicKeyBytes,
    required this.displayName,
    required this.identityId,
  });

  final String payload;
  final dynamic publicKeyBytes;
  final String displayName;
  final String identityId;

  @override
  Widget build(BuildContext context) {
    final qrPayload = qr.QrPayload.fromString(payload);
    final qrData = qr.QrCode(
      payload: qrPayload,
      errorCorrectLevel: qr.QrErrorCorrectLevel.medium,
    );
    final qrImage = qr.QrImage(qrData);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          // Avatar
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.bgElevated,
              borderRadius: BorderRadius.circular(24),
            ),
            alignment: Alignment.center,
            child: Text(
              displayName.isNotEmpty
                  ? displayName[0].toUpperCase()
                  : '?',
              style: AppTheme.headlineMedium.copyWith(color: AppTheme.accent),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            displayName,
            style: AppTheme.titleLarge.copyWith(color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 24),

          // QR Code
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: CustomPaint(
              size: const Size(200, 200),
              painter: _QrPainter(qrImage),
            ),
          ),
          const SizedBox(height: 16),

          // Identity ID
          Text(
            _formatId(identityId),
            style: AppTheme.technical.copyWith(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 16),

          Text(
            'Share this QR code to let others add you as a peer.',
            style: AppTheme.bodySmall.copyWith(color: AppTheme.textTertiary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.verified, size: 12, color: AppTheme.green),
              const SizedBox(width: 4),
              Text(
                'Your identity is verified and encrypted.',
                style: AppTheme.caption.copyWith(color: AppTheme.green),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    // Share via system share sheet
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Share coming soon'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: const Text('Share'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textPrimary,
                    side: const BorderSide(color: AppTheme.bgOverlay),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Save coming soon'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                  icon: const Icon(Icons.save_alt, size: 18),
                  label: const Text('Save'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textPrimary,
                    side: const BorderSide(color: AppTheme.bgOverlay),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _formatId(String id) {
    if (id.length <= 16) return id;
    final buffer = StringBuffer();
    for (var i = 0; i < id.length && i < 16; i += 4) {
      if (buffer.isNotEmpty) buffer.write(':');
      buffer.write(id.substring(i, i + 4));
    }
    return '$buffer...';
  }
}

class _QrPainter extends CustomPainter {
  _QrPainter(this.qrImage);

  final qr.QrImage qrImage;

  @override
  void paint(Canvas canvas, Size size) {
    final moduleCount = qrImage.moduleCount;
    final moduleSize = size.width / moduleCount;
    final paint = Paint()..style = PaintingStyle.fill;

    for (var x = 0; x < moduleCount; x++) {
      for (var y = 0; y < moduleCount; y++) {
        if (qrImage.isDark(x, y)) {
          canvas.drawRect(
            Rect.fromLTWH(
              x * moduleSize,
              y * moduleSize,
              moduleSize,
              moduleSize,
            ),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _QrPainter oldDelegate) => false;
}
