import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/currency.dart';
import '../models/expense.dart';
import '../models/expense_category.dart';
import '../theme.dart';

final _dateFormat = DateFormat('d MMM', 'ru');

class ExpenseTile extends StatelessWidget {
  final Expense expense;
  final AppCurrency currency;
  final VoidCallback? onLongPress;

  /// The amount to display, if it differs from [expense.amount] -- used
  /// when the list is being viewed in a currency other than the one the
  /// expense was actually recorded in. [expense.amount] itself never
  /// changes; only the displayed figure does.
  final double? amountOverride;

  /// True when [amountOverride] is a currency conversion rather than the
  /// recorded amount, so the row can mark itself as approximate.
  final bool isApproximate;

  /// False in the grouped view, where the category header right above the
  /// row already carries that category's icon -- repeating the same icon
  /// on every row under it was the redundant part, not the row's own
  /// title. The title and note stay exactly as they are; only the
  /// leading icon (and the space it took) drops out.
  final bool showIcon;

  const ExpenseTile({
    super.key,
    required this.expense,
    required this.currency,
    this.onLongPress,
    this.amountOverride,
    this.isApproximate = false,
    this.showIcon = true,
  });

  @override
  Widget build(BuildContext context) {
    final isIncome = expense.isIncome;
    final color = isIncome ? kIncomeColor : expense.category!.color;
    final icon =
        isIncome ? Icons.arrow_downward_rounded : expense.category!.icon;
    final title = isIncome ? 'Доход' : expense.category!.label;
    final sign = isIncome ? '+' : '−';
    final displayAmount = amountOverride ?? expense.amount;
    final approxPrefix = isApproximate ? '≈ ' : '';
    final mutedColor =
        Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6);

    return Card(
      color: Theme.of(context).cardTheme.color?.withValues(alpha: 0.82),
      child: InkWell(
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // The amount is given a share of the row rather than whatever it
              // wants: a seven-digit sum on a small screen used to push the row
              // past its width. Inside that share it scales down to fit, so it
              // stays readable instead of being clipped.
              final amountMaxWidth = constraints.maxWidth * 0.42;
              return Row(
                children: [
                  if (showIcon) ...[
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
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
                              color: mutedColor,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: amountMaxWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            '$approxPrefix$sign${currency.format.format(displayAmount)}',
                            maxLines: 1,
                            softWrap: false,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.normal,
                              color: isIncome ? kIncomeColor : kExpenseColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            _dateFormat.format(expense.date),
                            maxLines: 1,
                            softWrap: false,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.color
                                  ?.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
