import 'package:flutter/material.dart';

import '../data/expense_repository.dart';
import '../models/currency.dart';
import '../models/expense.dart';
import '../widgets/add_expense_sheet.dart';
import '../widgets/expense_tile.dart';
import '../widgets/summary_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _repository = ExpenseRepository();

  List<Expense> _expenses = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    final expenses = await _repository.loadExpenses();
    expenses.sort((a, b) => b.date.compareTo(a.date));
    setState(() {
      _expenses = expenses;
      _loading = false;
    });
  }

  Future<void> _addExpense(Expense expense) async {
    setState(() {
      _expenses = [expense, ..._expenses]..sort((a, b) => b.date.compareTo(a.date));
    });
    await _repository.saveExpenses(_expenses);
  }

  Future<void> _deleteExpense(Expense expense) async {
    final removedIndex = _expenses.indexOf(expense);
    setState(() {
      _expenses = List.of(_expenses)..remove(expense);
    });
    await _repository.saveExpenses(_expenses);

    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Расход удалён'),
        action: SnackBarAction(
          label: 'Отменить',
          onPressed: () async {
            setState(() {
              final restored = List.of(_expenses);
              final insertAt = removedIndex.clamp(0, restored.length);
              restored.insert(insertAt, expense);
              _expenses = restored;
            });
            await _repository.saveExpenses(_expenses);
          },
        ),
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

  Map<AppCurrency, double> _totalsBy(bool Function(Expense) predicate) {
    final totals = <AppCurrency, double>{};
    for (final expense in _expenses.where(predicate)) {
      totals[expense.currency] = (totals[expense.currency] ?? 0) + expense.amount;
    }
    return totals;
  }

  Map<AppCurrency, double> get _todayTotals {
    final now = DateTime.now();
    return _totalsBy((e) =>
        e.date.year == now.year &&
        e.date.month == now.month &&
        e.date.day == now.day);
  }

  Map<AppCurrency, double> get _monthTotals {
    final now = DateTime.now();
    return _totalsBy((e) => e.date.year == now.year && e.date.month == now.month);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Расходы')),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddExpenseSheet,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadExpenses,
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    sliver: SliverToBoxAdapter(
                      child: SummaryCard(
                        todayTotals: _todayTotals,
                        monthTotals: _monthTotals,
                      ),
                    ),
                  ),
                  if (_expenses.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyState(),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                      sliver: SliverList.separated(
                        itemCount: _expenses.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final expense = _expenses[index];
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
              ),
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
