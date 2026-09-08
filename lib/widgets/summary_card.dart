import 'package:flutter/material.dart';

import '../models/currency.dart';

const _incomeColor = Color(0xFF6EE7A8);
const _cardStart = Color(0xFF4D4D4D);
const _cardEnd = Color(0xFF655C81);

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
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_cardStart, _cardEnd],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _cardStart.withValues(alpha: 0.25),
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
            height: 48,
            margin: const EdgeInsets.only(top: 4),
            color: Colors.white.withValues(alpha: 0.15),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${expenseTotal > 0 ? '−' : ''}${currency.format.format(expenseTotal)}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        if (incomeTotal > 0)
          Text(
            '+${currency.format.format(incomeTotal)}',
            style: const TextStyle(
              color: _incomeColor,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
      ],
    );
  }
}
