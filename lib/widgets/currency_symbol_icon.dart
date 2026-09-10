import 'package:flutter/material.dart';

import '../models/currency.dart';

/// Renders a currency's own symbol (₽, ₸, $) in the footprint of a 24dp
/// Material icon, so it drops into the same slots a generic money icon
/// used to occupy (a text field's prefixIcon, a row's leading icon
/// circle) -- but never implies "dollar" for a ruble or tenge budget.
class CurrencySymbolIcon extends StatelessWidget {
  final AppCurrency currency;
  final double size;
  final Color? color;

  const CurrencySymbolIcon({
    super.key,
    required this.currency,
    this.size = 24,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Text(
          currency.symbol,
          style: TextStyle(
            fontSize: size * 0.72,
            fontWeight: FontWeight.w600,
            // Falls back to whatever an Icon would have used here, so
            // swapping one for the other doesn't change the surrounding
            // tone (e.g. TextField's prefixIcon slot tints icons itself).
            color: color ?? IconTheme.of(context).color,
          ),
        ),
      ),
    );
  }
}
