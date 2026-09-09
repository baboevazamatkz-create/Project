import 'dart:math' as math;

import 'package:flutter/material.dart';

class AppBackgroundPattern extends StatelessWidget {
  final Widget child;

  const AppBackgroundPattern({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary.withValues(alpha: 0.05);
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(painter: _PatternPainter(color: color)),
          ),
        ),
        child,
      ],
    );
  }
}

class _PatternPainter extends CustomPainter {
  final Color color;

  _PatternPainter({required this.color});

  static const _icons = [
    Icons.monetization_on_rounded,
    Icons.attach_money_rounded,
    Icons.receipt_long_rounded,
    Icons.pie_chart_rounded,
    Icons.credit_card_rounded,
    Icons.shopping_bag_rounded,
    Icons.wallet_rounded,
    Icons.trending_up_rounded,
    Icons.local_atm_rounded,
    Icons.percent_rounded,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(7);
    const cell = 100.0;
    final cols = (size.width / cell).ceil() + 1;
    final rows = (size.height / cell).ceil() + 1;

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    for (var row = -1; row < rows; row++) {
      for (var col = -1; col < cols; col++) {
        final jitterX = (random.nextDouble() - 0.5) * cell * 0.6;
        final jitterY = (random.nextDouble() - 0.5) * cell * 0.6;
        final cx = col * cell + cell / 2 + jitterX;
        final cy = row * cell + cell / 2 + jitterY;

        // Occasionally draw a short decorative line/tick instead of an icon.
        if (random.nextDouble() < 0.22) {
          final angle = random.nextDouble() * math.pi;
          final length = 16 + random.nextDouble() * 14;
          final dx = math.cos(angle) * length / 2;
          final dy = math.sin(angle) * length / 2;
          canvas.drawLine(
            Offset(cx - dx, cy - dy),
            Offset(cx + dx, cy + dy),
            linePaint,
          );
          continue;
        }

        final icon = _icons[random.nextInt(_icons.length)];
        final fontSize = 20 + random.nextDouble() * 16;
        final rotation = (random.nextDouble() - 0.5) * math.pi / 2;

        final textPainter = TextPainter(
          text: TextSpan(
            text: String.fromCharCode(icon.codePoint),
            style: TextStyle(
              fontSize: fontSize,
              fontFamily: icon.fontFamily,
              package: icon.fontPackage,
              color: color,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        canvas.save();
        canvas.translate(cx, cy);
        canvas.rotate(rotation);
        textPainter.paint(
          canvas,
          Offset(-textPainter.width / 2, -textPainter.height / 2),
        );
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PatternPainter oldDelegate) =>
      oldDelegate.color != color;
}
