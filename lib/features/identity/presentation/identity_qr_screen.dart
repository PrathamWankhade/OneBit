import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr/qr.dart' as qr;
import 'package:onebit/core/theme/app_theme.dart';
import 'package:onebit/features/identity/identity_export.dart';
import 'package:onebit/features/identity/identity_providers.dart';
import 'package:onebit/features/identity/presentation/identity_qr_scanner_view.dart';
import 'package:onebit/features/peer_registry/peer_entry.dart';
import 'package:onebit/features/peer_registry/peer_registry_providers.dart';

/// F6 — QR code display and scanner for sharing / importing identity.
///
/// Two swipe pages:
///   0 — avatar, QR code, OneBit ID, share/save actions and the
///       peer-link status card,
///   1 — the camera scanner.
///
/// The app bar title follows whichever page is visible, and its trailing
/// icon jumps to the other page so the scanner is reachable both by swipe
/// and by tap. [initialPage] lets `/identity/scan` open straight on 1.
class IdentityQrScreen extends ConsumerStatefulWidget {
  const IdentityQrScreen({this.initialPage = 0, super.key});

  /// Page shown first: 0 = my QR code, 1 = scanner.
  final int initialPage;

  @override
  ConsumerState<IdentityQrScreen> createState() => _IdentityQrScreenState();
}

class _IdentityQrScreenState extends ConsumerState<IdentityQrScreen> {
  Future<String>? _exportFuture;
  late final PageController _pageController;
  late int _page;

  @override
  void initState() {
    super.initState();
    _page = widget.initialPage == 1 ? 1 : 0;
    _pageController = PageController(initialPage: _page);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToPage(int page) {
    if (page == _page) return;
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final identityAsync = ref.watch(localIdentityProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgBase,
      appBar: AppBar(
        backgroundColor: AppTheme.bgBase,
        title: Text(
          _page == 0 ? 'My QR Code' : 'Scan QR Code',
          style: AppTheme.titleLarge.copyWith(color: AppTheme.textPrimary),
        ),
        actions: [
          IconButton(
            tooltip: _page == 0 ? 'Scan a QR code' : 'Show my QR code',
            onPressed: () => _goToPage(_page == 0 ? 1 : 0),
            icon: Icon(
              _page == 0 ? Icons.qr_code_scanner : Icons.qr_code,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) => setState(() => _page = index),
        children: [
          Column(
            children: [
              Expanded(
                child: identityAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: AppTheme.accent),
                  ),
                  error: (e, _) => Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 48,
                          color: AppTheme.red,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading identity: $e',
                          style: AppTheme.bodyMedium,
                        ),
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
                            const Text(
                              'No identity found',
                              style: AppTheme.bodyLarge,
                            ),
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
                            child: CircularProgressIndicator(
                              color: AppTheme.accent,
                            ),
                          );
                        }
                        return _QrDisplay(
                          payload: snapshot.data!,
                          publicKeyBytes: identity.publicKeyBytes!,
                          displayName: identity.displayName,
                          identityId: identity.identityId ?? '',
                          onScanTap: () => _goToPage(1),
                        );
                      },
                    );
                  },
                ),
              ),
              const _PeerBoundCard(),
            ],
          ),
          const IdentityQrScannerView(),
        ],
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
    required this.onScanTap,
  });

  final String payload;
  final dynamic publicKeyBytes;
  final String displayName;
  final String identityId;

  /// Switches the pager over to the scanner page.
  ///
  /// Swipe works too, but the gesture alone is undiscoverable.
  final VoidCallback onScanTap;

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
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onScanTap,
              icon: const Icon(Icons.qr_code_scanner, size: 18),
              label: const Text('Scan a QR code'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: AppTheme.bgBase,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
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

/// F6 — Peer link status card pinned under the QR display.
///
/// Reads [peerEntriesProvider], which carries both the persistent peer
/// identities and their runtime BLE lifecycle state, so the card is
/// honest about all three cases instead of always claiming a bound peer:
///
///   * nothing bound yet        → prompt to scan a QR code
///   * bound, no BLE link       → "awaiting proximity link"
///   * bound, BLE link up       → "proximity link established"
class _PeerBoundCard extends ConsumerWidget {
  const _PeerBoundCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries =
        ref.watch(peerEntriesProvider).valueOrNull ?? const <PeerEntry>[];
    final bound = entries.isNotEmpty;
    final linked = entries.any((entry) => entry.isConnected);

    final Color color;
    final String title;
    final String subtitle;
    if (!bound) {
      color = AppTheme.textTertiary;
      title = 'NO PEER BOUND';
      subtitle = 'scan a QR code to bind a peer';
    } else if (linked) {
      color = AppTheme.green;
      title = 'PEER BOUND';
      subtitle = 'proximity link established';
    } else {
      color = AppTheme.amber;
      title = 'PEER BOUND';
      subtitle = 'awaiting proximity link';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.bgSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.45)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                bound ? Icons.link : Icons.link_off,
                size: 18,
                color: color,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTheme.labelMedium.copyWith(
                      color: color,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTheme.caption.copyWith(
                      color: AppTheme.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
