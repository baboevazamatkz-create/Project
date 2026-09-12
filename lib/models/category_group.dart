import 'package:flutter/material.dart';

import 'expense.dart';
import 'expense_category.dart';
import '../theme.dart';

/// One category's (or income's) transactions for a single month, with
/// their combined total -- what the home screen's "group by category"
/// view renders instead of the plain chronological list.
class CategoryGroup {
  final String label;
  final IconData icon;
  final Color color;
  final double total;
  final List<Expense> items;

  const CategoryGroup({
    required this.label,
    required this.icon,
    required this.color,
    required this.total,
    required this.items,
  });
}

double _sumOf(List<Expense> items) =>
    items.fold(0.0, (sum, expense) => sum + expense.amount);

/// Groups the [expenses] that fall within [month] by category, keeping
/// income as its own group rather than trying to fit it under a category
/// (income entries carry no category). A plain top-level function, not a
/// method on some state class, so it can be unit-tested directly without
/// pumping a widget -- [month] is a parameter rather than read from
/// DateTime.now() internally for the same reason: a fixed date makes the
/// test deterministic.
///
/// Categories are ordered by total spent, highest first, matching the
/// stats screen's own category breakdown. Income (if any this month)
/// leads: it is usually the shorter list and the figure people check
/// first.
List<CategoryGroup> buildCategoryGroups(
  List<Expense> expenses, {
  required DateTime month,
}) {
  final scoped = expenses.where(
    (expense) =>
        expense.date.year == month.year && expense.date.month == month.month,
  );

  final incomeItems = <Expense>[];
  final byCategory = <ExpenseCategory, List<Expense>>{};
  for (final expense in scoped) {
    if (expense.isIncome) {
      incomeItems.add(expense);
    } else {
      (byCategory[expense.category!] ??= []).add(expense);
    }
  }

  final groups = <CategoryGroup>[];
  if (incomeItems.isNotEmpty) {
    groups.add(CategoryGroup(
      label: 'Доход',
      icon: Icons.arrow_downward_rounded,
      color: kIncomeColor,
      total: _sumOf(incomeItems),
      items: incomeItems,
    ));
  }

  final sortedCategories = byCategory.entries.toList()
    ..sort((a, b) => _sumOf(b.value).compareTo(_sumOf(a.value)));
  for (final entry in sortedCategories) {
    groups.add(CategoryGroup(
      label: entry.key.label,
      icon: entry.key.icon,
      color: entry.key.color,
      total: _sumOf(entry.value),
      items: entry.value,
    ));
  }
  return groups;
}
