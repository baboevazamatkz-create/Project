import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:expense_tracker/models/currency.dart';
import 'package:expense_tracker/models/expense.dart';
import 'package:expense_tracker/models/household.dart';
import 'package:expense_tracker/models/transaction_type.dart';
import 'package:expense_tracker/models/expense_category.dart';
import 'package:expense_tracker/screens/household_screen.dart';
import 'package:expense_tracker/screens/stats_screen.dart';
import 'package:expense_tracker/theme.dart';
import 'package:expense_tracker/widgets/add_expense_sheet.dart';
import 'package:expense_tracker/widgets/expense_tile.dart';
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

    expect(find.text('Трекинг расходов'), findsOneWidget);
    expect(find.text('Создать новый бюджет'), findsOneWidget);
    expect(find.text('Присоединиться по коду'), findsOneWidget);
  });

  testWidgets('Budget switcher icons stay visible on the dark theme',
      (tester) async {
    // The sheet is drawn in the brand green rather than the near-black ink
    // accent, which used to disappear into the dark background entirely.
    await _pumpAt(
      tester,
      Scaffold(
        body: HouseholdSwitcherSheet(
          households: const [
            Household(code: 'ABCD2345', label: 'Семья'),
            Household(code: 'EFGH6789', label: 'Работа'),
          ],
          activeCode: 'ABCD2345',
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
    expect(checkIcon.color, kBrandColor);

    final coinIcon = tester.widget<Icon>(
      find.byIcon(Icons.monetization_on_rounded).first,
    );
    expect(coinIcon.color, kBrandColor);
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
