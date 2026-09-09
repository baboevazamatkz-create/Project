import 'package:flutter/material.dart';

import '../models/currency.dart';

const _incomeColor = Color(0xFF16A34A);
const _expenseColor = Color(0xFFDC2626);

class SummaryCard extends StatelessWidget {
  final double todayExpenseTotal;
  final double todayIncomeTotal;
  final double monthExpenseTotal;
  final double monthIncomeTotal;
  final AppCurrency currency;

  const SummaryCard({
    super.key,
    required this.todayExpenseTotal,
    required this.todayIncomeTotal,
    required this.monthExpenseTotal,
    required this.monthIncomeTotal,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
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
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final double expenseTotal;
  final double incomeTotal;
  final AppCurrency currency;

  const _SummaryItem({
    required this.label,
    required this.expenseTotal,
    required this.incomeTotal,
    required this.currency,
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(
            color: bodyColor,
            fontSize: 17,
            fontWeight: FontWeight.normal,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '+${currency.format.format(incomeTotal)}',
          style: amountStyle.copyWith(color: _incomeColor),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 3),
        Text(
          '−${currency.format.format(expenseTotal)}',
          style: amountStyle.copyWith(color: _expenseColor),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Container(
          width: 36,
          height: 1,
          color: Theme.of(context).dividerTheme.color,
        ),
        const SizedBox(height: 6),
        Text(
          'Итого',
          style: TextStyle(
            color: bodyColor?.withValues(alpha: 0.5),
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          net >= 0
              ? currency.format.format(net)
              : '−${currency.format.format(net.abs())}',
          style: amountStyle.copyWith(
            color: net >= 0 ? _incomeColor : _expenseColor,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
