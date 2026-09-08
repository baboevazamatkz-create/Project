import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme.dart';

class SummaryCard extends StatelessWidget {
  final double todayTotal;
  final double monthTotal;
  final NumberFormat currencyFormat;

  const SummaryCard({
    super.key,
    required this.todayTotal,
    required this.monthTotal,
    required this.currencyFormat,
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
        children: [
          Expanded(
            child: _SummaryItem(
              icon: Icons.today_rounded,
              iconColor: const Color(0xFFFFB84C),
              label: 'Сегодня',
              value: currencyFormat.format(todayTotal),
            ),
          ),
          Container(
            width: 1,
            height: 48,
            color: Colors.white.withValues(alpha: 0.15),
          ),
          Expanded(
            child: _SummaryItem(
              icon: Icons.calendar_month_rounded,
              iconColor: const Color(0xFF4ADEDE),
              label: 'За месяц',
              value: currencyFormat.format(monthTotal),
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
  final String value;

  const _SummaryItem({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
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
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
