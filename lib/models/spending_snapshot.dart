import '../models/currency.dart';
import '../models/expense.dart';
import '../models/expense_category.dart';

/// One category's contribution to a month: how much, and in how many
/// records. The count is what lets a tip say "seven coffees" rather than
/// just a sum -- and what keeps a single large purchase from reading as a
/// habit.
class CategoryFigures {
  final double amount;
  final int count;

  const CategoryFigures({required this.amount, required this.count});

  Map<String, dynamic> toJson() => {'amount': amount, 'count': count};
}

/// One calendar month's totals, split by category. Expenses only -- income
/// is tracked as a single figure, since the advice this feeds is about
/// where money goes, not where it comes from.
class MonthFigures {
  final double income;
  final double expense;
  final Map<ExpenseCategory, CategoryFigures> categories;

  const MonthFigures({
    required this.income,
    required this.expense,
    required this.categories,
  });

  Map<String, dynamic> toJson() => {
        'income': income,
        'expense': expense,
        'categories': {
          for (final entry in categories.entries)
            entry.key.storageKey: entry.value.toJson(),
        },
      };
}

/// What gets sent for a spending analysis: this month against last month,
/// by category, plus whatever limits are set. Deliberately just numbers --
/// no note text, no merchant names, nothing an individual purchase could
/// be picked out of. A category total is everything a useful tip like
/// "too much on taxis" actually needs.
class SpendingSnapshot {
  final AppCurrency currency;
  final int daysElapsedInMonth;
  final int daysInMonth;
  final MonthFigures thisMonth;
  final MonthFigures lastMonth;
  final Map<ExpenseCategory, double> limits;

  const SpendingSnapshot({
    required this.currency,
    required this.daysElapsedInMonth,
    required this.daysInMonth,
    required this.thisMonth,
    required this.lastMonth,
    required this.limits,
  });

  /// How many individual records the analysis actually has to go on,
  /// across both months. Below a handful, a "verdict" is just noise
  /// dressed up as insight -- the screen refuses to ask for one rather
  /// than spend a call on it.
  int get recordCount {
    var total = 0;
    for (final figures in thisMonth.categories.values) {
      total += figures.count;
    }
    for (final figures in lastMonth.categories.values) {
      total += figures.count;
    }
    return total;
  }

  Map<String, dynamic> toRequestJson() => {
        'currency': currency.storageKey,
        'daysElapsedInMonth': daysElapsedInMonth,
        'daysInMonth': daysInMonth,
        'thisMonth': thisMonth.toJson(),
        'lastMonth': lastMonth.toJson(),
        'limits': {
          for (final entry in limits.entries) entry.key.storageKey: entry.value,
        },
      };

  /// A stable string identifying exactly this snapshot's numbers. Two
  /// snapshots built from the same spending come out identical, which is
  /// what lets the advice screen skip a fresh call when nothing has
  /// changed since the last one -- see AdviceCache.
  String get fingerprint {
    final buffer = StringBuffer()
      ..write(currency.storageKey)
      ..write('|')
      ..write(daysElapsedInMonth)
      ..write('/')
      ..write(daysInMonth);
    void writeMonth(MonthFigures month) {
      buffer
        ..write('|')
        ..write(month.income.toStringAsFixed(2))
        ..write(',')
        ..write(month.expense.toStringAsFixed(2));
      for (final category in ExpenseCategory.values) {
        final figures = month.categories[category];
        if (figures == null) continue;
        buffer
          ..write(';')
          ..write(category.storageKey)
          ..write(':')
          ..write(figures.amount.toStringAsFixed(2))
          ..write('x')
          ..write(figures.count);
      }
    }

    writeMonth(thisMonth);
    writeMonth(lastMonth);
    buffer.write('|limits');
    for (final category in ExpenseCategory.values) {
      final limit = limits[category];
      if (limit == null) continue;
      buffer
        ..write(';')
        ..write(category.storageKey)
        ..write(':')
        ..write(limit.toStringAsFixed(2));
    }
    return buffer.toString();
  }
}

/// Builds the snapshot from the household's own records, in the budget's
/// own currency -- converting a mixed-currency household into one before
/// sending it off would only make the figures a tip cites wrong.
///
/// [now] is injectable so "this month" and "last month" can be tested
/// without waiting for a particular date to come round.
SpendingSnapshot buildSpendingSnapshot(
  List<Expense> expenses, {
  required AppCurrency currency,
  required Map<ExpenseCategory, double> limits,
  DateTime? now,
}) {
  final today = now ?? DateTime.now();
  final thisMonthKey = DateTime(today.year, today.month);
  final lastMonthKey = DateTime(today.year, today.month - 1);

  final builder = _MonthBuilder();
  final lastBuilder = _MonthBuilder();

  for (final expense in expenses) {
    final key = DateTime(expense.date.year, expense.date.month);
    final target = key == thisMonthKey
        ? builder
        : key == lastMonthKey
            ? lastBuilder
            : null;
    target?.add(expense);
  }

  final daysInMonth = DateTime(today.year, today.month + 1, 0).day;

  return SpendingSnapshot(
    currency: currency,
    daysElapsedInMonth: today.day,
    daysInMonth: daysInMonth,
    thisMonth: builder.build(),
    lastMonth: lastBuilder.build(),
    limits: limits,
  );
}

/// Accumulates one month's worth of expenses into totals and per-category
/// figures in a single pass.
class _MonthBuilder {
  double income = 0;
  double expense = 0;
  final Map<ExpenseCategory, double> _amounts = {};
  final Map<ExpenseCategory, int> _counts = {};

  void add(Expense e) {
    if (e.isIncome) {
      income += e.amount;
      return;
    }
    expense += e.amount;
    final category = e.category ?? ExpenseCategory.other;
    _amounts[category] = (_amounts[category] ?? 0) + e.amount;
    _counts[category] = (_counts[category] ?? 0) + 1;
  }

  MonthFigures build() => MonthFigures(
        income: income,
        expense: expense,
        categories: {
          for (final category in _amounts.keys)
            category: CategoryFigures(
              amount: _amounts[category]!,
              count: _counts[category]!,
            ),
        },
      );
}
