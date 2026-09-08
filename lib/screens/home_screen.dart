import 'package:flutter/material.dart';

import '../data/expense_repository.dart';
import '../models/currency.dart';
import '../models/expense.dart';
import '../models/household.dart';
import '../models/transaction_type.dart';
import '../widgets/add_expense_sheet.dart';
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

  Future<void> _addExpense(Expense expense) {
    return _repository.addExpense(widget.household.code, expense);
  }

  Future<void> _deleteExpense(Expense expense) async {
    await _repository.deleteExpense(widget.household.code, expense.id);

    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(expense.isIncome ? 'Доход удалён' : 'Расход удалён'),
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

  void _openStats(List<Expense> expenses) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => StatsScreen(
          householdCode: widget.household.code,
          expenses: expenses,
        ),
      ),
    );
  }

  void _openAddSheet(TransactionType type, {Expense? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => AddExpenseSheet(
        type: type,
        existing: existing,
        onSubmit: _addExpense,
      ),
    );
  }

  Map<AppCurrency, double> _totalsBy(
    List<Expense> expenses,
    bool Function(Expense) predicate,
  ) {
    final totals = <AppCurrency, double>{};
    for (final expense in expenses.where(predicate)) {
      totals[expense.currency] =
          (totals[expense.currency] ?? 0) + expense.amount;
    }
    return totals;
  }

  Map<AppCurrency, double> _totalsFor(
    List<Expense> expenses, {
    required bool sameDay,
    required bool isIncome,
  }) {
    final now = DateTime.now();
    return _totalsBy(
      expenses,
      (e) =>
          e.isIncome == isIncome &&
          e.date.year == now.year &&
          e.date.month == now.month &&
          (!sameDay || e.date.day == now.day),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Expense>>(
      stream: _repository.watchExpenses(widget.household.code),
      builder: (context, snapshot) {
        final expenses = snapshot.data ?? const <Expense>[];
        return Scaffold(
          appBar: AppBar(
            title: Text(widget.household.label),
            actions: [
              IconButton(
                onPressed: () => _openStats(expenses),
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
                onPressed: () => _openAddSheet(TransactionType.income),
                tooltip: 'Добавить доход',
                child: const Icon(Icons.add),
              ),
              const SizedBox(width: 14),
              FloatingActionButton(
                heroTag: 'add_expense',
                onPressed: () => _openAddSheet(TransactionType.expense),
                tooltip: 'Добавить расход',
                child: const Icon(Icons.remove),
              ),
            ],
          ),
          body: !snapshot.hasData
              ? const Center(child: CircularProgressIndicator())
              : CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      sliver: SliverToBoxAdapter(
                        child: SummaryCard(
                          todayExpenseTotals: _totalsFor(
                            expenses,
                            sameDay: true,
                            isIncome: false,
                          ),
                          todayIncomeTotals: _totalsFor(
                            expenses,
                            sameDay: true,
                            isIncome: true,
                          ),
                          monthExpenseTotals: _totalsFor(
                            expenses,
                            sameDay: false,
                            isIncome: false,
                          ),
                          monthIncomeTotals: _totalsFor(
                            expenses,
                            sameDay: false,
                            isIncome: true,
                          ),
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
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
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
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 20),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade400,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Icon(Icons.delete_outline_rounded,
                                    color: Colors.white),
                              ),
                              onDismissed: (_) => _deleteExpense(expense),
                              child: ExpenseTile(
                                expense: expense,
                                onTap: () => _openAddSheet(
                                  expense.type,
                                  existing: expense,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
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
                fontWeight: FontWeight.w600,
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
