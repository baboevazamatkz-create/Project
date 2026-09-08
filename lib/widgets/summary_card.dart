import 'package:flutter/material.dart';

import '../models/currency.dart';
import '../theme.dart';

class SummaryCard extends StatelessWidget {
  final Map<AppCurrency, double> todayTotals;
  final Map<AppCurrency, double> monthTotals;

  const SummaryCard({
    super.key,
    required this.todayTotals,
    required this.monthTotals,
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
              totals: todayTotals,
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
              totals: monthTotals,
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
  final Map<AppCurrency, double> totals;

  const _SummaryItem({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.totals,
  });

  @override
  Widget build(BuildContext context) {
    final entries = totals.entries.toList();
    final values = entries.isEmpty
        ? [AppCurrency.rub.format.format(0)]
        : entries.map((e) => e.key.format.format(e.value)).toList();

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
        for (final value in values)
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
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
