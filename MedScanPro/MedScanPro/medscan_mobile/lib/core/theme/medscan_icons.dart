import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Distinctive vector icons for MedScan Pro.
///
/// Implements custom monoline clinical healthcare vectors for:
/// - [MedScanScannerIcon]: Optical reticles framing a pharmaceutical capsule.
/// - [MedScanVerifyShieldIcon]: Regulatory medicine verification shield seal.
///
/// Designed on a 24x24 optical grid with 1.75dp stroke weight, rounded caps,
/// and rounded joins to maintain complete visual harmony with the standard
/// monoline interface icon family.
class MedScanIcons {
  const MedScanIcons._();

  /// Distinctive medicine scanning vector icon.
  static Widget scanner({
    Key? key,
    double size = 24.0,
    Color? color,
    double strokeWidth = 1.75,
  }) {
    return MedScanScannerIcon(
      key: key,
      size: size,
      color: color,
      strokeWidth: strokeWidth,
    );
  }

  /// Regulatory drug authenticity verification shield icon.
  static Widget verifyShield({
    Key? key,
    double size = 24.0,
    Color? color,
    double strokeWidth = 1.75,
  }) {
    return MedScanVerifyShieldIcon(
      key: key,
      size: size,
      color: color,
      strokeWidth: strokeWidth,
    );
  }
}

/// Custom painter widget for MedScan Pro's distinctive medicine scanner icon.
class MedScanScannerIcon extends StatelessWidget {
  final double size;
  final Color? color;
  final double strokeWidth;

  const MedScanScannerIcon({
    super.key,
    this.size = 24.0,
    this.color,
    this.strokeWidth = 1.75,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor =
        color ?? IconTheme.of(context).color ?? const Color(0xFF004D40);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        size: Size(size, size),
        painter: _ScannerPainter(color: iconColor, strokeWidth: strokeWidth),
      ),
    );
  }
}

class _ScannerPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  _ScannerPainter({required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24.0;
    canvas.save();
    canvas.scale(scale, scale);

    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // 1. Optical Scanner Corner Brackets
    final bracketPath = Path();

    // Top-Left Bracket
    bracketPath.moveTo(3.5, 7.0);
    bracketPath.lineTo(3.5, 4.5);
    bracketPath.arcToPoint(
      const Offset(4.5, 3.5),
      radius: const Radius.circular(1.0),
    );
    bracketPath.lineTo(7.0, 3.5);

    // Top-Right Bracket
    bracketPath.moveTo(17.0, 3.5);
    bracketPath.lineTo(19.5, 3.5);
    bracketPath.arcToPoint(
      const Offset(20.5, 4.5),
      radius: const Radius.circular(1.0),
    );
    bracketPath.lineTo(20.5, 7.0);

    // Bottom-Right Bracket
    bracketPath.moveTo(20.5, 17.0);
    bracketPath.lineTo(20.5, 19.5);
    bracketPath.arcToPoint(
      const Offset(19.5, 20.5),
      radius: const Radius.circular(1.0),
    );
    bracketPath.lineTo(17.0, 20.5);

    // Bottom-Left Bracket
    bracketPath.moveTo(7.0, 20.5);
    bracketPath.lineTo(4.5, 20.5);
    bracketPath.arcToPoint(
      const Offset(3.5, 19.5),
      radius: const Radius.circular(1.0),
    );
    bracketPath.lineTo(3.5, 17.0);

    canvas.drawPath(bracketPath, paint);

    // 2. Center Pharmaceutical Capsule
    canvas.save();
    canvas.translate(12.0, 12.0);
    canvas.rotate(-math.pi / 6.0); // -30 degrees clinical tilt

    final capsuleRRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: 10.0, height: 5.0),
      const Radius.circular(2.5),
    );
    canvas.drawRRect(capsuleRRect, paint);

    // Central division seam
    canvas.drawLine(const Offset(0.0, -2.5), const Offset(0.0, 2.5), paint);
    canvas.restore();

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ScannerPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
  }
}

/// Custom painter widget for MedScan Pro's distinctive verification shield icon.
class MedScanVerifyShieldIcon extends StatelessWidget {
  final double size;
  final Color? color;
  final double strokeWidth;

  const MedScanVerifyShieldIcon({
    super.key,
    this.size = 24.0,
    this.color,
    this.strokeWidth = 1.75,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor =
        color ?? IconTheme.of(context).color ?? const Color(0xFF059669);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        size: Size(size, size),
        painter: _VerifyShieldPainter(
          color: iconColor,
          strokeWidth: strokeWidth,
        ),
      ),
    );
  }
}

class _VerifyShieldPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  _VerifyShieldPainter({required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24.0;
    canvas.save();
    canvas.scale(scale, scale);

    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // 1. Regulatory Clinical Shield Path
    final shieldPath = Path();
    shieldPath.moveTo(12.0, 2.5);
    shieldPath.lineTo(19.0, 5.0);
    shieldPath.lineTo(19.0, 11.5);
    shieldPath.cubicTo(19.0, 16.5, 16.0, 19.8, 12.0, 21.5);
    shieldPath.cubicTo(8.0, 19.8, 5.0, 16.5, 5.0, 11.5);
    shieldPath.lineTo(5.0, 5.0);
    shieldPath.close();

    canvas.drawPath(shieldPath, paint);

    // 2. Inner Verification Checkmark
    final checkPath = Path();
    checkPath.moveTo(9.0, 12.0);
    checkPath.lineTo(11.0, 14.0);
    checkPath.lineTo(15.5, 9.5);

    canvas.drawPath(checkPath, paint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _VerifyShieldPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
  }
}
