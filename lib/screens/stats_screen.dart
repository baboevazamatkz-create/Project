import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/currency.dart';
import '../models/expense.dart';
import '../models/expense_category.dart';
import '../theme.dart';

class StatsScreen extends StatefulWidget {
  final List<Expense> expenses;

  const StatsScreen({super.key, required this.expenses});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  late final List<Expense> _monthExpenses;
  late final List<AppCurrency> _availableCurrencies;
  late AppCurrency _selectedCurrency;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _monthExpenses = widget.expenses
        .where((e) =>
            !e.isIncome && e.date.year == now.year && e.date.month == now.month)
        .toList();
    _availableCurrencies = AppCurrency.values
        .where((c) => _monthExpenses.any((e) => e.currency == c))
        .toList();
    _selectedCurrency = _availableCurrencies.isNotEmpty
        ? _availableCurrencies.first
        : AppCurrency.rub;
  }

  Map<ExpenseCategory, double> get _categoryTotals {
    final totals = <ExpenseCategory, double>{};
    for (final expense
        in _monthExpenses.where((e) => e.currency == _selectedCurrency)) {
      final category = expense.category!;
      totals[category] = (totals[category] ?? 0) + expense.amount;
    }
    return totals;
  }

  @override
  Widget build(BuildContext context) {
    final totals = _categoryTotals;
    final total = totals.values.fold(0.0, (sum, value) => sum + value);
    final entries = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Scaffold(
      appBar: AppBar(title: const Text('По категориям')),
      body: entries.isEmpty
          ? Center(
              child: Text(
                'Нет расходов за этот месяц',
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.color
                      ?.withValues(alpha: 0.6),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: [
                Text(
                  'За текущий месяц',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.color
                        ?.withValues(alpha: 0.6),
                  ),
                ),
                if (_availableCurrencies.length > 1) ...[
                  const SizedBox(height: 16),
                  Center(
                    child: _CurrencySelector(
                      currencies: _availableCurrencies,
                      selected: _selectedCurrency,
                      onChanged: (currency) =>
                          setState(() => _selectedCurrency = currency),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  height: 220,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          sections: entries.map((entry) {
                            final percent =
                                total == 0 ? 0.0 : entry.value / total * 100;
                            return PieChartSectionData(
                              value: entry.value,
                              color: entry.key.color,
                              title: percent >= 6
                                  ? '${percent.toStringAsFixed(0)}%'
                                  : '',
                              radius: 88,
                              titleStyle: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            );
                          }).toList(),
                          sectionsSpace: 2,
                          centerSpaceRadius: 52,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Всего',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.color
                                  ?.withValues(alpha: 0.5),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _selectedCurrency.format.format(total),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                for (final entry in entries)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: entry.key.color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(entry.key.icon,
                              color: entry.key.color, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            entry.key.label,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          _selectedCurrency.format.format(entry.value),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

class _CurrencySelector extends StatelessWidget {
  final List<AppCurrency> currencies;
  final AppCurrency selected;
  final ValueChanged<AppCurrency> onChanged;

  const _CurrencySelector({
    required this.currencies,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).inputDecorationTheme.fillColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: currencies.map((currency) {
          final isSelected = currency == selected;
          return GestureDetector(
            onTap: () => onChanged(currency),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 44,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? kAccentColor : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                currency.symbol,
                style: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
