import 'package:flutter/material.dart';

import '../mt_colors.dart';

/// MT5-style diagonal corner ribbon (e.g. Readonly / Demo).
class MtCornerRibbon extends StatelessWidget {
  const MtCornerRibbon({
    super.key,
    required this.label,
    required this.color,
    this.left = false,
    this.size = 56,
    this.fontSize = 11,
  });

  /// Watch / investor — Exness-style "Readonly" (no hyphen).
  const MtCornerRibbon.watch({super.key})
    : label = 'Readonly',
      color = const Color(0xFF757575),
      left = true,
      size = 64,
      fontSize = 10;

  const MtCornerRibbon.demo({super.key})
    : label = 'Demo',
      color = const Color(0xFF46A81E),
      left = false,
      size = 56,
      fontSize = 12;

  final String label;
  final Color color;
  final bool left;
  final double size;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: MtCornerRibbonPainter(
        label: label,
        color: color,
        left: left,
        fontSize: fontSize,
      ),
    );
  }
}

class MtCornerRibbonPainter extends CustomPainter {
  const MtCornerRibbonPainter({
    required this.label,
    required this.color,
    this.left = false,
    this.fontSize = 12,
  });

  final String label;
  final Color color;
  final bool left;
  final double fontSize;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    final w = size.width;
    final a = w * 0.38;
    final b = w * 0.98;
    final Path band;
    final Offset center;
    final double angle;
    if (left) {
      band = Path()
        ..moveTo(b, 0)
        ..lineTo(a, 0)
        ..lineTo(0, a)
        ..lineTo(0, b)
        ..close();
      center = Offset((a + b) / 4, (a + b) / 4);
      angle = -0.785398;
    } else {
      band = Path()
        ..moveTo(w - b, 0)
        ..lineTo(w - a, 0)
        ..lineTo(w, a)
        ..lineTo(w, b)
        ..close();
      center = Offset(w - (a + b) / 4, (a + b) / 4);
      angle = 0.785398;
    }
    canvas.drawPath(band, Paint()..color = color);
    final shadowColor = Color.alphaBlend(
      Colors.black.withValues(alpha: 0.4),
      color,
    );
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontFamily: 'Roboto',
          color: MtColors.foreground,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.15,
          shadows: [
            Shadow(color: shadowColor, offset: const Offset(1, 0), blurRadius: 2),
            Shadow(color: shadowColor, offset: const Offset(-1, 0), blurRadius: 2),
            Shadow(color: shadowColor, offset: const Offset(0, 1), blurRadius: 2),
            Shadow(color: shadowColor, offset: const Offset(0, -1), blurRadius: 2),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    textPainter.paint(
      canvas,
      Offset(-textPainter.width / 2, -textPainter.height / 2),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant MtCornerRibbonPainter oldDelegate) =>
      oldDelegate.label != label ||
      oldDelegate.color != color ||
      oldDelegate.left != left ||
      oldDelegate.fontSize != fontSize;
}
