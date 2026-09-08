import 'package:flutter/material.dart';

import '../models/currency.dart';
import '../theme.dart';

const _incomeColor = Color(0xFF6EE7A8);

class SummaryCard extends StatelessWidget {
  final Map<AppCurrency, double> todayExpenseTotals;
  final Map<AppCurrency, double> todayIncomeTotals;
  final Map<AppCurrency, double> monthExpenseTotals;
  final Map<AppCurrency, double> monthIncomeTotals;

  const SummaryCard({
    super.key,
    required this.todayExpenseTotals,
    required this.todayIncomeTotals,
    required this.monthExpenseTotals,
    required this.monthIncomeTotals,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [kAccentColor, Color(0xFF4A3F6B)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: kAccentColor.withValues(alpha: 0.3),
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
              icon: Icons.today_rounded,
              iconColor: const Color(0xFFFFB84C),
              label: 'Сегодня',
              expenseTotals: todayExpenseTotals,
              incomeTotals: todayIncomeTotals,
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
              icon: Icons.calendar_month_rounded,
              iconColor: const Color(0xFF4ADEDE),
              label: 'За месяц',
              expenseTotals: monthExpenseTotals,
              incomeTotals: monthIncomeTotals,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final Map<AppCurrency, double> expenseTotals;
  final Map<AppCurrency, double> incomeTotals;

  const _SummaryItem({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.expenseTotals,
    required this.incomeTotals,
  });

  @override
  Widget build(BuildContext context) {
    final currencies = AppCurrency.values
        .where((c) => (expenseTotals[c] ?? 0) > 0 || (incomeTotals[c] ?? 0) > 0)
        .toList();
    if (currencies.isEmpty) currencies.add(AppCurrency.rub);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        for (final currency in currencies) ...[
          Text(
            '${(expenseTotals[currency] ?? 0) > 0 ? '−' : ''}'
            '${currency.format.format(expenseTotals[currency] ?? 0)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          if ((incomeTotals[currency] ?? 0) > 0)
            Text(
              '+${currency.format.format(incomeTotals[currency]!)}',
              style: const TextStyle(
                color: _incomeColor,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          const SizedBox(height: 4),
        ],
      ],
    );
  }
}
