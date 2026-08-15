import 'package:flutter/material.dart';
import 'package:qr/qr.dart';

/// Renders [data] as a QR code using the pure-Dart `qr` encoder.
///
/// The widget paints the module matrix itself (no image decoding, no
/// platform channels), draws a quiet zone around the pattern and labels the
/// result for screen readers. Malformed/oversized payloads fall back to an
/// error tile instead of throwing in the build phase.
class OneBitQrCode extends StatelessWidget {
  const OneBitQrCode({
    required this.data,
    this.semanticsLabel,
    this.errorCorrection = QrErrorCorrectLevel.medium,
    super.key,
  });

  /// Text payload to encode.
  final String data;

  /// Accessible label of the code (e.g. "Identity card").
  final String? semanticsLabel;

  /// Error correction level (default medium balances density and robustness).
  final QrErrorCorrectLevel errorCorrection;

  /// Fraction of the canvas reserved for the quiet zone.
  static const double quietZone = 0.08;

  @override
  Widget build(BuildContext context) {
    final QrImage? image;
    try {
      final code = QrCode(
        payload: QrPayload.fromString(data),
        errorCorrectLevel: errorCorrection,
      );
      image = QrImage(code);
    } on Object {
      return _ErrorTile(semanticsLabel: semanticsLabel);
    }

    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: semanticsLabel,
      image: true,
      child: CustomPaint(
        painter: _QrPainter(
          image: image,
          darkColor: scheme.onSurface,
          lightColor: Colors.transparent,
          quietZone: quietZone,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

final class _QrPainter extends CustomPainter {
  const _QrPainter({
    required this.image,
    required this.darkColor,
    required this.lightColor,
    required this.quietZone,
  });

  final QrImage image;
  final Color darkColor;
  final Color lightColor;
  final double quietZone;

  @override
  void paint(Canvas canvas, Size size) {
    final modules = image.moduleCount;
    final cell = size.shortestSide / (modules + 2 * quietZone * modules);
    final offset = (size.shortestSide - cell * modules) / 2;
    final darkPaint = Paint()..color = darkColor;
    final lightPaint = Paint()..color = lightColor;

    for (var row = 0; row < modules; row++) {
      for (var col = 0; col < modules; col++) {
        final rect = Rect.fromLTWH(
          offset + col * cell,
          offset + row * cell,
          cell + 0.5,
          cell + 0.5,
        );
        canvas.drawRect(rect, image.isDark(row, col) ? darkPaint : lightPaint);
      }
    }
  }

  @override
  bool shouldRepaint(_QrPainter oldDelegate) =>
      oldDelegate.image != image ||
      oldDelegate.darkColor != darkColor ||
      oldDelegate.quietZone != quietZone;
}

final class _ErrorTile extends StatelessWidget {
  const _ErrorTile({this.semanticsLabel});

  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: semanticsLabel,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.qr_code_2_rounded,
          size: 48,
          color: scheme.onErrorContainer,
        ),
      ),
    );
  }
}
