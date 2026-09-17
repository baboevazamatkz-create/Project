import 'package:flutter/material.dart';

import '../theme.dart';

/// The vertical tab standing beside [SummaryCard]: the totals card states
/// what happened, this is the one thing on that row offering to explain it.
///
/// Built to read as the summary card's own edge rather than a separate
/// button -- same rim gradient, same corner radius, same shadow -- so the
/// two look like one object with a fold in it, not a card and a stray icon
/// beside it. [height] is passed in explicitly and the widget is given the
/// card's own height at the call site (a `Row` with `CrossAxisAlignment
/// .stretch` sizes it from the sibling automatically); a plain [SizedBox]
/// height would have to duplicate the card's own sizing logic instead.
class AdviceTabButton extends StatelessWidget {
  final VoidCallback onTap;

  const AdviceTabButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            goldFor(context).withValues(alpha: 0.62),
            goldFor(context).withValues(alpha: 0.20),
            goldFor(context).withValues(alpha: 0.08),
          ],
          stops: const [0.0, 0.42, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: kAccentColor.withValues(
              alpha:
                  Theme.of(context).brightness == Brightness.dark ? 0.34 : 0.12,
            ),
            blurRadius: 34,
            spreadRadius: -8,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      padding: const EdgeInsets.all(1),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(21),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: heroGradientFor(context),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    size: 18,
                    color: goldFor(context),
                  ),
                  const SizedBox(height: 10),
                  RotatedBox(
                    quarterTurns: 3,
                    child: Text(
                      'СОВЕТЫ',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2.2,
                        color: heroForeground(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
