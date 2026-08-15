import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// The camera scanning seam of the QR feature.
///
/// Presentation owns the phase machine; the service owns the platform
/// camera. Tests override [qrScannerServiceProvider] with a fake that
/// renders a plain box and feeds detections programmatically.
abstract interface class QrScannerService {
  /// Requests camera permission and starts the preview. Returns false when
  /// the user refused (or the device has no camera).
  Future<bool> ensurePermission();

  /// (Re)starts the camera pipeline.
  Future<void> start();

  /// Stops the camera pipeline.
  Future<void> stop();

  /// Releases platform resources.
  void dispose();

  /// Builds the live camera preview; [onDetect] fires with every decoded
  /// text payload.
  Widget buildPreview(
    BuildContext context, {
    required ValueChanged<String> onDetect,
  });
}

/// Production scanner over the mobile_scanner plugin.
final class MobileQrScannerService implements QrScannerService {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );

  @override
  Future<bool> ensurePermission() async {
    try {
      await _controller.start();
      return true;
    } on MobileScannerException catch (error) {
      return error.errorCode != MobileScannerErrorCode.permissionDenied;
    } on Object {
      return false;
    }
  }

  @override
  Future<void> start() => _controller.start();

  @override
  Future<void> stop() => _controller.stop();

  @override
  void dispose() => _controller.dispose();

  @override
  Widget buildPreview(
    BuildContext context, {
    required ValueChanged<String> onDetect,
  }) {
    return MobileScanner(
      controller: _controller,
      fit: BoxFit.cover,
      onDetect: (capture) {
        for (final barcode in capture.barcodes) {
          final text = barcode.rawValue;
          if (text != null && text.isNotEmpty) {
            onDetect(text);
            return;
          }
        }
      },
    );
  }
}

final qrScannerServiceProvider = Provider<QrScannerService>((ref) {
  final service = MobileQrScannerService();
  ref.onDispose(service.dispose);
  return service;
});
