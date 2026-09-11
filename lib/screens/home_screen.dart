import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';

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
import '../theme.dart';
import '../widgets/summary_card.dart';
import 'stats_screen.dart';

Showcase _tourStep({
  required GlobalKey tourKey,
  required String title,
  required String description,
  required Widget child,
  ShapeBorder targetShapeBorder = const CircleBorder(),
  List<TooltipActionButton>? tooltipActions,
  TooltipActionConfig? tooltipActionConfig,
}) {
  return Showcase(
    key: tourKey,
    title: title,
    titleTextStyle: const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: kBrandColor,
    ),
    description: description,
    descTextStyle: TextStyle(
      fontSize: 13,
      color: Colors.black.withValues(alpha: 0.65),
    ),
    tooltipBackgroundColor: Colors.white,
    tooltipBorderRadius: BorderRadius.circular(16),
    tooltipPadding: const EdgeInsets.all(16),
    targetShapeBorder: targetShapeBorder,
    targetPadding: const EdgeInsets.all(4),
    tooltipActions: tooltipActions,
    tooltipActionConfig: tooltipActionConfig,
    child: child,
  );
}

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
  static const _tourSeenKey = 'onboarding_tour_seen';

  final _repository = ExpenseRepository();
  final _settingsRepository = HouseholdSettingsRepository();

  final _incomeFabKey = GlobalKey();
  final _expenseFabKey = GlobalKey();
  final _summaryCardKey = GlobalKey();
  final _statsKey = GlobalKey();
  final _switcherKey = GlobalKey();
  bool _tourStarted = false;

  // null means "show amounts in the household's own currency" (exact,
  // no conversion). Set when the user taps the currency toggle; reset
  // whenever the household changes, so switching budgets never leaves a
  // stale conversion showing.
  AppCurrency? _displayCurrency;

  // Held in fields rather than created inside build(): a stream built during
  // build is a brand-new Firestore listener on every rebuild, which drops the
  // loaded data back to a spinner and re-reads the collection each time.
  late Stream<AppCurrency> _currencyStream;
  late Stream<List<Expense>> _expensesStream;

  @override
  void initState() {
    super.initState();
    _subscribeToHousehold();
    ShowcaseView.register(
      onFinish: _markTourSeen,
      onDismiss: (_) => _markTourSeen(),
      skipIfTargetNotPresent: true,
      blurValue: 2,
      overlayOpacity: 0.65,
      globalTooltipActionConfig: const TooltipActionConfig(
        position: TooltipActionPosition.inside,
        alignment: MainAxisAlignment.spaceBetween,
        gapBetweenContentAndAction: 14,
      ),
      globalTooltipActions: [
        TooltipActionButton(
          type: TooltipDefaultActionType.skip,
          name: 'Пропустить',
          backgroundColor: Colors.transparent,
          textStyle: TextStyle(
            color: Colors.black.withValues(alpha: 0.45),
            fontSize: 13,
          ),
          hideActionWidgetForShowcase: [_switcherKey],
        ),
        TooltipActionButton(
          type: TooltipDefaultActionType.next,
          name: 'Далее',
          backgroundColor: kBrandColor,
          textStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          hideActionWidgetForShowcase: [_switcherKey],
        ),
      ],
    );
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.household.code != widget.household.code) {
      _subscribeToHousehold();
    }
  }

  @override
  void dispose() {
    ShowcaseView.get().unregister();
    super.dispose();
  }

  void _subscribeToHousehold() {
    final code = widget.household.code;
    _currencyStream = _settingsRepository.watchCurrency(code);
    _expensesStream = _repository.watchExpenses(code);
    _displayCurrency = null;
  }

  /// Steps the currency-view toggle to the next currency: household's own
  /// (exact) -> the other two (converted) -> back to household's own.
  void _cycleDisplayCurrency(AppCurrency householdCurrency) {
    final order = [
      householdCurrency,
      ...AppCurrency.values.where((c) => c != householdCurrency),
    ];
    final current = _displayCurrency ?? householdCurrency;
    final next = order[(order.indexOf(current) + 1) % order.length];
    setState(() {
      _displayCurrency = next == householdCurrency ? null : next;
    });
  }

  /// Starts the onboarding tour once real content is on screen.
  ///
  /// Waiting for [hasContent] (rather than firing on the very first frame)
  /// matters because the summary card only exists in the tree once the
  /// expenses stream has delivered its first snapshot — on a slow
  /// connection that can take a while, and this package finishes the whole
  /// tour early if a step's target isn't rendered when its turn comes up.
  Future<void> _maybeStartTour({required bool hasContent}) async {
    if (_tourStarted || !hasContent) return;
    _tourStarted = true;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_tourSeenKey) ?? false) return;
    if (!mounted) return;
    // Wait for two frames that have actually been rendered before capturing
    // the first target's position: on some devices the very first frames
    // still report provisional MediaQuery insets (status bar / gesture bar),
    // so a button's position at that instant differs from where it settles —
    // which is what put the highlight above the real button on one phone.
    //
    // This waits on endOfFrame rather than addPostFrameCallback because a
    // post-frame callback does not ask for a frame; once the app goes idle
    // after first paint nothing schedules one, so the tour sat waiting until
    // a tap happened to produce a frame. endOfFrame schedules one itself.
    for (var i = 0; i < 2; i++) {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
    }
    ShowcaseView.get().startShowCase(
      [_expenseFabKey, _incomeFabKey, _summaryCardKey, _statsKey, _switcherKey],
      delay: const Duration(milliseconds: 250),
    );
  }

  Future<void> _markTourSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_tourSeenKey, true);
  }

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

  void _showHouseholdSwitcher(AppCurrency currency) {
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
        currency: currency,
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
            style: ElevatedButton.styleFrom(backgroundColor: kExpenseColor),
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

  /// Sums today's and this month's income and expenses in a single pass,
  /// instead of walking the whole list once per figure on every rebuild.
  _Totals _totals(List<Expense> expenses) {
    final now = DateTime.now();
    var totals = const _Totals();
    for (final expense in expenses) {
      final date = expense.date;
      if (date.year != now.year || date.month != now.month) continue;
      final isToday = date.day == now.day;
      totals = totals.add(
        amount: expense.amount,
        isIncome: expense.isIncome,
        isToday: isToday,
      );
    }
    return totals;
  }

  /// Same plain glyph treatment as the other AppBar icons -- it is the
  /// budget's own currency symbol, not a filled pill, so it reads as one
  /// of the toolbar's icons rather than a separate loud control. A small
  /// dot is the only accent, and only appears once the toggle has actually
  /// been switched away from the household's own currency.
  Widget _currencyToggleButton(AppCurrency householdCurrency) {
    final display = _displayCurrency ?? householdCurrency;
    final isConverted = display != householdCurrency;
    return Tooltip(
      message: isConverted
          ? 'Показано по среднему курсу, не биржевому.\n'
              'Валюта бюджета: ${householdCurrency.label}'
          : 'Показать в другой валюте (по среднему курсу)',
      child: InkResponse(
        onTap: () => _cycleDisplayCurrency(householdCurrency),
        radius: 24,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Text(
                display.symbol,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: accentForeground(context),
                ),
              ),
              if (isConverted)
                Positioned(
                  bottom: 9,
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      color: kBrandColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppCurrency>(
      stream: _currencyStream,
      builder: (context, currencySnapshot) {
        final currency = currencySnapshot.data ?? AppCurrency.rub;
        return StreamBuilder<List<Expense>>(
          stream: _expensesStream,
          builder: (context, snapshot) {
            final expenses = snapshot.data ?? const <Expense>[];
            final totals = _totals(expenses);
            final displayCurrency = _displayCurrency ?? currency;
            final isConverted = displayCurrency != currency;
            final displayTotals = isConverted
                ? _Totals(
                    todayIncome: convertApprox(totals.todayIncome,
                        from: currency, to: displayCurrency),
                    todayExpense: convertApprox(totals.todayExpense,
                        from: currency, to: displayCurrency),
                    monthIncome: convertApprox(totals.monthIncome,
                        from: currency, to: displayCurrency),
                    monthExpense: convertApprox(totals.monthExpense,
                        from: currency, to: displayCurrency),
                  )
                : totals;
            _maybeStartTour(hasContent: snapshot.hasData);
            return Scaffold(
              appBar: AppBar(
                title: Text(
                  widget.household.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                actions: [
                  _currencyToggleButton(currency),
                  IconButton(
                    onPressed: _confirmClearAll,
                    icon: const Icon(Icons.delete_sweep_outlined),
                    tooltip: 'Очистить бюджет',
                  ),
                  _tourStep(
                    tourKey: _statsKey,
                    title: 'Статистика',
                    description:
                        'Диаграмма расходов по категориям и история за месяц',
                    child: IconButton(
                      onPressed: () => _openStats(expenses, currency),
                      icon: const Icon(Icons.pie_chart_rounded),
                      tooltip: 'По категориям',
                    ),
                  ),
                  _tourStep(
                    tourKey: _switcherKey,
                    title: 'Мои бюджеты',
                    description: 'Переключайтесь между бюджетами или '
                        'создайте новый, чтобы вести расходы с близкими',
                    tooltipActionConfig: const TooltipActionConfig(
                      position: TooltipActionPosition.inside,
                      alignment: MainAxisAlignment.end,
                    ),
                    tooltipActions: [
                      const TooltipActionButton(
                        type: TooltipDefaultActionType.next,
                        name: 'Готово',
                        backgroundColor: kBrandColor,
                        textStyle: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    child: IconButton(
                      onPressed: () => _showHouseholdSwitcher(currency),
                      icon: const Icon(Icons.people_alt_outlined),
                      tooltip: 'Мои бюджеты',
                    ),
                  ),
                ],
              ),
              floatingActionButton: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _tourStep(
                    tourKey: _expenseFabKey,
                    title: 'Добавить расход',
                    description: 'Нажмите, чтобы записать трату. Смахните '
                        'запись влево, чтобы удалить, или зажмите её, '
                        'чтобы изменить',
                    child: FloatingActionButton(
                      heroTag: 'add_expense',
                      backgroundColor: kExpenseColor,
                      onPressed: () =>
                          _openAddSheet(TransactionType.expense, currency),
                      tooltip: 'Добавить расход',
                      child: const Icon(Icons.remove),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _tourStep(
                    tourKey: _incomeFabKey,
                    title: 'Добавить доход',
                    description: 'Нажмите, чтобы записать поступление денег',
                    child: FloatingActionButton(
                      heroTag: 'add_income',
                      backgroundColor: kIncomeColor,
                      onPressed: () =>
                          _openAddSheet(TransactionType.income, currency),
                      tooltip: 'Добавить доход',
                      child: const Icon(Icons.add),
                    ),
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
                              child: _tourStep(
                                tourKey: _summaryCardKey,
                                title: 'Итоги',
                                description: 'Здесь видно, сколько '
                                    'потрачено и заработано сегодня и за '
                                    'месяц',
                                targetShapeBorder: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(24),
                                  ),
                                ),
                                child: SummaryCard(
                                  todayExpenseTotal: displayTotals.todayExpense,
                                  todayIncomeTotal: displayTotals.todayIncome,
                                  monthExpenseTotal: displayTotals.monthExpense,
                                  monthIncomeTotal: displayTotals.monthIncome,
                                  currency: displayCurrency,
                                  isApproximate: isConverted,
                                ),
                              ),
                            ),
                          ),
                          if (expenses.isEmpty)
                            const SliverFillRemaining(
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
                                  final tileAmount = isConverted
                                      ? convertApprox(expense.amount,
                                          from: currency, to: displayCurrency)
                                      : null;
                                  return Dismissible(
                                    key: ValueKey(expense.id),
                                    direction: DismissDirection.endToStart,
                                    background: Container(
                                      alignment: Alignment.centerRight,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 20),
                                      decoration: BoxDecoration(
                                        color: kExpenseColor,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Icon(
                                          Icons.delete_outline_rounded,
                                          color: Colors.white),
                                    ),
                                    onDismissed: (_) => _deleteExpense(expense),
                                    child: ExpenseTile(
                                      expense: expense,
                                      currency: displayCurrency,
                                      amountOverride: tileAmount,
                                      isApproximate: isConverted,
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

class _Totals {
  final double todayIncome;
  final double todayExpense;
  final double monthIncome;
  final double monthExpense;

  const _Totals({
    this.todayIncome = 0,
    this.todayExpense = 0,
    this.monthIncome = 0,
    this.monthExpense = 0,
  });

  _Totals add({
    required double amount,
    required bool isIncome,
    required bool isToday,
  }) {
    return _Totals(
      todayIncome: todayIncome + (isIncome && isToday ? amount : 0),
      todayExpense: todayExpense + (!isIncome && isToday ? amount : 0),
      monthIncome: monthIncome + (isIncome ? amount : 0),
      monthExpense: monthExpense + (!isIncome ? amount : 0),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

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
              color: accentForeground(context).withValues(alpha: 0.4),
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
