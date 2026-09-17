import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';

import '../data/expense_repository.dart';
import '../data/widget_bridge.dart';
import '../data/widget_launch.dart';
import '../data/household_settings_repository.dart';
import '../data/advice_service.dart';
import '../data/scan_service.dart';
import '../models/category_group.dart';
import '../models/currency.dart';
import '../models/expense.dart';
import '../models/expense_category.dart';
import '../models/household.dart';
import '../models/transaction_type.dart';
import '../widgets/add_expense_sheet.dart';
import '../widgets/advice_tab_button.dart';
import '../widgets/ai_scan_icon.dart';
import '../widgets/app_background_pattern.dart';
import '../widgets/expense_tile.dart';
import '../widgets/glass.dart';
import '../widgets/readable_width.dart';
import '../widgets/household_switcher_sheet.dart';
import '../theme.dart';
import '../theme_mode_controller.dart';
import '../widgets/summary_card.dart';
import '../widgets/tour_step.dart';
import 'advice_screen.dart';
import 'scan_flow.dart';
import 'stats_screen.dart';

final _monthDividerFormat = DateFormat('LLLL', 'ru');

/// How solid the three bottom-row buttons -- scan, expense, income -- sit
/// over the list behind them. One figure for all three rather than each
/// button choosing its own: they read as a set, so a difference in fill
/// opacity between them shows up as an inconsistency even when no single
/// button looks wrong on its own.
const double kFabFillOpacity = 0.82;

/// "Сентябрь" for the current year, "Сентябрь 2025" once it isn't -- the
/// label on a divider marking where one month's entries end and an older
/// month's begin in the chronological list. Not private, so it can be
/// unit-tested directly rather than only indirectly through a widget.
String monthDividerLabel(DateTime date) {
  final raw = _monthDividerFormat.format(date);
  final month = raw.isEmpty ? raw : raw[0].toUpperCase() + raw.substring(1);
  return date.year == DateTime.now().year ? month : '$month ${date.year}';
}

class HomeScreen extends StatefulWidget {
  final Household household;
  final List<Household> households;
  final ValueChanged<String> onSwitchHousehold;
  final ValueChanged<String> onLeaveHousehold;
  final VoidCallback onAddHousehold;

  const HomeScreen({
    super.key,
    required this.household,
    required this.households,
    required this.onSwitchHousehold,
    required this.onLeaveHousehold,
    required this.onAddHousehold,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  // Armed on launch and on every resume; disarmed once the tap behind it
  // has been read. Without it a resume for any other reason would reopen
  // the sheet.
  bool _widgetCheckArmed = true;
  AppCurrency? _lastCurrency;
  String? _publishedHousehold;

  // Bumped whenever the tour changes: anyone who had seen the old steps
  // would otherwise never be shown the controls added since. v3 added the
  // scanner, v4 the list row and the scanner's own wording, v5 the advice
  // tab.
  static const _tourSeenKey = 'onboarding_tour_seen_v5';

  final _repository = ExpenseRepository();
  final _scanFlow = ScanFlow();

  /// The scanner needs an address to talk to, passed in at build time. With
  /// none set there is nothing behind the button, so it is not shown at all
  /// -- and the tour skips its step rather than pointing at a gap.
  bool get _scanEnabled => ScanService.isConfigured;

  /// Same worker, same address as the scanner -- with none set there is
  /// nothing behind this button either, so it stays hidden rather than
  /// opening a screen that can only fail.
  bool get _adviceEnabled => AdviceService.isConfigured;
  final _settingsRepository = HouseholdSettingsRepository();

  final _incomeFabKey = GlobalKey();
  final _scanKey = GlobalKey();
  final _rowKey = GlobalKey();
  final _expenseFabKey = GlobalKey();
  final _summaryCardKey = GlobalKey();
  final _adviceKey = GlobalKey();
  final _clearKey = GlobalKey();
  final _themeKey = GlobalKey();
  final _viewModeKey = GlobalKey();
  final _currencyKey = GlobalKey();
  final _statsKey = GlobalKey();
  final _switcherKey = GlobalKey();
  bool _tourStarted = false;
  late final ShowcaseView _showcase;

  // Whether the list had a row to point the "hold to edit" step at when
  // the tour began. On a brand-new budget it does not, and the step is
  // left out rather than aimed at an empty list.
  bool _tourHasRows = false;

  // Each budget's own currency, fetched once (not a live stream -- nothing
  // in the app changes a budget's currency after creation) the first time
  // the switcher needs it, and kept here so reopening the switcher doesn't
  // re-fetch on every tap.
  final Map<String, AppCurrency> _householdCurrencies = {};
  bool _switcherLoading = false;

  // null means "show amounts in the household's own currency" (exact,
  // no conversion). Set when the user taps the currency toggle; reset
  // whenever the household changes, so switching budgets never leaves a
  // stale conversion showing.
  AppCurrency? _displayCurrency;

  // The flattened grouped view, kept against the expense list it came
  // from: between snapshots Firestore hands back the same instance, so
  // identity is enough to know the grouping still holds.
  List<Expense>? _groupedRowsFor;
  List<_GroupedRow>? _cachedGroupedRows;

  // The list's own controller, read by the top-edge fade so the band can
  // follow the scroll offset.
  final ScrollController _listController = ScrollController();

  // Off shows the full chronological history; on restricts to the current
  // month and clusters it by category instead. Not persisted -- it is a
  // way of looking at the list, not a setting worth remembering across
  // app launches, and the flat list is the safer default to reopen on.
  bool _groupedByCategory = false;

  // Held in fields rather than created inside build(): a stream built during
  // build is a brand-new Firestore listener on every rebuild, which drops the
  // loaded data back to a spinner and re-reads the collection each time.
  late Stream<AppCurrency> _currencyStream;
  late Stream<List<Expense>> _expensesStream;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _subscribeToHousehold();
    _showcase = ShowcaseView.register(
      onFinish: _markTourSeen,
      onDismiss: (_) => _markTourSeen(),
      skipIfTargetNotPresent: true,
      blurValue: 2,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    _widgetCheckArmed = true;
    final currency = _lastCurrency;
    if (currency != null) _maybeHandleWidgetLaunch(currency);
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
    WidgetsBinding.instance.removeObserver(this);
    _listController.dispose();
    _scanFlow.dispose();
    _showcase.unregister();
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
  // Called from build, so the common path -- "already started" -- has to be
  // synchronous: an async method allocates a Future even when it returns on
  // its first line, and that would be one per frame for the life of the
  // screen.
  void _maybeStartTour({required bool hasContent, required bool hasRows}) {
    if (_tourStarted || !hasContent) return;
    _tourStarted = true;
    _tourHasRows = hasRows;
    _startTour();
  }

  Future<void> _startTour() async {
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
    // Ordered the way the screen reads: what you are looking at, the two
    // things you do with it, the one destructive button, then the app bar
    // from left to right.
    _showcase.startShowCase(
      [
        _summaryCardKey,
        if (_adviceEnabled) _adviceKey,
        if (_tourHasRows) _rowKey,
        _expenseFabKey,
        _incomeFabKey,
        if (_scanEnabled) _scanKey,
        _clearKey,
        _themeKey,
        _viewModeKey,
        _currencyKey,
        _statsKey,
        _switcherKey,
      ],
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

  Future<void> _openScanner(
    List<Expense> expenses,
    AppCurrency currency,
  ) async {
    await _scanFlow.run(
      context,
      currency: currency,
      existing: expenses,
      onAdd: (added) async {
        await _repository.addExpenses(widget.household.code, added);
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..removeCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(added.length == 1
                  ? 'Запись добавлена'
                  : 'Добавлено записей: ${added.length}'),
            ),
          );
      },
    );
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

  Future<void> _showHouseholdSwitcher() async {
    final missing = widget.households
        .where((h) => !_householdCurrencies.containsKey(h.code))
        .toList();
    if (missing.isNotEmpty) {
      setState(() => _switcherLoading = true);
      final fetched = await Future.wait(
        missing.map((h) => _settingsRepository.fetchCurrency(h.code)),
      );
      for (var i = 0; i < missing.length; i++) {
        _householdCurrencies[missing[i].code] = fetched[i];
      }
      if (!mounted) return;
      setState(() => _switcherLoading = false);
    }
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => GlassSheet(
        child: HouseholdSwitcherSheet(
          households: widget.households,
          activeCode: widget.household.code,
          currencies: _householdCurrencies,
          onSwitch: widget.onSwitchHousehold,
          onAddHousehold: widget.onAddHousehold,
          onLeave: widget.onLeaveHousehold,
        ),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: expenseColor(context),
              foregroundColor: const Color(0xFFF6F2EA),
            ),
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

  void _openAdvice(List<Expense> expenses, AppCurrency currency) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AdviceScreen(
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
    ExpenseCategory? initialCategory,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => GlassSheet(
        child: AddExpenseSheet(
          type: type,
          currency: currency,
          existing: existing,
          initialCategory: initialCategory,
          onSubmit: _addExpense,
        ),
      ),
    );
  }

  /// Tells the widget which budget and currency to record into.
  ///
  /// Written whenever either changes rather than on every build: this runs
  /// inside build, and a preferences write per frame would be absurd.
  void _publishToWidget(AppCurrency currency) {
    if (_lastCurrency == currency &&
        _publishedHousehold == widget.household.code) {
      return;
    }
    _lastCurrency = currency;
    _publishedHousehold = widget.household.code;
    WidgetBridge.publish(
      householdCode: widget.household.code,
      currency: currency,
    );
  }

  /// Opens the sheet the home-screen widget asked for.
  ///
  /// The check is armed on launch and again on every resume, but it only
  /// runs once the currency stream has delivered -- on a cold start the
  /// first frame arrives before it does, and consuming the tap then would
  /// throw it away with nothing to open.
  void _maybeHandleWidgetLaunch(AppCurrency currency) {
    if (!_widgetCheckArmed) return;
    _widgetCheckArmed = false;
    _consumeWidgetLaunch(currency);
  }

  Future<void> _consumeWidgetLaunch(AppCurrency currency) async {
    final launch = await WidgetLaunchChannel.consume();
    if (launch == null || !mounted) return;
    _openAddSheet(
      launch.type,
      currency,
      initialCategory: launch.category,
    );
  }

  /// Same plain glyph treatment as the other AppBar icons -- it is the
  /// budget's own currency symbol, not a filled pill, so it reads as one
  /// of the toolbar's icons rather than a separate loud control. The only
  /// accent is a thin ring around it, and only once the toggle has
  /// actually been switched away from the household's own currency; the
  /// ring is always painted (transparent when off) so the button's size
  /// never shifts when it turns on.
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
          width: 36,
          height: 36,
          child: Center(
            child: Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isConverted
                    ? goldFor(context).withValues(alpha: 0.12)
                    : Colors.transparent,
                border: Border.all(
                  color: isConverted
                      ? goldFor(context).withValues(alpha: 0.7)
                      : Colors.transparent,
                  width: 1.2,
                ),
              ),
              child: Text(
                display.symbol,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: isConverted
                      ? goldFor(context)
                      : accentForeground(context).withValues(alpha: 0.78),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The swipe-to-delete / long-press-to-edit row shared by both the flat
  /// chronological list and the grouped-by-category view, so the two
  /// views can never drift out of sync on how a row behaves.
  Widget _buildExpenseRow(
    Expense expense, {
    required AppCurrency currency,
    required AppCurrency displayCurrency,
    required bool isConverted,
    bool showIcon = true,
  }) {
    final tileAmount = isConverted
        ? convertApprox(expense.amount, from: currency, to: displayCurrency)
        : null;
    return Dismissible(
      key: ValueKey(expense.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          // Was the light theme's constant in both rooms, so on Obsidian
          // the swipe flashed a colour from the other palette.
          color: expenseColor(context),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(
          Icons.delete_outline_rounded,
          color: Color(0xFFF6F2EA),
        ),
      ),
      onDismissed: (_) => _deleteExpense(expense),
      child: ExpenseTile(
        expense: expense,
        currency: displayCurrency,
        amountOverride: tileAmount,
        isApproximate: isConverted,
        showIcon: showIcon,
        onLongPress: () =>
            _openAddSheet(expense.type, currency, existing: expense),
      ),
    );
  }

  /// A thin rule with the month's name -- shared between the chronological
  /// list, where it appears only where the month actually changes between
  /// two rows, and the grouped view, where every month's cluster of
  /// categories gets one (a category header carries no date of its own,
  /// so without this the month it belongs to would be invisible).
  Widget _monthDivider(DateTime month) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 14, 0, 10),
      child: Row(
        children: [
          Text(
            monthDividerLabel(month).toUpperCase(),
            style: microLabel(
              context,
              color: goldFor(context).withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Divider(color: hairlineColor(context))),
        ],
      ),
    );
  }

  Widget _buildSeparator(List<Expense> expenses, int index) {
    final current = expenses[index].date;
    final next = expenses[index + 1].date;
    final monthChanged =
        current.year != next.year || current.month != next.month;
    return monthChanged ? _monthDivider(next) : const SizedBox(height: 7);
  }

  /// Wiping the budget lives in the bottom-left corner rather than in the
  /// app bar: it is the only destructive action on this screen, and it has
  /// no business sitting a few millimetres from the buttons people press
  /// several times a day.
  Widget _clearButton() {
    // Same button as the ones in the opposite corner -- a filled circle at
    // the same fill opacity -- just red and a size down, because it is the
    // one you should reach for least.
    return FloatingActionButton.small(
      heroTag: 'clear_budget',
      backgroundColor: expenseColor(context).withValues(alpha: kFabFillOpacity),
      foregroundColor: const Color(0xFFF6F2EA),
      onPressed: _confirmClearAll,
      tooltip: 'Очистить бюджет',
      child: const Icon(Icons.delete_sweep_outlined, size: 20),
    );
  }

  /// Flips the app between Ivory and Obsidian, first in the actions row.
  Widget _themeToggleButton() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return IconButton(
      onPressed: () => ThemeModeController.toggle(context),
      tooltip: isDark ? 'Светлая тема' : 'Тёмная тема',
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        transitionBuilder: (child, animation) => RotationTransition(
          turns: Tween<double>(begin: 0.6, end: 1).animate(animation),
          child: FadeTransition(opacity: animation, child: child),
        ),
        child: Icon(
          isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
          key: ValueKey(isDark),
          color: goldFor(context),
        ),
      ),
    );
  }

  /// First (leftmost) AppBar action: tap to flip between the plain
  /// chronological history and the same history clustered by category
  /// within each month (never mixing two different months' spending on
  /// one category into a single total). Icon-only, like the other AppBar
  /// actions -- the icon names the view a tap switches *to*, and the
  /// tooltip carries the same text for accessibility.
  Widget _viewModeToggle() {
    return IconButton(
      onPressed: () => setState(() => _groupedByCategory = !_groupedByCategory),
      icon: Icon(
        _groupedByCategory
            ? Icons.receipt_long_rounded
            : Icons.grid_view_rounded,
      ),
      tooltip: _groupedByCategory ? 'Список' : 'По категориям',
    );
  }

  /// The header row above each category's (or income's) transactions in
  /// the grouped view: icon, name and that category's total for the
  /// month, converted and marked approximate exactly like everywhere
  /// else a total is shown.
  Widget _groupHeader(
    CategoryGroup group, {
    required AppCurrency currency,
    required AppCurrency displayCurrency,
    required bool isConverted,
  }) {
    final total = isConverted
        ? convertApprox(group.total, from: currency, to: displayCurrency)
        : group.total;
    // buildCategoryGroups has no BuildContext, so income's colour is fixed
    // to the light palette there and resolved for the current room here.
    final color = group.isIncome ? incomeColor(context) : group.color;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 6, left: 2, right: 2),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.13),
              shape: BoxShape.circle,
              border: Border.all(
                color: color.withValues(alpha: 0.22),
                width: 1,
              ),
            ),
            child: Icon(group.icon, color: color, size: 16),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              group.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.1,
                color: accentForeground(context).withValues(alpha: 0.9),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              '${isConverted ? '≈ ' : ''}${displayCurrency.format.format(total)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: moneyStyle(
                size: 13,
                weight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The grouped view's content: every month present, newest first, each
  /// as a month divider followed by that month's categories -- the same
  /// boundary the chronological list's own dividers draw, just with the
  /// rows inside each month clustered by category instead of left in
  /// date order. Built up front rather than windowed: a personal
  /// household's whole history is still far short of where that would
  /// start to matter.
  /// Flattens the grouped view into one row list, cached against the
  /// expenses it was built from.
  ///
  /// The grouped view used to build every widget up front and hand the
  /// whole thing to a SliverChildListDelegate, which meant two costs on
  /// every rebuild -- regrouping the history, and constructing a widget
  /// per transaction whether or not it was anywhere near the screen.
  /// Flipping the theme or stepping the currency paid both. These rows
  /// are plain value objects instead, so the grouping happens once per
  /// snapshot and the widgets are built lazily as they scroll in, the
  /// way the flat list already worked.
  List<_GroupedRow> _groupedRows(List<Expense> expenses) {
    if (identical(_groupedRowsFor, expenses) && _cachedGroupedRows != null) {
      return _cachedGroupedRows!;
    }
    final rows = <_GroupedRow>[];
    for (final section in buildMonthSections(expenses)) {
      rows.add(_GroupedRow.month(section.month));
      for (final group in section.groups) {
        rows.add(_GroupedRow.header(group));
        for (var i = 0; i < group.items.length; i++) {
          rows.add(_GroupedRow.expense(
            group.items[i],
            isLastInGroup: i == group.items.length - 1,
          ));
        }
      }
    }
    _groupedRowsFor = expenses;
    _cachedGroupedRows = rows;
    return rows;
  }

  Widget _buildGroupedRow(
    _GroupedRow row, {
    required AppCurrency currency,
    required AppCurrency displayCurrency,
    required bool isConverted,
  }) {
    final month = row.month;
    if (month != null) return _monthDivider(month);

    final group = row.group;
    if (group != null) {
      return _groupHeader(
        group,
        currency: currency,
        displayCurrency: displayCurrency,
        isConverted: isConverted,
      );
    }

    // 7 between rows of a group, 21 before the next group's header --
    // the same rhythm the eagerly built version had.
    return Padding(
      padding: EdgeInsets.only(bottom: row.isLastInGroup ? 21 : 7),
      child: _buildExpenseRow(
        row.expense!,
        currency: currency,
        displayCurrency: displayCurrency,
        isConverted: isConverted,
        showIcon: false,
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
            final totals = expenseTotals(expenses);
            final displayCurrency = _displayCurrency ?? currency;
            final isConverted = displayCurrency != currency;
            final displayTotals = isConverted
                ? Totals(
                    todayIncome: convertApprox(totals.todayIncome,
                        from: currency, to: displayCurrency),
                    todayExpense: convertApprox(totals.todayExpense,
                        from: currency, to: displayCurrency),
                    monthIncome: convertApprox(totals.monthIncome,
                        from: currency, to: displayCurrency),
                    monthExpense: convertApprox(totals.monthExpense,
                        from: currency, to: displayCurrency),
                    allIncome: convertApprox(totals.allIncome,
                        from: currency, to: displayCurrency),
                    allExpense: convertApprox(totals.allExpense,
                        from: currency, to: displayCurrency),
                  )
                : totals;
            _publishToWidget(currency);
            _maybeHandleWidgetLaunch(currency);
            _maybeStartTour(
              hasContent: snapshot.hasData,
              hasRows: expenses.isNotEmpty && !_groupedByCategory,
            );
            return Scaffold(
              // The list runs under the app bar so there is something for
              // the bar's frosting to actually blur.
              extendBodyBehindAppBar: true,
              appBar: AppBar(
                flexibleSpace: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: appBarGlassTint(context),
                        border: Border(
                          bottom: BorderSide(color: hairlineColor(context)),
                        ),
                      ),
                    ),
                  ),
                ),
                title: Text(
                  widget.household.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                titleSpacing: 24,
                actions: [
                  tourStep(
                    context,
                    tourKey: _themeKey,
                    title: 'Тема',
                    description: 'Светлая и тёмная. Выбор запоминается и '
                        'переживает перезапуск',
                    child: _themeToggleButton(),
                  ),
                  tourStep(
                    context,
                    tourKey: _viewModeKey,
                    title: 'Список или категории',
                    description: 'Вся история подряд — или траты текущего '
                        'месяца, собранные по категориям',
                    child: _viewModeToggle(),
                  ),
                  tourStep(
                    context,
                    tourKey: _currencyKey,
                    title: 'Валюта',
                    description: 'Пересчитывает суммы в рубли, тенге или '
                        'доллары. Пересчёт приблизительный и помечен знаком ≈, '
                        'записи остаются в валюте бюджета',
                    child: _currencyToggleButton(currency),
                  ),
                  tourStep(
                    context,
                    tourKey: _statsKey,
                    title: 'Статистика',
                    description: 'Диаграмма трат по категориям, лимиты на '
                        'каждую и итоги за полгода',
                    child: IconButton(
                      onPressed: () => _openStats(expenses, currency),
                      icon: const Icon(Icons.pie_chart_rounded),
                      tooltip: 'По категориям',
                    ),
                  ),
                  tourStep(
                    context,
                    tourKey: _switcherKey,
                    title: 'Мои бюджеты',
                    description: 'Переключайтесь между бюджетами или '
                        'создайте новый, чтобы вести расходы с близкими',
                    isLast: true,
                    child: IconButton(
                      onPressed:
                          _switcherLoading ? null : _showHouseholdSwitcher,
                      icon: _switcherLoading
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              // backgroundColor keeps a full ring on
                              // screen at every frame -- without it, the
                              // moving arc spends part of its cycle as a
                              // short stray dash rather than a circle.
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                backgroundColor:
                                    goldFor(context).withValues(alpha: 0.16),
                                color: goldFor(context),
                              ),
                            )
                          : const Icon(Icons.people_alt_outlined),
                      tooltip: 'Мои бюджеты',
                    ),
                  ),
                  const SizedBox(width: 14),
                ],
              ),
              // All three buttons share the one FAB slot, laid out across the
              // full width. Only what sits in that slot is lifted when a
              // snackbar comes up, so the clear button -- previously a
              // Positioned child of the body -- stayed put while the other
              // two rose over the toast.
              floatingActionButtonLocation:
                  FloatingActionButtonLocation.centerFloat,
              // A plain ConstrainedBox rather than ReadableWidth: that one
              // centres on both axes, and Scaffold hands its button slot
              // loose constraints the size of the whole screen -- so the
              // row floated up to the middle of it instead of sitting on
              // the bottom edge. This caps the width and nothing else.
              floatingActionButton: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: ReadableWidth.maxWidth),
                child: Padding(
                  padding: const EdgeInsets.only(left: 22, right: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // An empty box still anchors spaceBetween, so the pair on
                      // the right keeps its place before the data arrives.
                      snapshot.hasData
                          ? tourStep(
                              context,
                              tourKey: _clearKey,
                              title: 'Очистить бюджет',
                              description: 'Удаляет все записи этого бюджета '
                                  'у всех его участников. Спросит подтверждение',
                              child: _clearButton(),
                            )
                          : const SizedBox.shrink(),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_scanEnabled) ...[
                            tourStep(
                              context,
                              tourKey: _scanKey,
                              title: 'Сканер с искусственным интеллектом',
                              description: 'Снимите чек или выберите скриншот '
                                  'из банка — ИИ прочитает суммы, даты и '
                                  'продавцов и сам разложит их по категориям. '
                                  'Выписку разберёт целиком, строку за '
                                  'строкой. Перед записью всё можно проверить '
                                  'и поправить: лишнее снять, ошибку — '
                                  'исправить',
                              child: FloatingActionButton.small(
                                heroTag: 'scan_receipt',
                                // A champagne wash blended into the
                                // sheet's own surface first -- blended
                                // rather than laid over, because over a
                                // row that happens to be the same
                                // near-white the sheet is, a translucent
                                // tint of the surface on the surface is no
                                // tint at all. That gives it a colour with
                                // real contrast to blend *from*; the same
                                // fixed translucency as its two neighbours
                                // is then applied on top of it, so all
                                // three buttons fade into the list behind
                                // them by the same amount.
                                backgroundColor: Color.alphaBlend(
                                  goldFor(context).withValues(alpha: 0.14),
                                  sheetSurface(context),
                                ).withValues(alpha: kFabFillOpacity),
                                foregroundColor: goldFor(context),
                                elevation: 3,
                                shape: CircleBorder(
                                  side: BorderSide(
                                    color: goldFor(context)
                                        .withValues(alpha: 0.55),
                                  ),
                                ),
                                onPressed: () =>
                                    _openScanner(expenses, currency),
                                tooltip: 'Распознать чек или скриншот — ИИ',
                                child: const AiScanIcon(size: 20),
                              ),
                            ),
                            const SizedBox(height: 14),
                          ],
                          tourStep(
                            context,
                            tourKey: _expenseFabKey,
                            title: 'Добавить расход',
                            description:
                                'Нажмите, чтобы записать трату. Смахните '
                                'запись влево, чтобы удалить, или зажмите её, '
                                'чтобы изменить',
                            child: FloatingActionButton(
                              heroTag: 'add_expense',
                              backgroundColor: (Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? kChampagne
                                      : kAccentColor)
                                  .withValues(alpha: kFabFillOpacity),
                              onPressed: () => _openAddSheet(
                                  TransactionType.expense, currency),
                              tooltip: 'Добавить расход',
                              child: const Icon(Icons.remove_rounded),
                            ),
                          ),
                          const SizedBox(height: 14),
                          tourStep(
                            context,
                            tourKey: _incomeFabKey,
                            title: 'Добавить доход',
                            description:
                                'Нажмите, чтобы записать поступление денег',
                            child: FloatingActionButton(
                              heroTag: 'add_income',
                              backgroundColor: incomeColor(context)
                                  .withValues(alpha: kFabFillOpacity),
                              foregroundColor: const Color(0xFFF6F2EA),
                              onPressed: () => _openAddSheet(
                                  TransactionType.income, currency),
                              tooltip: 'Добавить доход',
                              child: const Icon(Icons.add_rounded),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              body: AppBackgroundPattern(
                child: ReadableWidth(
                  child: !snapshot.hasData
                      ? Center(
                          // backgroundColor keeps a full ring on screen at
                          // every frame -- without it, the moving arc
                          // spends part of its cycle as a short stray dash
                          // rather than a circle.
                          child: CircularProgressIndicator(
                            backgroundColor:
                                goldFor(context).withValues(alpha: 0.16),
                            color: goldFor(context),
                          ),
                        )
                      // The totals stay put and only the history moves: the
                      // card is the one thing on this screen you want to be
                      // able to read while scrolling through everything else.
                      : Column(
                          children: [
                            Padding(
                              padding: EdgeInsets.fromLTRB(
                                20,
                                MediaQuery.of(context).padding.top +
                                    kToolbarHeight +
                                    10,
                                20,
                                8,
                              ),
                              // A plain Column: both the card and the
                              // button size themselves to the full width
                              // Column already bounds them to, so unlike a
                              // Row asked to match a sibling's height, there
                              // is no shared-size trick needed between them.
                              child: Column(
                                children: [
                                  tourStep(
                                    context,
                                    tourKey: _summaryCardKey,
                                    title: 'Итоги',
                                    description: 'Сколько потрачено и '
                                        'заработано сегодня, за месяц и за '
                                        'всё время — видно, пока листаете '
                                        'список',
                                    targetShapeBorder:
                                        const RoundedRectangleBorder(
                                      borderRadius: BorderRadius.all(
                                        Radius.circular(24),
                                      ),
                                    ),
                                    child: SummaryCard(
                                      todayExpenseTotal:
                                          displayTotals.todayExpense,
                                      todayIncomeTotal:
                                          displayTotals.todayIncome,
                                      monthExpenseTotal:
                                          displayTotals.monthExpense,
                                      monthIncomeTotal:
                                          displayTotals.monthIncome,
                                      allExpenseTotal: displayTotals.allExpense,
                                      allIncomeTotal: displayTotals.allIncome,
                                      currency: displayCurrency,
                                      isApproximate: isConverted,
                                    ),
                                  ),
                                  if (_adviceEnabled) ...[
                                    const SizedBox(height: 6),
                                    tourStep(
                                      context,
                                      tourKey: _adviceKey,
                                      title: 'Советы по расходам',
                                      description: 'Искусственный интеллект '
                                          'разбирает траты за месяц и '
                                          'подсказывает, на чём можно '
                                          'сэкономить',
                                      targetShapeBorder: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: AdviceTabButton(
                                        onTap: () => _openAdvice(
                                          expenses,
                                          displayCurrency,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Expanded(
                              // Rows slide up under the totals card and
                              // dissolve there. Without this the list is simply
                              // clipped at the card's edge, which reads as a
                              // rendering mistake rather than as depth.
                              child: TopFadeMask(
                                controller: _listController,
                                child: CustomScrollView(
                                  controller: _listController,
                                  slivers: [
                                    if (_groupedByCategory)
                                      if (expenses.isEmpty)
                                        const SliverFillRemaining(
                                          hasScrollBody: false,
                                          child: _EmptyState(),
                                        )
                                      else
                                        SliverPadding(
                                          padding: const EdgeInsets.fromLTRB(
                                              24, 22, 24, 100),
                                          sliver: SliverList.builder(
                                            itemCount:
                                                _groupedRows(expenses).length,
                                            itemBuilder: (context, index) =>
                                                _buildGroupedRow(
                                              _groupedRows(expenses)[index],
                                              currency: currency,
                                              displayCurrency: displayCurrency,
                                              isConverted: isConverted,
                                            ),
                                          ),
                                        )
                                    else if (expenses.isEmpty)
                                      const SliverFillRemaining(
                                        hasScrollBody: false,
                                        child: _EmptyState(),
                                      )
                                    else
                                      SliverPadding(
                                        padding: const EdgeInsets.fromLTRB(
                                            24, 22, 24, 100),
                                        sliver: SliverList.separated(
                                          itemCount: expenses.length,
                                          separatorBuilder: (context, index) =>
                                              _buildSeparator(expenses, index),
                                          itemBuilder: (context, index) {
                                            final row = _buildExpenseRow(
                                              expenses[index],
                                              currency: currency,
                                              displayCurrency: displayCurrency,
                                              isConverted: isConverted,
                                            );
                                            // The tour points at the top
                                            // row: the two gestures a row
                                            // answers to are invisible
                                            // until someone says so.
                                            if (index != 0) return row;
                                            return tourStep(
                                              context,
                                              tourKey: _rowKey,
                                              title: 'Запись в списке',
                                              description: 'Зажмите запись, '
                                                  'чтобы изменить сумму, '
                                                  'категорию, дату или '
                                                  'заметку. Смахните влево — '
                                                  'удалить, с возможностью '
                                                  'отменить',
                                              targetShapeBorder:
                                                  RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              child: row,
                                            );
                                          },
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Sums today's, this month's and every recorded income and expense in a
/// single pass, instead of walking the whole list once per figure on every
/// rebuild.
///
/// [now] is injectable so the split can be tested without waiting for a
/// particular date to come round.
Totals expenseTotals(List<Expense> expenses, {DateTime? now}) {
  final today = now ?? DateTime.now();
  var totals = const Totals();
  for (final expense in expenses) {
    final date = expense.date;
    final inMonth = date.year == today.year && date.month == today.month;
    totals = totals.add(
      amount: expense.amount,
      isIncome: expense.isIncome,
      isToday: inMonth && date.day == today.day,
      inMonth: inMonth,
    );
  }
  return totals;
}

class Totals {
  final double todayIncome;
  final double todayExpense;
  final double monthIncome;
  final double monthExpense;
  final double allIncome;
  final double allExpense;

  const Totals({
    this.todayIncome = 0,
    this.todayExpense = 0,
    this.monthIncome = 0,
    this.monthExpense = 0,
    this.allIncome = 0,
    this.allExpense = 0,
  });

  Totals add({
    required double amount,
    required bool isIncome,
    required bool isToday,
    required bool inMonth,
  }) {
    return Totals(
      todayIncome: todayIncome + (isIncome && isToday ? amount : 0),
      todayExpense: todayExpense + (!isIncome && isToday ? amount : 0),
      monthIncome: monthIncome + (isIncome && inMonth ? amount : 0),
      monthExpense: monthExpense + (!isIncome && inMonth ? amount : 0),
      allIncome: allIncome + (isIncome ? amount : 0),
      allExpense: allExpense + (!isIncome ? amount : 0),
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
              color: accentForeground(context).withValues(alpha: 0.55),
            ),
            const SizedBox(height: 16),
            Text(
              'Пока нет расходов',
              textAlign: TextAlign.center,
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

/// One line of the grouped view: a month divider, a category header, or a
/// transaction. Exactly one field is non-null.
class _GroupedRow {
  final DateTime? month;
  final CategoryGroup? group;
  final Expense? expense;

  /// Only meaningful on an expense row: the last of a category carries the
  /// wider gap that separates one category from the next.
  final bool isLastInGroup;

  const _GroupedRow._({
    this.month,
    this.group,
    this.expense,
    this.isLastInGroup = false,
  });

  const _GroupedRow.month(DateTime value) : this._(month: value);
  const _GroupedRow.header(CategoryGroup value) : this._(group: value);
  const _GroupedRow.expense(Expense value, {bool isLastInGroup = false})
      : this._(expense: value, isLastInGroup: isLastInGroup);
}
