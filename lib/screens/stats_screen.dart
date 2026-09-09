import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/budget_repository.dart';
import '../models/currency.dart';
import '../models/expense.dart';
import '../models/expense_category.dart';
import '../theme.dart';

final _monthFormat = DateFormat('LLL', 'ru');

class StatsScreen extends StatefulWidget {
  final String householdCode;
  final AppCurrency currency;
  final List<Expense> expenses;

  const StatsScreen({
    super.key,
    required this.householdCode,
    required this.currency,
    required this.expenses,
  });

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen>
    with SingleTickerProviderStateMixin {
  final _budgetRepository = BudgetRepository();
  late final TabController _tabController;

  // Aggregated once here rather than per build: the expense list is a fixed
  // snapshot for this screen, so recomputing it on every rebuild (and
  // re-opening the budgets stream with it) is pure waste.
  late final List<MapEntry<ExpenseCategory, double>> _categoryEntries;
  late final List<MapEntry<DateTime, double>> _monthlyTotals;
  late final Stream<Map<String, double>> _budgetsStream;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _budgetsStream = _budgetRepository.watchBudgets(widget.householdCode);
    _categoryEntries = _buildCategoryEntries();
    _monthlyTotals = _buildMonthlyTotals();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<MapEntry<ExpenseCategory, double>> _buildCategoryEntries() {
    final now = DateTime.now();
    final totals = <ExpenseCategory, double>{};
    for (final expense in widget.expenses) {
      if (expense.isIncome) continue;
      final date = expense.date;
      if (date.year != now.year || date.month != now.month) continue;
      final category = expense.category!;
      totals[category] = (totals[category] ?? 0) + expense.amount;
    }
    return totals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  }

  List<MapEntry<DateTime, double>> _buildMonthlyTotals() {
    final now = DateTime.now();
    final months =
        List.generate(6, (i) => DateTime(now.year, now.month - (5 - i)));
    final totals = {for (final m in months) m: 0.0};
    for (final expense in widget.expenses) {
      if (expense.isIncome) continue;
      final key = DateTime(expense.date.year, expense.date.month);
      final current = totals[key];
      if (current != null) totals[key] = current + expense.amount;
    }
    return months.map((m) => MapEntry(m, totals[m]!)).toList();
  }

  String _monthLabel(DateTime month) => _monthFormat.format(month);

  Future<void> _editBudget(ExpenseCategory category, double? current) async {
    final controller = TextEditingController(
      text: current != null && current > 0 ? current.toStringAsFixed(0) : '',
    );
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Лимит: ${category.label}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            hintText: 'Сумма в месяц, ${widget.currency.symbol}',
          ),
        ),
        actions: [
          if (current != null)
            TextButton(
              onPressed: () => Navigator.of(context).pop(''),
              child: const Text('Убрать лимит'),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    if (result == null) return;
    final amount =
        result.isEmpty ? null : double.tryParse(result.replaceAll(',', '.'));
    await _budgetRepository.setBudget(widget.householdCode, category, amount);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Статистика'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Категории'),
            Tab(text: 'История'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          CategoriesTab(
            entries: _categoryEntries,
            currency: widget.currency,
            budgetsStream: _budgetsStream,
            onEditBudget: _editBudget,
          ),
          HistoryTab(
            monthlyTotals: _monthlyTotals,
            currency: widget.currency,
            monthLabel: _monthLabel,
          ),
        ],
      ),
    );
  }
}

class CategoriesTab extends StatelessWidget {
  final List<MapEntry<ExpenseCategory, double>> entries;
  final AppCurrency currency;
  final Stream<Map<String, double>> budgetsStream;
  final void Function(ExpenseCategory category, double? current) onEditBudget;

  const CategoriesTab({
    super.key,
    required this.entries,
    required this.currency,
    required this.budgetsStream,
    required this.onEditBudget,
  });

  @override
  Widget build(BuildContext context) {
    final total = entries.fold(0.0, (sum, e) => sum + e.value);

    return StreamBuilder<Map<String, double>>(
      stream: budgetsStream,
      builder: (context, snapshot) {
        final budgets = snapshot.data ?? const {};

        if (entries.isEmpty) {
          return Center(
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
          );
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            Text(
              'За текущий месяц',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.normal,
                color: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.color
                    ?.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 28),
            // The chart is sized from the width actually available so it fits
            // narrow phones and gets no larger than it needs to on wide ones.
            LayoutBuilder(
              builder: (context, constraints) {
                final diameter = constraints.maxWidth.clamp(180.0, 300.0);
                final ringRadius = diameter * 0.31;
                final centerRadius = diameter * 0.185;
                return SizedBox(
                  height: diameter,
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
                              radius: ringRadius,
                              titleStyle: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.normal,
                                fontSize: 13,
                              ),
                            );
                          }).toList(),
                          sectionsSpace: 2,
                          centerSpaceRadius: centerRadius,
                        ),
                      ),
                      SizedBox(
                        width: centerRadius * 1.7,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Всего',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                currency.format.format(total),
                                maxLines: 1,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.normal,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 28),
            for (final entry in entries)
              () {
                final budget = BudgetRepository.budgetFor(budgets, entry.key);
                return _CategoryRow(
                  category: entry.key,
                  amount: entry.value,
                  currency: currency,
                  budget: budget,
                  onTap: () => onEditBudget(entry.key, budget),
                );
              }(),
          ],
        );
      },
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final ExpenseCategory category;
  final double amount;
  final AppCurrency currency;
  final double? budget;
  final VoidCallback onTap;

  const _CategoryRow({
    required this.category,
    required this.amount,
    required this.currency,
    required this.budget,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final budgetValue = budget;
    final progress = budgetValue != null && budgetValue > 0
        ? (amount / budgetValue).clamp(0.0, 1.5)
        : null;
    final isOverBudget = progress != null && progress >= 1.0;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                // Same deal as the expense rows: the figures get a bounded
                // share of the row and shrink inside it, so they stay flush
                // right and the category name keeps whatever is left.
                final amountMaxWidth = constraints.maxWidth * 0.5;
                return Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: category.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child:
                          Icon(category.icon, color: category.color, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        category.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.normal),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: amountMaxWidth),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          budgetValue != null
                              ? '${currency.format.format(amount)} / ${currency.format.format(budgetValue)}'
                              : currency.format.format(amount),
                          maxLines: 1,
                          softWrap: false,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.normal,
                            color: isOverBudget ? kExpenseColor : null,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            if (progress != null) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 48),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: category.color.withValues(alpha: 0.12),
                    color: isOverBudget ? kExpenseColor : category.color,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class HistoryTab extends StatelessWidget {
  final List<MapEntry<DateTime, double>> monthlyTotals;
  final AppCurrency currency;
  final String Function(DateTime month) monthLabel;

  const HistoryTab({
    super.key,
    required this.monthlyTotals,
    required this.currency,
    required this.monthLabel,
  });

  static const _lowColor = Color(0xFF3B82F6);
  static const _highColor = Color(0xFFEF4444);

  Color _colorForValue(double value, double maxValue) {
    if (maxValue <= 0) return _lowColor;
    final t = (value / maxValue).clamp(0.0, 1.0);
    return Color.lerp(_lowColor, _highColor, t)!;
  }

  @override
  Widget build(BuildContext context) {
    final maxValue =
        monthlyTotals.fold(0.0, (m, e) => e.value > m ? e.value : m);

    if (maxValue == 0) {
      return Center(
        child: Text(
          'Пока недостаточно данных',
          style: TextStyle(
            fontSize: 16,
            color: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.color
                ?.withValues(alpha: 0.6),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Расходы за последние 6 месяцев',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.normal,
              color: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.color
                  ?.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxValue * 1.2,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= monthlyTotals.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            monthLabel(monthlyTotals[index].key),
                            style: const TextStyle(fontSize: 11),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < monthlyTotals.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: monthlyTotals[i].value,
                          color:
                              _colorForValue(monthlyTotals[i].value, maxValue),
                          width: 22,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
