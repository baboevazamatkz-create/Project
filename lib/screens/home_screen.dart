import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/expense_repository.dart';
import '../models/currency.dart';
import '../models/expense.dart';
import '../theme.dart';
import '../widgets/add_expense_sheet.dart';
import '../widgets/expense_tile.dart';
import '../widgets/summary_card.dart';

class HomeScreen extends StatefulWidget {
  final String householdCode;

  const HomeScreen({super.key, required this.householdCode});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _repository = ExpenseRepository();

  Future<void> _addExpense(Expense expense) {
    return _repository.addExpense(widget.householdCode, expense);
  }

  Future<void> _deleteExpense(Expense expense) async {
    await _repository.deleteExpense(widget.householdCode, expense.id);

    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Расход удалён'),
        action: SnackBarAction(
          label: 'Отменить',
          onPressed: () => _repository.addExpense(widget.householdCode, expense),
        ),
      ),
    );
  }

  void _showHouseholdCode() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Код бюджета'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Поделитесь этим кодом, чтобы вести бюджет вместе:'),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: kAccentColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                widget.householdCode,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 4,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: widget.householdCode));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Код скопирован')),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Скопировать'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  void _openAddExpenseSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => AddExpenseSheet(onSubmit: _addExpense),
    );
  }

  Map<AppCurrency, double> _totalsBy(
    List<Expense> expenses,
    bool Function(Expense) predicate,
  ) {
    final totals = <AppCurrency, double>{};
    for (final expense in expenses.where(predicate)) {
      totals[expense.currency] = (totals[expense.currency] ?? 0) + expense.amount;
    }
    return totals;
  }

  Map<AppCurrency, double> _todayTotals(List<Expense> expenses) {
    final now = DateTime.now();
    return _totalsBy(
      expenses,
      (e) =>
          e.date.year == now.year &&
          e.date.month == now.month &&
          e.date.day == now.day,
    );
  }

  Map<AppCurrency, double> _monthTotals(List<Expense> expenses) {
    final now = DateTime.now();
    return _totalsBy(
      expenses,
      (e) => e.date.year == now.year && e.date.month == now.month,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Расходы'),
        actions: [
          IconButton(
            onPressed: _showHouseholdCode,
            icon: const Icon(Icons.people_alt_outlined),
            tooltip: 'Код бюджета',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddExpenseSheet,
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<Expense>>(
        stream: _repository.watchExpenses(widget.householdCode),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final expenses = snapshot.data!;
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: SummaryCard(
                    todayTotals: _todayTotals(expenses),
                    monthTotals: _monthTotals(expenses),
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
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final expense = expenses[index];
                      return Dismissible(
                        key: ValueKey(expense.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
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
                        ),
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
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
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
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
