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
        color: kAccentColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SummaryItem(
              label: 'Сегодня',
              value: currencyFormat.format(todayTotal),
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: Colors.white.withValues(alpha: 0.15),
          ),
          Expanded(
            child: _SummaryItem(
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
  final String label;
  final String value;

  const _SummaryItem({required this.label, required this.value});

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
