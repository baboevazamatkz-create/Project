import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:expense_tracker/data/advice_service.dart';
import 'package:expense_tracker/models/currency.dart';
import 'package:expense_tracker/models/expense.dart';
import 'package:expense_tracker/models/expense_category.dart';
import 'package:expense_tracker/models/spending_advice.dart';
import 'package:expense_tracker/models/spending_snapshot.dart';
import 'package:expense_tracker/models/transaction_type.dart';
import 'package:expense_tracker/theme.dart';
import 'package:expense_tracker/widgets/advice_tab_button.dart';
import 'package:expense_tracker/widgets/summary_card.dart';

const _endpoint = 'https://scan.example.test';

/// The shape worker/src/index.js answers with for /advice. Kept here
/// verbatim so a change on either side shows up as a failing test rather
/// than as a blank screen behind the "СОВЕТЫ" tab.
const _workerAnswer = {
  'verdict': 'concerning',
  'headline': 'В этом месяце еда и такси съели больше половины бюджета',
  'tips': [
    {
      'category': 'food',
      'severity': 'warning',
      'title': 'Слишком много на еду',
      'detail': 'Расходы на еду выросли вдвое по сравнению с прошлым '
          'месяцем — стоит чаще готовить дома',
    },
    {
      'category': 'transport',
      'severity': 'info',
      'title': 'Такси вместо прогулок',
      'detail': 'Часть коротких поездок можно заменить пешими — это и '
          'бюджету, и здоровью на пользу',
    },
  ],
};

AdviceService _service(
  Future<http.Response> Function(http.Request request) handler, {
  String? token = 'test-token',
}) =>
    AdviceService(
      endpoint: _endpoint,
      token: () async => token,
      client: MockClient(handler),
    );

Expense _expense({
  required double amount,
  required DateTime date,
  ExpenseCategory category = ExpenseCategory.food,
  TransactionType type = TransactionType.expense,
}) =>
    Expense(
      id: '${type.name}-$amount-${date.year}-${date.month}-${date.day}',
      amount: amount,
      date: date,
      type: type,
      category: type == TransactionType.income ? null : category,
    );

void main() {
  group('Building the snapshot', () {
    test('splits expenses into this month and last, by category', () {
      final now = DateTime(2026, 9, 15);
      final expenses = [
        _expense(amount: 1000, date: DateTime(2026, 9, 5)),
        _expense(amount: 500, date: DateTime(2026, 9, 10)),
        _expense(
            amount: 2000,
            date: DateTime(2026, 9, 12),
            category: ExpenseCategory.transport),
        _expense(amount: 700, date: DateTime(2026, 8, 20)),
        _expense(
            amount: 30000,
            date: DateTime(2026, 9, 1),
            type: TransactionType.income),
        // Two months back: neither bucket.
        _expense(amount: 999, date: DateTime(2026, 7, 1)),
      ];

      final snapshot = buildSpendingSnapshot(
        expenses,
        currency: AppCurrency.rub,
        limits: const {},
        now: now,
      );

      expect(snapshot.daysElapsedInMonth, 15);
      expect(snapshot.daysInMonth, 30);
      expect(snapshot.thisMonth.income, 30000);
      expect(snapshot.thisMonth.expense, 3500);
      expect(snapshot.thisMonth.categories[ExpenseCategory.food]!.amount, 1500);
      expect(snapshot.thisMonth.categories[ExpenseCategory.food]!.count, 2);
      expect(snapshot.thisMonth.categories[ExpenseCategory.transport]!.amount,
          2000);
      expect(snapshot.lastMonth.expense, 700);
      expect(snapshot.lastMonth.categories[ExpenseCategory.food]!.amount, 700);
      // The two-months-back record and the income aren't in either bucket's
      // category totals.
      expect(snapshot.recordCount, 4);
    });

    test('an income record with no category still counts toward income', () {
      final snapshot = buildSpendingSnapshot(
        [
          _expense(
              amount: 500,
              date: DateTime(2026, 9, 1),
              type: TransactionType.income),
        ],
        currency: AppCurrency.rub,
        limits: const {},
        now: DateTime(2026, 9, 15),
      );

      expect(snapshot.thisMonth.income, 500);
      expect(snapshot.thisMonth.categories, isEmpty);
    });

    test(
        'the fingerprint is stable for the same numbers and changes when '
        'they do', () {
      final now = DateTime(2026, 9, 15);
      final base = buildSpendingSnapshot(
        [_expense(amount: 1000, date: DateTime(2026, 9, 5))],
        currency: AppCurrency.rub,
        limits: const {ExpenseCategory.food: 5000},
        now: now,
      );
      final same = buildSpendingSnapshot(
        [_expense(amount: 1000, date: DateTime(2026, 9, 5))],
        currency: AppCurrency.rub,
        limits: const {ExpenseCategory.food: 5000},
        now: now,
      );
      final changed = buildSpendingSnapshot(
        [_expense(amount: 1001, date: DateTime(2026, 9, 5))],
        currency: AppCurrency.rub,
        limits: const {ExpenseCategory.food: 5000},
        now: now,
      );

      expect(base.fingerprint, same.fingerprint);
      expect(base.fingerprint, isNot(changed.fingerprint));
    });

    test('the request payload never carries note text or merchant names', () {
      final snapshot = buildSpendingSnapshot(
        [
          Expense(
            id: '1',
            amount: 1000,
            date: DateTime(2026, 9, 5),
            category: ExpenseCategory.food,
            note: 'Пятёрочка, ул. Ленина',
          ),
        ],
        currency: AppCurrency.rub,
        limits: const {},
        now: DateTime(2026, 9, 15),
      );

      final json = jsonEncode(snapshot.toRequestJson());
      expect(json, isNot(contains('Пятёрочка')));
      expect(json, isNot(contains('Ленина')));
    });
  });

  group('Reading the worker answer', () {
    test('a full answer parses into a verdict, headline and tips', () {
      final advice =
          SpendingAdvice.tryFromJson(Map<String, dynamic>.from(_workerAnswer));

      expect(advice, isNotNull);
      expect(advice!.verdict, SpendingVerdict.concerning);
      expect(advice.tips, hasLength(2));
      expect(advice.tips.first.category, ExpenseCategory.food);
      expect(advice.tips.first.severity, TipSeverity.warning);
      expect(advice.tips.last.category, ExpenseCategory.transport);
      expect(advice.tips.last.severity, TipSeverity.info);
    });

    test('a headline with nothing behind it is refused, not shown empty', () {
      final advice = SpendingAdvice.tryFromJson({
        'verdict': 'neutral',
        'headline': 'Всё в порядке',
        'tips': [],
      });

      expect(advice, isNull);
    });

    test('no headline at all is refused', () {
      final advice = SpendingAdvice.tryFromJson({
        'verdict': 'neutral',
        'tips': [
          {'title': 'x', 'detail': 'y'},
        ],
      });

      expect(advice, isNull);
    });

    test('a tip missing a title or detail is dropped, not shown blank', () {
      final advice = SpendingAdvice.tryFromJson({
        'headline': 'Есть о чём подумать',
        'tips': [
          {'title': '', 'detail': 'что-то'},
          {'title': 'Заголовок', 'detail': ''},
          {'title': 'Заголовок', 'detail': 'Детали'},
        ],
      });

      expect(advice, isNotNull);
      expect(advice!.tips, hasLength(1));
      expect(advice.tips.single.title, 'Заголовок');
    });

    test('an unknown category or severity falls back rather than crashing', () {
      final advice = SpendingAdvice.tryFromJson({
        'verdict': 'ecstatic',
        'headline': 'Норм',
        'tips': [
          {
            'category': 'crypto',
            'severity': 'urgent',
            'title': 'x',
            'detail': 'y'
          },
          {
            'category': 'general',
            'severity': 'info',
            'title': 'a',
            'detail': 'b'
          },
        ],
      });

      expect(advice!.verdict, SpendingVerdict.neutral);
      // An unrecognised key falls back the same way a scanned transaction's
      // category does -- to "other" -- rather than becoming an exception.
      expect(advice.tips.first.category, ExpenseCategory.other);
      expect(advice.tips.first.severity, TipSeverity.info);
      expect(advice.tips.last.category, isNull);
    });

    test('round-tripping through toJson keeps the same advice', () {
      final original =
          SpendingAdvice.tryFromJson(Map<String, dynamic>.from(_workerAnswer))!;
      final roundTripped = SpendingAdvice.tryFromJson(original.toJson());

      expect(roundTripped!.verdict, original.verdict);
      expect(roundTripped.headline, original.headline);
      expect(roundTripped.tips.length, original.tips.length);
    });
  });

  group('Talking to the worker', () {
    test('the request goes to /advice with the token and the snapshot',
        () async {
      late http.Request seen;
      final service = _service((request) async {
        seen = request;
        return http.Response(jsonEncode(_workerAnswer), 200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      });

      final snapshot = buildSpendingSnapshot(
        [_expense(amount: 1000, date: DateTime(2026, 9, 5))],
        currency: AppCurrency.rub,
        limits: const {},
        now: DateTime(2026, 9, 15),
      );

      final advice = await service.advise(snapshot);

      expect(seen.url.toString(), '$_endpoint/advice');
      expect(seen.headers['Authorization'], 'Bearer test-token');
      final body = jsonDecode(seen.body) as Map<String, dynamic>;
      expect(body['currency'], 'rub');
      expect(advice.headline, _workerAnswer['headline']);
    });

    test('the worker’s own wording is what the user is shown', () async {
      final service = _service((_) async => http.Response(
            jsonEncode({'error': 'Пока маловато записей для разбора'}),
            422,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ));

      final snapshot = buildSpendingSnapshot(
        [_expense(amount: 1000, date: DateTime(2026, 9, 5))],
        currency: AppCurrency.rub,
        limits: const {},
        now: DateTime(2026, 9, 15),
      );

      expect(
        () => service.advise(snapshot),
        throwsA(isA<AdviceException>().having(
            (e) => e.message, 'message', 'Пока маловато записей для разбора')),
      );
    });

    test('a wordless failure still says something in Russian', () async {
      final service = _service((_) async => http.Response('<html>', 500));
      final snapshot = buildSpendingSnapshot(
        [_expense(amount: 1000, date: DateTime(2026, 9, 5))],
        currency: AppCurrency.rub,
        limits: const {},
        now: DateTime(2026, 9, 15),
      );

      expect(
        () => service.advise(snapshot),
        throwsA(isA<AdviceException>()
            .having((e) => e.message, 'message', contains('500'))),
      );
    });

    test('without a signed-in user nothing is uploaded', () async {
      var called = false;
      final service = _service(
        (_) async {
          called = true;
          return http.Response('{}', 200);
        },
        token: null,
      );
      final snapshot = buildSpendingSnapshot(
        [_expense(amount: 1000, date: DateTime(2026, 9, 5))],
        currency: AppCurrency.rub,
        limits: const {},
        now: DateTime(2026, 9, 15),
      );

      await expectLater(
        service.advise(snapshot),
        throwsA(isA<AdviceException>()),
      );
      expect(called, isFalse);
    });

    test('an unconfigured worker refuses before any request', () async {
      final service = AdviceService(
        endpoint: '',
        token: () async => 'token',
        client: MockClient((_) async => http.Response('{}', 200)),
      );
      final snapshot = buildSpendingSnapshot(
        [_expense(amount: 1000, date: DateTime(2026, 9, 5))],
        currency: AppCurrency.rub,
        limits: const {},
        now: DateTime(2026, 9, 15),
      );

      expect(
        () => service.advise(snapshot),
        throwsA(isA<AdviceException>()),
      );
    });
  });

  group('The tab button', () {
    testWidgets('reads its label and reports a tap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(Brightness.light),
          home: Scaffold(
            body: AdviceTabButton(onTap: () => tapped = true),
          ),
        ),
      );

      expect(find.text('Советы по расходам'), findsOneWidget);

      await tester.tap(find.byType(AdviceTabButton));
      expect(tapped, isTrue);
    });

    testWidgets(
        'sitting full-width under the summary card, in a plain Column, '
        'does not blow up layout', (tester) async {
      // Regression guard for the shape home_screen.dart actually uses: a
      // Column with SummaryCard, then this button, both full width. The
      // earlier design sat the two side by side in a stretched Row, which
      // (as a non-Expanded Column child, given unbounded height) crashed
      // the whole screen in production -- moving to a stacked, full-width
      // layout for both removes the shared-height trick that bug came from
      // rather than working around it again.
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(Brightness.light),
          home: Scaffold(
            body: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const SummaryCard(
                        todayExpenseTotal: 100,
                        todayIncomeTotal: 0,
                        monthExpenseTotal: 500,
                        monthIncomeTotal: 1000,
                        allExpenseTotal: 5000,
                        allIncomeTotal: 8000,
                        currency: AppCurrency.rub,
                      ),
                      const SizedBox(height: 10),
                      AdviceTabButton(onTap: () {}),
                    ],
                  ),
                ),
                const Expanded(child: SizedBox.shrink()),
              ],
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(SummaryCard), findsOneWidget);
      expect(find.byType(AdviceTabButton), findsOneWidget);
    });

    testWidgets('survives the dark theme', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(Brightness.dark),
          home: Scaffold(
            body: AdviceTabButton(onTap: () {}),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });
}
