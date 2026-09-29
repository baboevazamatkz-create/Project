import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:expense_tracker/data/speech_recognizer.dart';
import 'package:expense_tracker/data/voice_service.dart';
import 'package:expense_tracker/models/currency.dart';
import 'package:expense_tracker/models/expense.dart';
import 'package:expense_tracker/models/expense_category.dart';
import 'package:expense_tracker/models/transaction_type.dart';
import 'package:expense_tracker/models/voice_answer.dart';
import 'package:expense_tracker/models/voice_intent.dart';
import 'package:expense_tracker/screens/voice_assistant_screen.dart';
import 'package:expense_tracker/theme.dart';
import 'package:expense_tracker/widgets/add_expense_sheet.dart';

const _endpoint = 'https://scan.example.test';

VoiceService _service(
  Future<http.Response> Function(http.Request request) handler, {
  String? token = 'test-token',
}) =>
    VoiceService(
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

/// A recognizer a test drives by hand: no microphone, no platform channel,
/// just the same three calls VoiceAssistantScreen makes against the real
/// one.
class FakeSpeechRecognizer implements SpeechRecognizer {
  bool available;
  bool _listening = false;
  void Function(String text, bool isFinal)? _onResult;
  VoidCallback? _onDone;

  FakeSpeechRecognizer({this.available = true});

  @override
  Future<bool> initialize() async => available;

  @override
  Future<void> listen({
    required void Function(String text, bool isFinal) onResult,
    required void Function() onDone,
  }) async {
    _listening = true;
    _onResult = onResult;
    _onDone = onDone;
  }

  @override
  Future<void> stop() async => _listening = false;

  @override
  Future<void> cancel() async => _listening = false;

  @override
  bool get isListening => _listening;

  /// Simulates the engine reporting words heard so far.
  void emit(String text) => _onResult?.call(text, false);

  /// Simulates the engine deciding the phrase is done -- silence, a pause
  /// timeout -- the same call a real session makes on its own.
  void finish() {
    _listening = false;
    _onDone?.call();
  }
}

void main() {
  setUpAll(() => initializeDateFormatting('ru'));

  group('Reading what the worker heard', () {
    test('an add command parses amount, category and date', () {
      final intent = VoiceIntent.fromJson({
        'intent': 'add',
        'type': 'expense',
        'amount': 500,
        'category': 'transport',
        'date': '2026-09-28',
        'note': 'такси',
      });

      expect(intent, isA<VoiceAddIntent>());
      final add = intent as VoiceAddIntent;
      expect(add.type, VoiceRecordType.expense);
      expect(add.amount, 500);
      expect(add.category, ExpenseCategory.transport);
      expect(add.date, DateTime(2026, 9, 28));
      expect(add.note, 'такси');
    });

    test('income carries no category even if the worker sent one', () {
      final intent = VoiceIntent.fromJson({
        'intent': 'add',
        'type': 'income',
        'amount': 80000,
        'category': 'other',
        'date': '2026-09-28',
      });

      final add = intent as VoiceAddIntent;
      expect(add.type, VoiceRecordType.income);
      expect(add.category, isNull);
    });

    test('a zero or missing amount is unclear, not a zero record', () {
      expect(
        VoiceIntent.fromJson({'intent': 'add', 'type': 'expense'}),
        isA<VoiceUnclearIntent>(),
      );
      expect(
        VoiceIntent.fromJson({'intent': 'add', 'type': 'expense', 'amount': 0}),
        isA<VoiceUnclearIntent>(),
      );
    });

    test('a bad date falls back rather than crashing', () {
      final add = VoiceIntent.fromJson({
        'intent': 'add',
        'type': 'expense',
        'amount': 100,
        'date': 'nonsense',
      }) as VoiceAddIntent;
      // Falls back to "now" -- just assert it parsed at all.
      expect(add.amount, 100);
    });

    test('a query parses type, category and period', () {
      final intent = VoiceIntent.fromJson({
        'intent': 'query',
        'type': 'expense',
        'category': 'food',
        'period': 'yesterday',
      });

      expect(intent, isA<VoiceQueryIntent>());
      final query = intent as VoiceQueryIntent;
      expect(query.type, VoiceQueryType.expense);
      expect(query.category, ExpenseCategory.food);
      expect(query.period, VoiceQueryPeriod.yesterday);
    });

    test('"all" and an unset category both mean every category', () {
      final all = VoiceIntent.fromJson({'intent': 'query', 'category': 'all'})
          as VoiceQueryIntent;
      final unset =
          VoiceIntent.fromJson({'intent': 'query'}) as VoiceQueryIntent;
      expect(all.category, isNull);
      expect(unset.category, isNull);
      // No period named falls back to this_month.
      expect(unset.period, VoiceQueryPeriod.thisMonth);
    });

    test('net is a query-only type', () {
      final query = VoiceIntent.fromJson({'intent': 'query', 'type': 'net'})
          as VoiceQueryIntent;
      expect(query.type, VoiceQueryType.net);
    });

    test('an unrecognised intent, not just "unclear", still becomes it', () {
      expect(
        VoiceIntent.fromJson({'intent': 'delete_everything'}),
        isA<VoiceUnclearIntent>(),
      );
      expect(VoiceIntent.fromJson({}), isA<VoiceUnclearIntent>());
    });
  });

  group('Answering a question locally', () {
    final expenses = [
      _expense(amount: 500, date: DateTime(2026, 9, 28)), // today, food
      _expense(
          amount: 300,
          date: DateTime(2026, 9, 27),
          category: ExpenseCategory.transport), // yesterday, transport
      _expense(amount: 1200, date: DateTime(2026, 9, 15)), // this month, food
      _expense(amount: 900, date: DateTime(2026, 8, 20)), // last month, food
      _expense(
          amount: 50000,
          date: DateTime(2026, 9, 1),
          type: TransactionType.income),
    ];
    final now = DateTime(2026, 9, 28);

    test('a category question sums only that category, that period', () {
      final answer = answerVoiceQuery(
        expenses,
        const VoiceQueryIntent(
          type: VoiceQueryType.expense,
          category: ExpenseCategory.food,
          period: VoiceQueryPeriod.thisMonth,
        ),
        currency: AppCurrency.rub,
        now: now,
      );

      // Today's 500 + the mid-month 1200, not the transport one or last
      // month's.
      expect(answer.amount, 1700);
      expect(answer.sentence, contains('еду'));
    });

    test('with no category named, every category counts', () {
      final answer = answerVoiceQuery(
        expenses,
        const VoiceQueryIntent(
          type: VoiceQueryType.expense,
          category: null,
          period: VoiceQueryPeriod.thisMonth,
        ),
        currency: AppCurrency.rub,
        now: now,
      );

      expect(answer.amount, 2000); // 500 + 300 + 1200
    });

    test('yesterday means exactly one day, not "recently"', () {
      final answer = answerVoiceQuery(
        expenses,
        const VoiceQueryIntent(
          type: VoiceQueryType.expense,
          category: null,
          period: VoiceQueryPeriod.yesterday,
        ),
        currency: AppCurrency.rub,
        now: now,
      );

      expect(answer.amount, 300);
    });

    test('income ignores a category filter -- income has none', () {
      final answer = answerVoiceQuery(
        expenses,
        const VoiceQueryIntent(
          type: VoiceQueryType.income,
          category: ExpenseCategory.food,
          period: VoiceQueryPeriod.thisMonth,
        ),
        currency: AppCurrency.rub,
        now: now,
      );

      expect(answer.amount, 50000);
    });

    test('net is income minus expense for the period', () {
      final answer = answerVoiceQuery(
        expenses,
        const VoiceQueryIntent(
          type: VoiceQueryType.net,
          category: null,
          period: VoiceQueryPeriod.thisMonth,
        ),
        currency: AppCurrency.rub,
        now: now,
      );

      expect(answer.amount, 50000 - 2000);
      expect(answer.sentence, contains('превысил'));
    });

    test('a net loss reads as an overspend, not a negative number', () {
      final answer = answerVoiceQuery(
        [
          _expense(amount: 5000, date: DateTime(2026, 9, 28)),
        ],
        const VoiceQueryIntent(
          type: VoiceQueryType.net,
          category: null,
          period: VoiceQueryPeriod.thisMonth,
        ),
        currency: AppCurrency.rub,
        now: now,
      );

      expect(answer.amount, lessThan(0));
      expect(answer.sentence, contains('превысили'));
      expect(answer.sentence, isNot(contains('-')));
    });

    test('a quiet period answers zero, not an error', () {
      final answer = answerVoiceQuery(
        expenses,
        const VoiceQueryIntent(
          type: VoiceQueryType.expense,
          category: ExpenseCategory.health,
          period: VoiceQueryPeriod.today,
        ),
        currency: AppCurrency.rub,
        now: now,
      );

      expect(answer.amount, 0);
    });
  });

  group('Talking to the worker', () {
    test('the request goes to /voice with the token and the phrase', () async {
      late http.Request seen;
      final service = _service((request) async {
        seen = request;
        return http.Response(
          jsonEncode({'intent': 'unclear'}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      await service.parse('сколько я потратил на еду',
          today: DateTime(2026, 9, 28));

      expect(seen.url.toString(), '$_endpoint/voice');
      expect(seen.headers['Authorization'], 'Bearer test-token');
      final body = jsonDecode(seen.body) as Map<String, dynamic>;
      expect(body['text'], 'сколько я потратил на еду');
      expect(body['today'], '2026-09-28');
    });

    test('an empty phrase never reaches the network', () async {
      var called = false;
      final service = _service((_) async {
        called = true;
        return http.Response('{}', 200);
      });

      await expectLater(
        service.parse('   '),
        throwsA(isA<VoiceException>()),
      );
      expect(called, isFalse);
    });

    test('the worker’s own wording is what the user is shown', () async {
      final service = _service((_) async => http.Response(
            jsonEncode({'error': 'На сегодня разборов больше нет'}),
            429,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ));

      expect(
        () => service.parse('добавь расход 500'),
        throwsA(isA<VoiceException>().having(
            (e) => e.message, 'message', 'На сегодня разборов больше нет')),
      );
    });

    test('an unconfigured assistant refuses before any request', () async {
      final service = VoiceService(
        endpoint: '',
        token: () async => 'token',
        client: MockClient((_) async => http.Response('{}', 200)),
      );

      expect(
        () => service.parse('добавь расход 500'),
        throwsA(isA<VoiceException>()),
      );
    });
  });

  group('The assistant screen', () {
    Future<VoiceAssistantScreen> pumpScreenAndGetDraft(
      WidgetTester tester, {
      required FakeSpeechRecognizer recognizer,
      required VoiceService service,
      required void Function(Expense? draft) onResult,
    }) async {
      final screen = VoiceAssistantScreen(
        currency: AppCurrency.rub,
        expenses: const [],
        recognizer: recognizer,
        service: service,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(Brightness.light),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    final draft = await Navigator.of(context).push<Expense>(
                        MaterialPageRoute(builder: (_) => screen));
                    onResult(draft);
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      // Not pumpAndSettle: by the time the page transition finishes, the
      // screen is already in its listening stage, and the pulse animation
      // that drives repeats indefinitely for as long as that stage lasts
      // -- exactly like the indeterminate spinners elsewhere in this app,
      // settling on it would simply never return. Bounded pumps instead:
      // one to start the push, enough time for the transition, then a
      // couple of empty pumps to flush the two awaits _start() makes
      // (initialize(), then listen()) before it reaches that stage.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      await tester.pump();
      return screen;
    }

    testWidgets('an add command comes back as a draft ready to confirm',
        (tester) async {
      final recognizer = FakeSpeechRecognizer();
      final service = _service((_) async => http.Response(
            jsonEncode({
              'intent': 'add',
              'type': 'expense',
              'amount': 500,
              'category': 'transport',
              'date': '2026-09-28',
              'note': 'такси',
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ));
      Expense? result;

      await pumpScreenAndGetDraft(
        tester,
        recognizer: recognizer,
        service: service,
        onResult: (draft) => result = draft,
      );

      expect(find.text('Говорите…'), findsOneWidget);
      recognizer.emit('потратил 500 на такси');
      await tester.pump();
      expect(find.text('потратил 500 на такси'), findsOneWidget);

      recognizer.finish();
      // Not pumpAndSettle here either: the processing stage shows its own
      // indeterminate spinner while awaiting the (mocked) network call, for
      // the same reason bounded pumps stood in for it when opening the
      // screen above.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));

      expect(result, isNotNull);
      expect(result!.amount, 500);
      expect(result!.category, ExpenseCategory.transport);
      expect(result!.type, TransactionType.expense);
    });

    testWidgets('a question is answered on screen, nothing handed back',
        (tester) async {
      final recognizer = FakeSpeechRecognizer();
      final service = _service((_) async => http.Response(
            jsonEncode({
              'intent': 'query',
              'type': 'expense',
              'category': 'food',
              'period': 'yesterday',
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ));
      Expense? result;
      var resultDelivered = false;

      await pumpScreenAndGetDraft(
        tester,
        recognizer: recognizer,
        service: service,
        onResult: (draft) {
          result = draft;
          resultDelivered = true;
        },
      );

      recognizer.emit('сколько я потратил на еду вчера');
      recognizer.finish();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));

      expect(resultDelivered, isFalse); // still on the answer screen
      expect(result, isNull);
      expect(find.textContaining('еду'), findsOneWidget);
      expect(find.text('Готово'), findsOneWidget);

      await tester.tap(find.text('Готово'));
      await tester.pumpAndSettle();
      expect(resultDelivered, isTrue);
      expect(result, isNull);
    });

    testWidgets('no microphone permission shows a message, not a crash',
        (tester) async {
      final recognizer = FakeSpeechRecognizer(available: false);
      final service = _service((_) async => http.Response('{}', 200));

      await pumpScreenAndGetDraft(
        tester,
        recognizer: recognizer,
        service: service,
        onResult: (_) {},
      );

      expect(tester.takeException(), isNull);
      expect(find.textContaining('микрофон'), findsOneWidget);
    });
  });

  group('AddExpenseSheet as a draft', () {
    testWidgets('reads as a new record, not an edit, and gets a fresh id',
        (tester) async {
      Expense? submitted;
      final draft = Expense(
        id: 'should-not-survive',
        amount: 500,
        date: DateTime(2026, 9, 28),
        category: ExpenseCategory.transport,
        note: 'такси',
        type: TransactionType.expense,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(Brightness.light),
          home: Scaffold(
            body: AddExpenseSheet(
              type: TransactionType.expense,
              currency: AppCurrency.rub,
              existing: draft,
              isDraft: true,
              onSubmit: (e) => submitted = e,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('НОВЫЙ РАСХОД'), findsOneWidget);
      expect(find.text('Добавить'), findsOneWidget);
      expect(find.text('Изменить'), findsNothing);

      await tester.tap(find.text('Добавить'));
      await tester.pumpAndSettle();

      expect(submitted, isNotNull);
      expect(submitted!.id, isNot('should-not-survive'));
      expect(submitted!.amount, 500);
    });
  });
}
