import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/currency.dart';
import '../models/expense.dart';
import '../models/expense_category.dart';

const _incomeColor = Color(0xFF16A34A);
const _expenseColor = Color(0xFFDC2626);

class ExpenseTile extends StatelessWidget {
  final Expense expense;
  final AppCurrency currency;
  final VoidCallback? onLongPress;

  const ExpenseTile({
    super.key,
    required this.expense,
    required this.currency,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('d MMM', 'ru');
    final isIncome = expense.isIncome;
    final color = isIncome ? _incomeColor : expense.category!.color;
    final icon = isIncome ? Icons.arrow_upward_rounded : expense.category!.icon;
    final title = isIncome ? 'Доход' : expense.category!.label;
    final sign = isIncome ? '+' : '−';

    return Card(
      color: Theme.of(context).cardTheme.color?.withValues(alpha: 0.82),
      child: InkWell(
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                    if (expense.note.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        expense.note,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.color
                              ?.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$sign${currency.format.format(expense.amount)}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.normal,
                      color: isIncome ? _incomeColor : _expenseColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dateFormat.format(expense.date),
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.color
                          ?.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
