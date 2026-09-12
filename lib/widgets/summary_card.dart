import 'dart:ui';

import 'package:flutter/material.dart';

import '../models/currency.dart';
import '../theme.dart';

/// The one object on screen that is supposed to look expensive: a thin
/// sheet of glass in a champagne rim, cut from whichever material the
/// theme is made of, carrying the two figures that matter at a glance.
///
/// The ranking inside it is deliberate -- the net result is the headline,
/// set large and light; what it was made of (income and spending) sits
/// under it as supporting detail. That is the order a bank states it in,
/// and it is why the card reads as a statement rather than a tally.
class SummaryCard extends StatelessWidget {
  final double todayExpenseTotal;
  final double todayIncomeTotal;
  final double monthExpenseTotal;
  final double monthIncomeTotal;
  final AppCurrency currency;

  /// True when [currency] differs from the currency these totals were
  /// actually recorded in, so the figures are a converted approximation
  /// rather than exact sums. Shown as a small "≈" marker.
  final bool isApproximate;

  const SummaryCard({
    super.key,
    required this.todayExpenseTotal,
    required this.todayIncomeTotal,
    required this.monthExpenseTotal,
    required this.monthIncomeTotal,
    required this.currency,
    this.isApproximate = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        // The rim is what holds the card together now that its fill is
        // this thin: champagne where the light lands, gone by the far
        // corner.
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
        borderRadius: BorderRadius.circular(25),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: heroGradientFor(context),
              borderRadius: BorderRadius.circular(25),
            ),
            child: Stack(
              children: [
                // Two pools of light across the slab: a broad one from the
                // top-left, and a tighter, brighter one riding the upper edge --
                // the way light actually sits on a curved glass surface.
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: const Alignment(-0.85, -1.1),
                          radius: 1.5,
                          colors: [
                            Colors.white.withValues(
                              alpha: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? 0.10
                                  : 0.30,
                            ),
                            Colors.white.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: 70,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withValues(
                              alpha: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? 0.07
                                  : 0.22,
                            ),
                            Colors.white.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _SummaryItem(
                          label: 'СЕГОДНЯ',
                          expenseTotal: todayExpenseTotal,
                          incomeTotal: todayIncomeTotal,
                          currency: currency,
                          isApproximate: isApproximate,
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 92,
                        margin: const EdgeInsets.symmetric(horizontal: 18),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              heroForeground(context).withValues(alpha: 0),
                              heroForeground(context).withValues(alpha: 0.16),
                              heroForeground(context).withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        child: _SummaryItem(
                          label: 'ЗА МЕСЯЦ',
                          expenseTotal: monthExpenseTotal,
                          incomeTotal: monthIncomeTotal,
                          currency: currency,
                          isApproximate: isApproximate,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final double expenseTotal;
  final double incomeTotal;
  final AppCurrency currency;
  final bool isApproximate;

  const _SummaryItem({
    required this.label,
    required this.expenseTotal,
    required this.incomeTotal,
    required this.currency,
    this.isApproximate = false,
  });

  @override
  Widget build(BuildContext context) {
    final net = incomeTotal - expenseTotal;
    // Marks converted figures so they don't read as exact sums.
    String approx(String amount) => isApproximate ? '≈ $amount' : amount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.4,
            color: goldFor(context),
          ),
        ),
        const SizedBox(height: 12),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            approx(
              net >= 0
                  ? currency.format.format(net)
                  : '−${currency.format.format(net.abs())}',
            ),
            maxLines: 1,
            softWrap: false,
            style: moneyStyle(
              size: 26,
              weight: FontWeight.w300,
              color: heroForeground(context),
              letterSpacing: -0.6,
            ),
          ),
        ),
        const SizedBox(height: 14),
        _Leg(
          color: incomeColor(context),
          amount: approx('+${currency.format.format(incomeTotal)}'),
        ),
        const SizedBox(height: 6),
        _Leg(
          color: expenseColor(context),
          amount: approx('−${currency.format.format(expenseTotal)}'),
        ),
      ],
    );
  }
}

/// One of the two figures the headline is made of, marked by a small dot in
/// its own colour rather than a coloured number -- on a dark slab a full
/// line of colour shouts; a dot states.
class _Leg extends StatelessWidget {
  final Color color;
  final String amount;

  const _Leg({required this.color, required this.amount});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              amount,
              maxLines: 1,
              softWrap: false,
              style: moneyStyle(
                size: 12.5,
                weight: FontWeight.w400,
                color: heroForeground(context).withValues(alpha: 0.68),
                letterSpacing: -0.1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
