import 'package:flutter/material.dart';

import '../data/expense_repository.dart';
import '../data/household_settings_repository.dart';
import '../models/currency.dart';
import '../models/expense.dart';
import '../models/household.dart';
import '../models/transaction_type.dart';
import '../widgets/add_expense_sheet.dart';
import '../widgets/app_background_pattern.dart';
import '../widgets/expense_tile.dart';
import '../widgets/household_switcher_sheet.dart';
import '../widgets/summary_card.dart';
import 'stats_screen.dart';

class HomeScreen extends StatefulWidget {
  final Household household;
  final List<Household> households;
  final ValueChanged<String> onSwitchHousehold;
  final VoidCallback onAddHousehold;

  const HomeScreen({
    super.key,
    required this.household,
    required this.households,
    required this.onSwitchHousehold,
    required this.onAddHousehold,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _repository = ExpenseRepository();
  final _settingsRepository = HouseholdSettingsRepository();

  Future<void> _addExpense(Expense expense) {
    return _repository.addExpense(widget.household.code, expense);
  }

  Future<void> _deleteExpense(Expense expense) async {
    await _repository.deleteExpense(widget.household.code, expense.id);

    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(expense.isIncome ? 'Доход удалён' : 'Расход удалён'),
        duration: const Duration(seconds: 2),
        persist: false,
        action: SnackBarAction(
          label: 'Отменить',
          onPressed: () =>
              _repository.addExpense(widget.household.code, expense),
        ),
      ),
    );
  }

  void _showHouseholdSwitcher() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => HouseholdSwitcherSheet(
        households: widget.households,
        activeCode: widget.household.code,
        onSwitch: widget.onSwitchHousehold,
        onAddHousehold: widget.onAddHousehold,
      ),
    );
  }

  Future<void> _confirmClearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Очистить бюджет?'),
        content: Text(
          'Все расходы и доходы в бюджете «${widget.household.label}» '
          'будут удалены безвозвратно. Это действие нельзя отменить.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Очистить'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _settingsRepository.clearAllExpenses(widget.household.code);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Бюджет очищен')),
    );
  }

  void _openStats(List<Expense> expenses, AppCurrency currency) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => StatsScreen(
          householdCode: widget.household.code,
          currency: currency,
          expenses: expenses,
        ),
      ),
    );
  }

  void _openAddSheet(
    TransactionType type,
    AppCurrency currency, {
    Expense? existing,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => AddExpenseSheet(
        type: type,
        currency: currency,
        existing: existing,
        onSubmit: _addExpense,
      ),
    );
  }

  double _totalFor(
    List<Expense> expenses, {
    required bool sameDay,
    required bool isIncome,
  }) {
    final now = DateTime.now();
    return expenses
        .where((e) =>
            e.isIncome == isIncome &&
            e.date.year == now.year &&
            e.date.month == now.month &&
            (!sameDay || e.date.day == now.day))
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppCurrency>(
      stream: _settingsRepository.watchCurrency(widget.household.code),
      builder: (context, currencySnapshot) {
        final currency = currencySnapshot.data ?? AppCurrency.rub;
        return StreamBuilder<List<Expense>>(
          stream: _repository.watchExpenses(widget.household.code),
          builder: (context, snapshot) {
            final expenses = snapshot.data ?? const <Expense>[];
            return Scaffold(
              appBar: AppBar(
                title: Text(widget.household.label),
                actions: [
                  IconButton(
                    onPressed: _confirmClearAll,
                    icon: const Icon(Icons.delete_sweep_outlined),
                    tooltip: 'Очистить бюджет',
                  ),
                  IconButton(
                    onPressed: () => _openStats(expenses, currency),
                    icon: const Icon(Icons.pie_chart_rounded),
                    tooltip: 'По категориям',
                  ),
                  IconButton(
                    onPressed: _showHouseholdSwitcher,
                    icon: const Icon(Icons.people_alt_outlined),
                    tooltip: 'Мои бюджеты',
                  ),
                ],
              ),
              floatingActionButton: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FloatingActionButton(
                    heroTag: 'add_income',
                    backgroundColor: Colors.green.shade600,
                    onPressed: () =>
                        _openAddSheet(TransactionType.income, currency),
                    tooltip: 'Добавить доход',
                    child: const Icon(Icons.add),
                  ),
                  const SizedBox(width: 14),
                  FloatingActionButton(
                    heroTag: 'add_expense',
                    backgroundColor: Colors.red.shade600,
                    onPressed: () =>
                        _openAddSheet(TransactionType.expense, currency),
                    tooltip: 'Добавить расход',
                    child: const Icon(Icons.remove),
                  ),
                ],
              ),
              body: AppBackgroundPattern(
                child: !snapshot.hasData
                    ? const Center(child: CircularProgressIndicator())
                    : CustomScrollView(
                        slivers: [
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                            sliver: SliverToBoxAdapter(
                              child: SummaryCard(
                                todayExpenseTotal: _totalFor(
                                  expenses,
                                  sameDay: true,
                                  isIncome: false,
                                ),
                                todayIncomeTotal: _totalFor(
                                  expenses,
                                  sameDay: true,
                                  isIncome: true,
                                ),
                                monthExpenseTotal: _totalFor(
                                  expenses,
                                  sameDay: false,
                                  isIncome: false,
                                ),
                                monthIncomeTotal: _totalFor(
                                  expenses,
                                  sameDay: false,
                                  isIncome: true,
                                ),
                                currency: currency,
                              ),
                            ),
                          ),
                          if (expenses.isEmpty)
                            SliverFillRemaining(
                              hasScrollBody: false,
                              child: _EmptyState(),
                            )
                          else
                            SliverPadding(
                              padding:
                                  const EdgeInsets.fromLTRB(24, 8, 24, 100),
                              sliver: SliverList.separated(
                                itemCount: expenses.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final expense = expenses[index];
                                  return Dismissible(
                                    key: ValueKey(expense.id),
                                    direction: DismissDirection.endToStart,
                                    background: Container(
                                      alignment: Alignment.centerRight,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 20),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade400,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Icon(
                                          Icons.delete_outline_rounded,
                                          color: Colors.white),
                                    ),
                                    onDismissed: (_) => _deleteExpense(expense),
                                    child: ExpenseTile(
                                      expense: expense,
                                      currency: currency,
                                      onLongPress: () => _openAddSheet(
                                        expense.type,
                                        currency,
                                        existing: expense,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
              ),
            );
          },
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 56,
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'Пока нет расходов',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.normal,
                color: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.color
                    ?.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
