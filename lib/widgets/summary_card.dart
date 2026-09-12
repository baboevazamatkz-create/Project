import 'dart:ui';

import 'package:flutter/material.dart';

import '../models/currency.dart';
import '../theme.dart';

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
    final baseColor = Theme.of(context).cardTheme.color ?? Colors.white;
    final tintedColor = Color.alphaBlend(
      kBrandColor.withValues(alpha: 0.06),
      baseColor,
    );
    // The one card on screen worth an actual frosted-glass blur rather than
    // just a translucent fill -- there's only ever one of it, so the extra
    // compositing cost that would add up across a scrolling list of rows is
    // a non-issue here.
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: tintedColor.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: hairlineColor(context)),
            boxShadow: [
              BoxShadow(
                color: kAccentColor.withValues(
                  alpha: Theme.of(context).brightness == Brightness.dark
                      ? 0.35
                      : 0.08,
                ),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _SummaryItem(
                  label: 'Сегодня',
                  expenseTotal: todayExpenseTotal,
                  incomeTotal: todayIncomeTotal,
                  currency: currency,
                  isApproximate: isApproximate,
                ),
              ),
              Container(
                width: 1,
                height: 78,
                margin: const EdgeInsets.only(top: 4),
                color: Theme.of(context).dividerTheme.color,
              ),
              Expanded(
                child: _SummaryItem(
                  label: 'За месяц',
                  expenseTotal: monthExpenseTotal,
                  incomeTotal: monthIncomeTotal,
                  currency: currency,
                  isApproximate: isApproximate,
                ),
              ),
            ],
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
    final bodyColor = Theme.of(context).textTheme.bodyMedium?.color;
    final amountStyle = TextStyle(
      color: bodyColor,
      fontSize: 13,
      fontWeight: FontWeight.normal,
    );
    // Marks converted figures so they don't read as exact sums.
    String approx(String amount) => isApproximate ? '≈ $amount' : amount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: bodyColor,
            fontSize: 17,
            fontWeight: FontWeight.normal,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          approx('+${currency.format.format(incomeTotal)}'),
          style: amountStyle.copyWith(color: kIncomeColor),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 3),
        Text(
          approx('−${currency.format.format(expenseTotal)}'),
          style: amountStyle.copyWith(color: kExpenseColor),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Итого',
          style: TextStyle(
            color: bodyColor?.withValues(alpha: 0.5),
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          approx(
            net >= 0
                ? currency.format.format(net)
                : '−${currency.format.format(net.abs())}',
          ),
          style: amountStyle.copyWith(
            color: net >= 0 ? kIncomeColor : kExpenseColor,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
