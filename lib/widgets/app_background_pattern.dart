import 'package:flutter/material.dart';

class AppBackgroundPattern extends StatelessWidget {
  final Widget child;

  const AppBackgroundPattern({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final color =
        Theme.of(context).colorScheme.primary.withValues(alpha: 0.035);
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
    Icons.savings_rounded,
    Icons.attach_money_rounded,
    Icons.receipt_long_rounded,
    Icons.pie_chart_rounded,
    Icons.credit_card_rounded,
    Icons.shopping_bag_rounded,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    const spacing = 88.0;
    var row = 0;
    for (double y = -20; y < size.height + spacing; y += spacing) {
      final rowOffset = row.isEven ? 0.0 : spacing / 2;
      var iconIndex = row;
      for (double x = -20 + rowOffset; x < size.width + spacing; x += spacing) {
        final icon = _icons[iconIndex % _icons.length];
        final textPainter = TextPainter(
          text: TextSpan(
            text: String.fromCharCode(icon.codePoint),
            style: TextStyle(
              fontSize: 26,
              fontFamily: icon.fontFamily,
              package: icon.fontPackage,
              color: color,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        textPainter.paint(canvas, Offset(x, y));
        iconIndex++;
      }
      row++;
    }
  }

  @override
  bool shouldRepaint(covariant _PatternPainter oldDelegate) =>
      oldDelegate.color != color;
}
