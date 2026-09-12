import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:expense_tracker/models/category_group.dart';
import 'package:expense_tracker/models/currency.dart';
import 'package:expense_tracker/models/expense.dart';
import 'package:expense_tracker/models/household.dart';
import 'package:expense_tracker/models/transaction_type.dart';
import 'package:expense_tracker/models/expense_category.dart';
import 'package:expense_tracker/screens/home_screen.dart'
    show monthDividerLabel;
import 'package:expense_tracker/screens/household_screen.dart';
import 'package:expense_tracker/screens/stats_screen.dart';
import 'package:expense_tracker/theme.dart';
import 'package:expense_tracker/widgets/add_expense_sheet.dart';
import 'package:expense_tracker/widgets/expense_tile.dart';
import 'package:expense_tracker/widgets/currency_symbol_icon.dart';
import 'package:expense_tracker/widgets/household_switcher_sheet.dart';
import 'package:expense_tracker/widgets/summary_card.dart';

/// Screen sizes worth covering: a small budget phone, a common modern phone
/// and a tablet.
const _screenSizes = <String, Size>{
  'small phone': Size(320, 534),
  'modern phone': Size(411, 891),
  'phone landscape': Size(891, 411),
  'tablet': Size(800, 1280),
};

/// The range the app clamps the system font scale to, plus the default.
const _textScales = <double>[0.85, 1.0, 1.25];

Future<void> _pumpAt(
  WidgetTester tester,
  Widget child, {
  required Size size,
  required double textScale,
  Brightness brightness = Brightness.light,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(brightness),
      builder: (context, inner) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
        ),
        child: inner!,
      ),
      home: child,
    ),
  );
  await tester.pumpAndSettle();
}

/// Runs [build] on every screen size and font scale combination and fails if
/// any of them overflows or otherwise throws while laying out.
void testAcrossScreens(String description, Widget Function() build) {
  for (final entry in _screenSizes.entries) {
    for (final scale in _textScales) {
      testWidgets('$description — ${entry.key} @ ${scale}x', (tester) async {
        await _pumpAt(tester, build(), size: entry.value, textScale: scale);
        expect(tester.takeException(), isNull);
      });
    }
  }

  // The app follows the system theme, so every screen has to survive the dark
  // one too.
  testWidgets('$description — dark theme', (tester) async {
    await _pumpAt(
      tester,
      build(),
      size: _screenSizes['modern phone']!,
      textScale: 1.0,
      brightness: Brightness.dark,
    );
    expect(tester.takeException(), isNull);
  });
}

void main() {
  setUpAll(() => initializeDateFormatting('ru'));

  testWidgets('Household screen offers create and join actions',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HouseholdScreen(onReady: (_) {}),
      ),
    );

    expect(find.text('Общий бюджет\nна двоих'), findsOneWidget);
    expect(find.text('Создать новый бюджет'), findsOneWidget);
    expect(find.text('Присоединиться по коду'), findsOneWidget);
  });

  testWidgets('Budget switcher icons stay visible on the dark theme',
      (tester) async {
    // The sheet is drawn in the champagne accent rather than the near-black
    // ink, which used to disappear into the dark background entirely -- and
    // on dark it is the *lighter* champagne, since the deep one goes muddy
    // against near-black.
    await _pumpAt(
      tester,
      Scaffold(
        body: HouseholdSwitcherSheet(
          households: const [
            Household(code: 'ABCD2345', label: 'Семья'),
            Household(code: 'EFGH6789', label: 'Работа'),
          ],
          activeCode: 'ABCD2345',
          currencies: const {
            'ABCD2345': AppCurrency.rub,
            'EFGH6789': AppCurrency.usd,
          },
          onSwitch: (_) {},
          onAddHousehold: () {},
        ),
      ),
      size: _screenSizes['modern phone']!,
      textScale: 1.0,
      brightness: Brightness.dark,
    );

    final checkIcon = tester.widget<Icon>(
      find.byIcon(Icons.check_circle_rounded),
    );
    expect(checkIcon.color, kChampagne);

    // The coin icon was replaced by the currency's own symbol (see
    // CurrencySymbolIcon); check that took the same colour.
    final symbolText = tester.widget<Text>(
      find.descendant(
        of: find.byType(CurrencySymbolIcon).first,
        matching: find.byType(Text),
      ),
    );
    expect(symbolText.style?.color, kChampagne);
  });

  testWidgets(
      'Budget switcher shows each budget\'s own currency, not the active one',
      (tester) async {
    // A ruble budget and a dollar budget in the same list: the icon on
    // each row must match that row's own currency, not whichever budget
    // happens to be open (activeCode is the ruble one here).
    await _pumpAt(
      tester,
      Scaffold(
        body: HouseholdSwitcherSheet(
          households: const [
            Household(code: 'ABCD2345', label: 'Семья'),
            Household(code: 'EFGH6789', label: 'Доллары'),
          ],
          activeCode: 'ABCD2345',
          currencies: const {
            'ABCD2345': AppCurrency.rub,
            'EFGH6789': AppCurrency.usd,
          },
          onSwitch: (_) {},
          onAddHousehold: () {},
        ),
      ),
      size: _screenSizes['modern phone']!,
      textScale: 1.0,
    );

    final symbols = tester
        .widgetList<Text>(find.descendant(
          of: find.byType(CurrencySymbolIcon),
          matching: find.byType(Text),
        ))
        .map((t) => t.data)
        .toList();
    expect(
        symbols,
        containsAll(<String>[
          AppCurrency.rub.symbol,
          AppCurrency.usd.symbol,
        ]));
  });

  testAcrossScreens(
    'Household screen lays out',
    () => HouseholdScreen(onReady: (_) {}),
  );

  testAcrossScreens(
    'Summary card lays out with large amounts',
    () => const Scaffold(
      body: Padding(
        padding: EdgeInsets.all(24),
        child: SummaryCard(
          todayExpenseTotal: 1234567,
          todayIncomeTotal: 7654321,
          monthExpenseTotal: 98765432,
          monthIncomeTotal: 12345678,
          currency: AppCurrency.kzt,
        ),
      ),
    ),
  );

  testAcrossScreens(
    'Expense row lays out with a long note',
    () => Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: ExpenseTile(
          expense: Expense(
            id: 'a',
            amount: 12345678,
            date: DateTime(2026, 1, 15),
            category: ExpenseCategory.entertainment,
            note: 'Очень длинная заметка, которая точно не помещается в строку',
            type: TransactionType.expense,
          ),
          currency: AppCurrency.kzt,
        ),
      ),
    ),
  );

  testAcrossScreens(
    'Budget switcher lays out with a long budget name',
    () => Scaffold(
      body: HouseholdSwitcherSheet(
        households: const [
          Household(
            code: 'ABCD2345',
            label: 'Очень длинное название общего семейного бюджета',
          ),
          Household(code: 'EFGH6789', label: 'Работа'),
        ],
        activeCode: 'ABCD2345',
        currencies: const {
          'ABCD2345': AppCurrency.kzt,
          'EFGH6789': AppCurrency.rub,
        },
        onSwitch: (_) {},
        onAddHousehold: () {},
      ),
    ),
  );

  testAcrossScreens(
    'Add-budget screen lays out when opened from the switcher',
    () => HouseholdScreen(onReady: (_) {}, canCancel: true),
  );

  testAcrossScreens(
    'New expense sheet lays out with every category chip',
    () => const Scaffold(
      body: AddExpenseSheet(
        type: TransactionType.expense,
        currency: AppCurrency.kzt,
        onSubmit: _ignoreExpense,
      ),
    ),
  );

  testAcrossScreens(
    'New income sheet lays out',
    () => const Scaffold(
      body: AddExpenseSheet(
        type: TransactionType.income,
        currency: AppCurrency.rub,
        onSubmit: _ignoreExpense,
      ),
    ),
  );

  testAcrossScreens(
    'Income row lays out',
    () => Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: ExpenseTile(
          expense: Expense(
            id: 'b',
            amount: 9876543,
            date: DateTime(2026, 9, 30),
            note: '',
            type: TransactionType.income,
          ),
          currency: AppCurrency.rub,
        ),
      ),
    ),
  );

  testAcrossScreens(
    'Category breakdown lays out with limits set',
    () => Scaffold(
      body: CategoriesTab(
        entries: _categoryEntries,
        currency: AppCurrency.kzt,
        budgetsStream: Stream.value({
          for (final entry in _categoryEntries)
            entry.key.storageKey: entry.value * 0.8,
        }),
        onEditBudget: _ignoreBudget,
      ),
    ),
  );

  testAcrossScreens(
    'Category breakdown lays out without limits',
    () => Scaffold(
      body: CategoriesTab(
        entries: _categoryEntries,
        currency: AppCurrency.rub,
        budgetsStream: Stream.value(const <String, double>{}),
        onEditBudget: _ignoreBudget,
      ),
    ),
  );

  testAcrossScreens(
    'Monthly history lays out',
    () => Scaffold(
      body: HistoryTab(
        monthlyTotals: _monthlyTotals,
        currency: AppCurrency.kzt,
        monthLabel: DateFormat('LLL', 'ru').format,
      ),
    ),
  );

  group('buildCategoryGroups', () {
    final september = DateTime(2026, 9);

    test('only includes expenses that fall within the given month', () {
      final inMonth = Expense(
        id: 'a',
        amount: 500,
        date: DateTime(2026, 9, 10),
        category: ExpenseCategory.food,
      );
      final outOfMonth = Expense(
        id: 'b',
        amount: 999,
        date: DateTime(2026, 8, 10),
        category: ExpenseCategory.food,
      );
      final groups = buildCategoryGroups(
        [inMonth, outOfMonth],
        month: september,
      );
      expect(groups, hasLength(1));
      expect(groups.single.items, [inMonth]);
      expect(groups.single.total, 500);
    });

    test('income forms its own group, listed first', () {
      final income = Expense(
        id: 'i',
        amount: 1000,
        date: DateTime(2026, 9, 3),
        type: TransactionType.income,
      );
      final food = Expense(
        id: 'f',
        amount: 300,
        date: DateTime(2026, 9, 3),
        category: ExpenseCategory.food,
      );
      final groups = buildCategoryGroups([food, income], month: september);
      expect(groups.first.label, 'Доход');
      expect(groups.first.total, 1000);
    });

    test('categories are ordered by total spent, highest first', () {
      final smallFood = Expense(
        id: 'f1',
        amount: 100,
        date: DateTime(2026, 9, 1),
        category: ExpenseCategory.food,
      );
      final bigTransport = Expense(
        id: 't1',
        amount: 5000,
        date: DateTime(2026, 9, 2),
        category: ExpenseCategory.transport,
      );
      final groups = buildCategoryGroups(
        [smallFood, bigTransport],
        month: september,
      );
      expect(groups.map((g) => g.label), ['Транспорт', 'Еда']);
    });

    test("sums every transaction in a category into that group's total", () {
      final a = Expense(
        id: 'a',
        amount: 100,
        date: DateTime(2026, 9, 1),
        category: ExpenseCategory.food,
      );
      final b = Expense(
        id: 'b',
        amount: 250,
        date: DateTime(2026, 9, 15),
        category: ExpenseCategory.food,
      );
      final groups = buildCategoryGroups([a, b], month: september);
      expect(groups.single.total, 350);
      expect(groups.single.items, hasLength(2));
    });

    test('a month with nothing recorded produces no groups', () {
      expect(buildCategoryGroups(<Expense>[], month: september), isEmpty);
    });
  });

  group('buildMonthSections', () {
    test('splits into one section per calendar month, newest first', () {
      final expenses = [
        Expense(
          id: 'a',
          amount: 100,
          date: DateTime(2026, 7, 5),
          category: ExpenseCategory.food,
        ),
        Expense(
          id: 'b',
          amount: 200,
          date: DateTime(2026, 9, 1),
          category: ExpenseCategory.food,
        ),
        Expense(
          id: 'c',
          amount: 300,
          date: DateTime(2026, 8, 20),
          category: ExpenseCategory.food,
        ),
      ];
      final sections = buildMonthSections(expenses);
      expect(sections.map((s) => s.month), [
        DateTime(2026, 9),
        DateTime(2026, 8),
        DateTime(2026, 7),
      ]);
    });

    test('is correctly ordered regardless of the input order', () {
      // buildMonthSections must not assume expenses arrive newest-first.
      final expenses = [
        Expense(
          id: 'old',
          amount: 100,
          date: DateTime(2026, 1, 1),
          category: ExpenseCategory.food,
        ),
        Expense(
          id: 'new',
          amount: 100,
          date: DateTime(2026, 12, 1),
          category: ExpenseCategory.food,
        ),
      ];
      final sections = buildMonthSections(expenses);
      expect(sections.first.month, DateTime(2026, 12));
      expect(sections.last.month, DateTime(2026, 1));
    });

    test("each section's groups never mix another month's spending in", () {
      final september = Expense(
        id: 'sep',
        amount: 1000,
        date: DateTime(2026, 9, 10),
        category: ExpenseCategory.food,
      );
      final august = Expense(
        id: 'aug',
        amount: 5000,
        date: DateTime(2026, 8, 10),
        category: ExpenseCategory.food,
      );
      final sections = buildMonthSections([september, august]);
      final septemberSection =
          sections.firstWhere((s) => s.month == DateTime(2026, 9));
      expect(septemberSection.groups.single.total, 1000);
      expect(septemberSection.groups.single.items, [september]);
    });

    test('an empty list produces no sections', () {
      expect(buildMonthSections(<Expense>[]), isEmpty);
    });
  });

  group('monthDividerLabel', () {
    test('omits the year for the current calendar year', () {
      final thisYear = DateTime(DateTime.now().year, 9, 1);
      expect(monthDividerLabel(thisYear), 'Сентябрь');
    });

    test('includes the year once it is not the current one', () {
      expect(monthDividerLabel(DateTime(2019, 3, 1)), 'Март 2019');
    });
  });

  group('convertApprox', () {
    test('same currency is returned unchanged, not just approximately equal',
        () {
      expect(convertApprox(12345, from: AppCurrency.usd, to: AppCurrency.usd),
          12345);
    });

    test('round-tripping through another currency returns to the original', () {
      const original = 50000.0;
      final toUsd =
          convertApprox(original, from: AppCurrency.rub, to: AppCurrency.usd);
      final back =
          convertApprox(toUsd, from: AppCurrency.usd, to: AppCurrency.rub);
      expect(back, closeTo(original, 0.001));
    });

    test('a dollar is worth many more tenge than one, in that direction', () {
      final kzt = convertApprox(1, from: AppCurrency.usd, to: AppCurrency.kzt);
      expect(kzt, greaterThan(100));
    });
  });

  testWidgets('Summary card marks converted totals as approximate',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SummaryCard(
            todayExpenseTotal: 1000,
            todayIncomeTotal: 2000,
            monthExpenseTotal: 1000,
            monthIncomeTotal: 2000,
            currency: AppCurrency.usd,
            isApproximate: true,
          ),
        ),
      ),
    );
    expect(find.textContaining('≈'), findsWidgets);
  });

  testWidgets('Summary card does not mark exact totals as approximate',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SummaryCard(
            todayExpenseTotal: 1000,
            todayIncomeTotal: 2000,
            monthExpenseTotal: 1000,
            monthIncomeTotal: 2000,
            currency: AppCurrency.rub,
          ),
        ),
      ),
    );
    expect(find.textContaining('≈'), findsNothing);
  });

  testWidgets('Expense row shows the override amount, not the recorded one',
      (tester) async {
    final expense = Expense(
      id: 'c',
      amount: 1000,
      date: DateTime(2026, 9, 1),
      category: ExpenseCategory.food,
      type: TransactionType.expense,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExpenseTile(
            expense: expense,
            currency: AppCurrency.usd,
            amountOverride: 11.63,
            isApproximate: true,
          ),
        ),
      ),
    );
    // The recorded amount (1000 RUB) must not appear; only the converted
    // override, marked approximate, should render.
    expect(find.textContaining('1 000'), findsNothing);
    expect(find.textContaining('≈'), findsWidgets);
  });

  testWidgets(
      'Expense row hides its icon when told to, keeping the title and note',
      (tester) async {
    final withNote = Expense(
      id: 'd',
      amount: 500,
      date: DateTime(2026, 9, 1),
      category: ExpenseCategory.food,
      note: 'Кофе с собой',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExpenseTile(
            expense: withNote,
            currency: AppCurrency.rub,
            showIcon: false,
          ),
        ),
      ),
    );
    // The category's icon (shown once already in the group header above
    // this row in the grouped view) does not repeat on the row itself...
    expect(find.byIcon(ExpenseCategory.food.icon), findsNothing);
    // ...but the row's own title and note still show.
    expect(find.text('Еда'), findsOneWidget);
    expect(find.text('Кофе с собой'), findsOneWidget);
  });

  testWidgets('Expense row shows its icon by default', (tester) async {
    final expense = Expense(
      id: 'e',
      amount: 500,
      date: DateTime(2026, 9, 1),
      category: ExpenseCategory.food,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExpenseTile(expense: expense, currency: AppCurrency.rub),
        ),
      ),
    );
    expect(find.byIcon(ExpenseCategory.food.icon), findsOneWidget);
    expect(find.text('Еда'), findsOneWidget);
  });
}

final _categoryEntries = <MapEntry<ExpenseCategory, double>>[
  for (final category in ExpenseCategory.values)
    MapEntry(category, 1234567.0 - category.index * 1000),
];

final _monthlyTotals = <MapEntry<DateTime, double>>[
  for (var i = 5; i >= 0; i--)
    MapEntry(DateTime(2026, 9 - i), 1234567.0 - i * 100000),
];

void _ignoreExpense(Expense expense) {}

void _ignoreBudget(ExpenseCategory category, double? current) {}
