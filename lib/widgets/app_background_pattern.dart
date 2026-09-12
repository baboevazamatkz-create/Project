import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// The room the whole app sits in: a soft vertical wash, two barely-there
/// pools of champagne light, and a fine diagonal grain over the top.
///
/// It replaced a scatter of money glyphs. At this scale a literal pattern
/// of wallets and coins reads as decoration on a free app; light and grain
/// read as material, which is the whole point of the redesign.
class AppBackgroundPattern extends StatelessWidget {
  final Widget child;

  const AppBackgroundPattern({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            // Its own layer: the background never changes while the list
            // above it scrolls, so it should never repaint with it.
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _AtmospherePainter(
                  gradient: pageGradient(context),
                  glow: kPatternColor,
                  isDark: isDark,
                ),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _AtmospherePainter extends CustomPainter {
  final LinearGradient gradient;
  final Color glow;
  final bool isDark;

  _AtmospherePainter({
    required this.gradient,
    required this.glow,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..shader = gradient.createShader(rect));

    // Warm light from high on the right, and a second, weaker pool low on
    // the left, so the page has a direction to it instead of reading flat.
    void pool(Offset centre, double radius, double alpha) {
      canvas.drawCircle(
        centre,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [glow.withValues(alpha: alpha), glow.withValues(alpha: 0)],
          ).createShader(Rect.fromCircle(center: centre, radius: radius)),
      );
    }

    pool(
      Offset(size.width * 0.86, size.height * 0.06),
      size.width * 0.95,
      isDark ? 0.11 : 0.16,
    );
    pool(
      Offset(size.width * 0.05, size.height * 0.78),
      size.width * 0.8,
      isDark ? 0.06 : 0.09,
    );

    // A fine diagonal grain -- invisible as lines, felt as texture.
    final grain = Paint()
      ..color = (isDark ? Colors.white : kAccentColor)
          .withValues(alpha: isDark ? 0.022 : 0.018)
      ..strokeWidth = 1;
    const spacing = 26.0;
    final diagonal = size.width + size.height;
    for (var offset = -size.height; offset < diagonal; offset += spacing) {
      canvas.drawLine(
        Offset(offset, 0),
        Offset(offset + size.height, size.height),
        grain,
      );
    }

    // One long highlight raking across the upper third, the way light
    // catches a brushed surface.
    final sheenRect = Rect.fromLTWH(0, 0, size.width, size.height * 0.42);
    canvas.drawRect(
      sheenRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: isDark ? 0.030 : 0.34),
            Colors.white.withValues(alpha: 0),
          ],
          stops: const [0.0, 0.7],
          transform: const GradientRotation(math.pi / 14),
        ).createShader(sheenRect),
    );
  }

  @override
  bool shouldRepaint(covariant _AtmospherePainter oldDelegate) =>
      oldDelegate.isDark != isDark ||
      oldDelegate.glow != glow ||
      oldDelegate.gradient != gradient;
}
