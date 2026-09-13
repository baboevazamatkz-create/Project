import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';

import '../data/budget_repository.dart';
import '../models/currency.dart';
import '../models/expense.dart';
import '../models/expense_category.dart';
import '../theme.dart';
import '../widgets/readable_width.dart';
import '../widgets/app_background_pattern.dart';
import '../widgets/tour_step.dart';

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
  // Shown once, the first time someone opens this screen with something
  // on it. A tappable category row is the only way to set a limit and
  // nothing about the row says so.
  static const _tourSeenKey = 'stats_tour_seen_v1';

  // Its own scope, not the default one. Registering without a scope
  // overwrites whatever is registered there -- the home screen's
  // showcase, still mounted behind this route -- and unregistering on the
  // way out would then leave that screen with none at all.
  static const _tourScope = 'stats';

  final _budgetRepository = BudgetRepository();
  final _limitKey = GlobalKey();
  late final ShowcaseView _showcase;
  bool _tourStarted = false;

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
    _showcase = ShowcaseView.register(
      scope: _tourScope,
      onFinish: _markTourSeen,
      onDismiss: (_) => _markTourSeen(),
      skipIfTargetNotPresent: true,
      blurValue: 2,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _showcase.unregister();
    super.dispose();
  }

  // Called from build, so the common path -- already started -- stays
  // synchronous rather than allocating a Future on every frame.
  void _maybeStartTour() {
    if (_tourStarted || _categoryEntries.isEmpty) return;
    _tourStarted = true;
    _startTour();
  }

  Future<void> _startTour() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_tourSeenKey) ?? false) return;
    // Two rendered frames before the target's position is captured, for
    // the same reason as the home screen: the first frames still report
    // provisional insets, and endOfFrame schedules the frame it waits on.
    for (var i = 0; i < 2; i++) {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
    }
    _showcase.startShowCase(
      [_limitKey],
      delay: const Duration(milliseconds: 250),
    );
  }

  Future<void> _markTourSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_tourSeenKey, true);
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
    _maybeStartTour();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Статистика'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: goldFor(context),
          unselectedLabelColor:
              accentForeground(context).withValues(alpha: 0.45),
          labelStyle: const TextStyle(
            fontFamily: 'Onest',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
          unselectedLabelStyle: const TextStyle(
            fontFamily: 'Onest',
            fontSize: 12,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.8,
          ),
          indicatorColor: goldFor(context),
          indicatorWeight: 1.6,
          indicatorSize: TabBarIndicatorSize.label,
          dividerColor: hairlineColor(context),
          tabs: const [
            Tab(text: 'КАТЕГОРИИ'),
            Tab(text: 'ИСТОРИЯ'),
          ],
        ),
      ),
      body: AppBackgroundPattern(
        child: ReadableWidth(
          child: TabBarView(
            controller: _tabController,
            children: [
              CategoriesTab(
                entries: _categoryEntries,
                currency: widget.currency,
                budgetsStream: _budgetsStream,
                onEditBudget: _editBudget,
                limitTourKey: _limitKey,
              ),
              HistoryTab(
                monthlyTotals: _monthlyTotals,
                currency: widget.currency,
                monthLabel: _monthLabel,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CategoriesTab extends StatelessWidget {
  final List<MapEntry<ExpenseCategory, double>> entries;
  final AppCurrency currency;
  final Stream<Map<String, double>> budgetsStream;
  final void Function(ExpenseCategory category, double? current) onEditBudget;

  /// Attached to the first category row, which the tour points at. Null
  /// where the tab is built outside a registered showcase -- in a test,
  /// say -- so the rows are plain.
  final GlobalKey? limitTourKey;

  const CategoriesTab({
    super.key,
    required this.entries,
    required this.currency,
    required this.budgetsStream,
    required this.onEditBudget,
    this.limitTourKey,
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
            Center(
              child: Text(
                'ЗА ТЕКУЩИЙ МЕСЯЦ',
                style: microLabel(
                  context,
                  color: goldFor(context).withValues(alpha: 0.85),
                ),
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
                                color: Color(0xFFF6F2EA),
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
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
                              'ВСЕГО',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: microLabel(context, size: 9.5),
                            ),
                            const SizedBox(height: 4),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                currency.format.format(total),
                                maxLines: 1,
                                style: moneyStyle(
                                  size: 18,
                                  weight: FontWeight.w300,
                                  color: accentForeground(context),
                                  letterSpacing: -0.4,
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
            for (final entry in entries.asMap().entries)
              () {
                final category = entry.value.key;
                final budget = BudgetRepository.budgetFor(budgets, category);
                final row = _CategoryRow(
                  category: category,
                  amount: entry.value.value,
                  currency: currency,
                  budget: budget,
                  onTap: () => onEditBudget(category, budget),
                );
                final tourKey = limitTourKey;
                if (entry.key != 0 || tourKey == null) return row;
                return tourStep(
                  context,
                  tourKey: tourKey,
                  title: 'Лимиты по категориям',
                  description: 'Нажмите на категорию, чтобы задать лимит на '
                      'месяц. Под строкой появится, сколько от него осталось, '
                      'а перерасход подсветится',
                  isLast: true,
                  targetShapeBorder: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: row,
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
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: category.color.withValues(alpha: 0.13),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: category.color.withValues(alpha: 0.22),
                        ),
                      ),
                      child:
                          Icon(category.icon, color: category.color, size: 17),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        category.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            letterSpacing: -0.1),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: amountMaxWidth),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: currency.format.format(amount),
                                // Only the figure that broke the limit is
                                // loud; the limit itself stays quiet, so the
                                // row says what is wrong rather than just
                                // turning red.
                                style: moneyStyle(
                                  size: isOverBudget ? 15 : 14,
                                  weight: isOverBudget
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isOverBudget
                                      ? overBudgetColor(context)
                                      : accentForeground(context)
                                          .withValues(alpha: 0.85),
                                ),
                              ),
                              if (budgetValue != null)
                                TextSpan(
                                  text:
                                      ' / ${currency.format.format(budgetValue)}',
                                  style: moneyStyle(
                                    size: 14,
                                    weight: FontWeight.w500,
                                    color: accentForeground(context)
                                        .withValues(alpha: 0.55),
                                  ),
                                ),
                            ],
                          ),
                          maxLines: 1,
                          softWrap: false,
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
                    minHeight: 4,
                    backgroundColor: category.color.withValues(alpha: 0.12),
                    color:
                        isOverBudget ? expenseColor(context) : category.color,
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

  /// Champagne for a quiet month, terracotta for the worst one. Both ends
  /// are picked per theme: the deep terracotta that reads on paper turns
  /// into near-black-on-near-black in the dark, which is what made the
  /// tallest bar disappear.
  Color _colorForValue(BuildContext context, double value, double maxValue) {
    final low = goldFor(context);
    final high = expenseColor(context);
    if (maxValue <= 0) return low;
    final t = (value / maxValue).clamp(0.0, 1.0);
    return Color.lerp(low, high, t)!;
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
            'РАСХОДЫ ЗА ПОСЛЕДНИЕ 6 МЕСЯЦЕВ',
            style: microLabel(
              context,
              color: goldFor(context).withValues(alpha: 0.85),
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
                // The default tooltip is a grey slab that takes its text
                // colour from the bar, which on a dark bar is unreadable.
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) =>
                        Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF2A2831)
                            : kAccentColor,
                    tooltipRoundedRadius: 10,
                    tooltipPadding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                        BarTooltipItem(
                      currency.format.format(rod.toY),
                      const TextStyle(
                        fontFamily: 'Onest',
                        color: Color(0xFFF4F1EA),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
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
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: accentForeground(context)
                                  .withValues(alpha: 0.65),
                            ),
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
                          color: _colorForValue(
                              context, monthlyTotals[i].value, maxValue),
                          width: 22,
                          borderRadius: BorderRadius.circular(6),
                          // A faint track behind each bar, so a small month
                          // still reads as a bar rather than as nothing.
                          backDrawRodData: BackgroundBarChartRodData(
                            show: true,
                            toY: maxValue * 1.2,
                            color: accentForeground(context)
                                .withValues(alpha: 0.05),
                          ),
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
