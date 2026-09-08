import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/budget_repository.dart';
import '../models/currency.dart';
import '../models/expense.dart';
import '../models/expense_category.dart';
import '../theme.dart';

class StatsScreen extends StatefulWidget {
  final String householdCode;
  final List<Expense> expenses;

  const StatsScreen({
    super.key,
    required this.householdCode,
    required this.expenses,
  });

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen>
    with SingleTickerProviderStateMixin {
  final _budgetRepository = BudgetRepository();
  late final TabController _tabController;
  late final List<Expense> _monthExpenses;
  late final List<AppCurrency> _availableCurrencies;
  late AppCurrency _selectedCurrency;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    final now = DateTime.now();
    final monthlyExpensesOnly = widget.expenses.where((e) => !e.isIncome);
    _monthExpenses = monthlyExpensesOnly
        .where((e) => e.date.year == now.year && e.date.month == now.month)
        .toList();
    final currenciesInUse = monthlyExpensesOnly.map((e) => e.currency).toSet();
    _availableCurrencies =
        AppCurrency.values.where(currenciesInUse.contains).toList();
    _selectedCurrency = _availableCurrencies.isNotEmpty
        ? _availableCurrencies.first
        : AppCurrency.rub;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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

  List<MapEntry<DateTime, double>> get _monthlyTotals {
    final now = DateTime.now();
    final months =
        List.generate(6, (i) => DateTime(now.year, now.month - (5 - i)));
    final totals = {for (final m in months) m: 0.0};
    for (final expense in widget.expenses
        .where((e) => !e.isIncome && e.currency == _selectedCurrency)) {
      final key = DateTime(expense.date.year, expense.date.month);
      if (totals.containsKey(key)) {
        totals[key] = totals[key]! + expense.amount;
      }
    }
    return months.map((m) => MapEntry(m, totals[m]!)).toList();
  }

  String _monthLabel(DateTime month) => DateFormat('LLL', 'ru').format(month);

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
            hintText: 'Сумма в месяц, ${_selectedCurrency.symbol}',
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
    await _budgetRepository.setBudget(
      widget.householdCode,
      category,
      _selectedCurrency,
      amount,
    );
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
      body: Column(
        children: [
          if (_availableCurrencies.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: _CurrencySelector(
                currencies: _availableCurrencies,
                selected: _selectedCurrency,
                onChanged: (currency) =>
                    setState(() => _selectedCurrency = currency),
              ),
            ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _CategoriesTab(
                  entries: (_categoryTotals.entries.toList()
                    ..sort((a, b) => b.value.compareTo(a.value))),
                  currency: _selectedCurrency,
                  householdCode: widget.householdCode,
                  budgetRepository: _budgetRepository,
                  onEditBudget: _editBudget,
                ),
                _HistoryTab(
                  monthlyTotals: _monthlyTotals,
                  currency: _selectedCurrency,
                  monthLabel: _monthLabel,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoriesTab extends StatelessWidget {
  final List<MapEntry<ExpenseCategory, double>> entries;
  final AppCurrency currency;
  final String householdCode;
  final BudgetRepository budgetRepository;
  final void Function(ExpenseCategory category, double? current) onEditBudget;

  const _CategoriesTab({
    required this.entries,
    required this.currency,
    required this.householdCode,
    required this.budgetRepository,
    required this.onEditBudget,
  });

  @override
  Widget build(BuildContext context) {
    final total = entries.fold(0.0, (sum, e) => sum + e.value);

    return StreamBuilder<Map<String, double>>(
      stream: budgetRepository.watchBudgets(householdCode),
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
                fontWeight: FontWeight.w500,
                color: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.color
                    ?.withValues(alpha: 0.6),
              ),
            ),
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
                        currency.format.format(total),
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            for (final entry in entries)
              _CategoryRow(
                category: entry.key,
                amount: entry.value,
                currency: currency,
                budget:
                    budgetRepository.budgetFor(budgets, entry.key, currency),
                onTap: () => onEditBudget(
                  entry.key,
                  budgetRepository.budgetFor(budgets, entry.key, currency),
                ),
              ),
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
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: category.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(category.icon, color: category.color, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    category.label,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  budgetValue != null
                      ? '${currency.format.format(amount)} / ${currency.format.format(budgetValue)}'
                      : currency.format.format(amount),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isOverBudget ? Colors.red.shade600 : null,
                  ),
                ),
              ],
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
                    color: isOverBudget ? Colors.red.shade400 : category.color,
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

class _HistoryTab extends StatelessWidget {
  final List<MapEntry<DateTime, double>> monthlyTotals;
  final AppCurrency currency;
  final String Function(DateTime month) monthLabel;

  const _HistoryTab({
    required this.monthlyTotals,
    required this.currency,
    required this.monthLabel,
  });

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
              fontWeight: FontWeight.w500,
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
                          color: kAccentColor,
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
