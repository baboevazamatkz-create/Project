import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:intl/date_symbol_data_local.dart';

import 'package:expense_tracker/data/scan_service.dart';
import 'package:expense_tracker/models/currency.dart';
import 'package:expense_tracker/models/expense.dart';
import 'package:expense_tracker/models/expense_category.dart';
import 'package:expense_tracker/models/scanned_transaction.dart';
import 'package:expense_tracker/models/transaction_type.dart';
import 'package:expense_tracker/theme.dart';
import 'package:expense_tracker/widgets/scan_review_sheet.dart';

const _endpoint = 'https://scan.example.test';

/// The shape worker/src/index.js answers with. Kept here verbatim so a
/// change on either side shows up as a failing test rather than as an
/// empty review sheet on someone's phone.
const _workerAnswer = {
  'document': 'statement',
  'transactions': [
    {
      'type': 'expense',
      'amount': 1234.5,
      'currency': 'rub',
      'date': '2026-09-12',
      'note': 'Магнит',
      'category': 'food',
      'confidence': 0.93,
    },
    {
      'type': 'income',
      'amount': 50000,
      'currency': 'rub',
      'date': '2026-09-10',
      'note': 'Зарплата',
      'category': 'other',
      'confidence': 0.99,
    },
  ],
};

ScanService _service(
  Future<http.Response> Function(http.Request request) handler, {
  String? token = 'test-token',
}) =>
    ScanService(
      endpoint: _endpoint,
      token: () async => token,
      client: MockClient(handler),
    );

Expense _expense({
  required double amount,
  required DateTime date,
  TransactionType type = TransactionType.expense,
}) =>
    Expense(
      id: '${type.name}-$amount-${date.day}',
      amount: amount,
      date: date,
      type: type,
      category: ExpenseCategory.food,
    );

Future<void> _pumpSheet(
  WidgetTester tester, {
  required ScanResult result,
  required Set<int> duplicates,
  required void Function(List<Expense>) onConfirm,
  Brightness brightness = Brightness.light,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(brightness),
      home: Scaffold(
        body: ScanReviewSheet(
          result: result,
          currency: AppCurrency.rub,
          duplicates: duplicates,
          onConfirm: onConfirm,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting('ru'));

  group('Reading the worker answer', () {
    test('a statement becomes one row per operation', () {
      final result = ScanResult.fromJson(
        Map<String, dynamic>.from(_workerAnswer),
        fallbackCurrency: AppCurrency.rub,
      );

      expect(result.document, ScanDocument.statement);
      expect(result.transactions, hasLength(2));
      expect(result.transactions.first.amount, 1234.5);
      expect(result.transactions.first.category, ExpenseCategory.food);
      expect(result.transactions.first.date, DateTime(2026, 9, 12));
      expect(result.transactions.last.type, TransactionType.income);
    });

    test('a row without a usable amount is dropped, not written as zero', () {
      final result = ScanResult.fromJson(
        {
          'document': 'receipt',
          'transactions': [
            {'type': 'expense', 'amount': 0, 'date': '2026-09-12'},
            {'type': 'expense', 'amount': -40, 'date': '2026-09-12'},
            {'type': 'expense', 'date': '2026-09-12'},
            {'type': 'expense', 'amount': 40, 'date': '2026-09-12'},
          ],
        },
        fallbackCurrency: AppCurrency.rub,
      );

      expect(result.transactions, hasLength(1));
      expect(result.transactions.single.amount, 40);
    });

    test(
        'an unknown category falls back to other, an unseen currency to '
        'the budget’s own', () {
      final result = ScanResult.fromJson(
        {
          'document': 'nonsense',
          'transactions': [
            {
              'type': 'sideways',
              'amount': 10,
              'date': 'вчера',
              'category': 'crypto',
            },
          ],
        },
        fallbackCurrency: AppCurrency.kzt,
      );

      final row = result.transactions.single;
      expect(result.document, ScanDocument.other);
      expect(row.category, ExpenseCategory.other);
      expect(row.currency, AppCurrency.kzt);
      expect(row.type, TransactionType.expense);
      // An unparseable date becomes today rather than nothing.
      expect(row.date.day, DateTime.now().day);
    });

    test('a low confidence is what marks a row as worth checking', () {
      final result = ScanResult.fromJson(
        {
          'document': 'receipt',
          'transactions': [
            {
              'type': 'expense',
              'amount': 10,
              'date': '2026-09-12',
              'confidence': 0.4
            },
            {
              'type': 'expense',
              'amount': 11,
              'date': '2026-09-12',
              'confidence': 0.8
            },
          ],
        },
        fallbackCurrency: AppCurrency.rub,
      );

      expect(result.transactions.first.isUncertain, isTrue);
      expect(result.transactions.last.isUncertain, isFalse);
    });
  });

  group('Talking to the worker', () {
    test('the request carries the token, the snapshots and today', () async {
      late http.Request seen;
      final service = _service((request) async {
        seen = request;
        return http.Response(jsonEncode(_workerAnswer), 200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      });

      await service.scan(
        images: [
          ScanImage(bytes: Uint8List.fromList([1, 2, 3]), mime: 'image/jpeg'),
        ],
        currency: AppCurrency.kzt,
        today: DateTime(2026, 9, 13),
      );

      expect(seen.url.toString(), _endpoint);
      expect(seen.headers['Authorization'], 'Bearer test-token');

      final body = jsonDecode(seen.body) as Map<String, dynamic>;
      expect(body['currency'], 'kzt');
      expect(body['today'], '2026-09-13');
      final images = body['images'] as List;
      expect(images, hasLength(1));
      expect((images.single as Map)['mime'], 'image/jpeg');
      expect(base64Decode((images.single as Map)['data'] as String), [1, 2, 3]);
    });

    test('the worker’s own wording is what the user is shown', () async {
      final service = _service((_) async => http.Response(
            jsonEncode({'error': 'На сегодня разборов больше нет'}),
            429,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ));

      expect(
        () => service.scan(
          images: [
            ScanImage(bytes: Uint8List.fromList([1]), mime: 'image/jpeg'),
          ],
          currency: AppCurrency.rub,
        ),
        throwsA(isA<ScanException>().having(
            (e) => e.message, 'message', 'На сегодня разборов больше нет')),
      );
    });

    test('a wordless failure still says something in Russian', () async {
      final service = _service((_) async => http.Response('<html>', 500));

      expect(
        () => service.scan(
          images: [
            ScanImage(bytes: Uint8List.fromList([1]), mime: 'image/jpeg'),
          ],
          currency: AppCurrency.rub,
        ),
        throwsA(isA<ScanException>()
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

      await expectLater(
        service.scan(
          images: [
            ScanImage(bytes: Uint8List.fromList([1]), mime: 'image/jpeg'),
          ],
          currency: AppCurrency.rub,
        ),
        throwsA(isA<ScanException>()),
      );
      expect(called, isFalse);
    });

    test('an unconfigured scanner refuses before any request', () async {
      final service = ScanService(
        endpoint: '',
        token: () async => 'token',
        client: MockClient((_) async => http.Response('{}', 200)),
      );

      expect(
        () => service.scan(
          images: [
            ScanImage(bytes: Uint8List.fromList([1]), mime: 'image/jpeg'),
          ],
          currency: AppCurrency.rub,
        ),
        throwsA(isA<ScanException>()),
      );
    });
  });

  group('Preparing a snapshot', () {
    test('a small photo goes up untouched, with its real type', () {
      final small = Uint8List.fromList(
        img.encodeJpg(img.Image(width: 40, height: 30), quality: 80),
      );
      expect(small.length, lessThan(kScanPassThroughBytes));

      final prepared = prepareScanImage(small);
      expect(prepared.mime, 'image/jpeg');
      expect(prepared.bytes, same(small));
    });

    test('an oversized snapshot is brought down to what a model reads at', () {
      // A PNG this size is well past the pass-through limit, so it takes
      // the decode-and-resize path.
      final large = img.Image(width: 3000, height: 2000);
      for (var x = 0; x < large.width; x += 7) {
        for (var y = 0; y < large.height; y += 5) {
          large.setPixelRgb(x, y, x % 255, y % 255, 120);
        }
      }
      final raw = Uint8List.fromList(img.encodePng(large));
      expect(raw.length, greaterThan(kScanPassThroughBytes));

      final prepared = prepareScanImage(raw);
      final decoded = img.decodeImage(prepared.bytes)!;

      expect(prepared.mime, 'image/jpeg');
      expect(decoded.width, kScanMaxEdge);
      expect(decoded.height, 2000 * kScanMaxEdge ~/ 3000);
      expect(prepared.bytes.length, lessThan(raw.length));
    });

    test('bytes that are not an image at all are passed on, not thrown away',
        () {
      final junk = Uint8List.fromList(List.filled(600 * 1024, 7));
      final prepared = prepareScanImage(junk);
      expect(prepared.bytes, same(junk));
      expect(prepared.mime, 'image/jpeg');
    });
  });

  group('Finding what is already there', () {
    test('same direction, same day and same sum reads as a duplicate', () {
      final scanned = ScanResult.fromJson(
        Map<String, dynamic>.from(_workerAnswer),
        fallbackCurrency: AppCurrency.rub,
      ).transactions;

      final duplicates = findDuplicates(scanned, [
        _expense(amount: 1234.5, date: DateTime(2026, 9, 12, 19, 30)),
      ]);

      expect(duplicates, {0});
    });

    test('a different day, sum or direction is not a duplicate', () {
      final scanned = ScanResult.fromJson(
        Map<String, dynamic>.from(_workerAnswer),
        fallbackCurrency: AppCurrency.rub,
      ).transactions;

      expect(
        findDuplicates(scanned, [
          _expense(amount: 1234.5, date: DateTime(2026, 9, 11)),
          _expense(amount: 1234.0, date: DateTime(2026, 9, 12)),
          _expense(
            amount: 1234.5,
            date: DateTime(2026, 9, 12),
            type: TransactionType.income,
          ),
        ]),
        isEmpty,
      );
    });

    test('the same row twice on one screenshot is caught as well', () {
      final scanned = ScanResult.fromJson(
        {
          'document': 'statement',
          'transactions': [
            {'type': 'expense', 'amount': 90, 'date': '2026-09-12'},
            {'type': 'expense', 'amount': 90, 'date': '2026-09-12'},
          ],
        },
        fallbackCurrency: AppCurrency.rub,
      ).transactions;

      expect(findDuplicates(scanned, const []), {1});
    });
  });

  group('The review sheet', () {
    ScanResult parsed() => ScanResult.fromJson(
          Map<String, dynamic>.from(_workerAnswer),
          fallbackCurrency: AppCurrency.rub,
        );

    testWidgets('every read row is listed and ticked', (tester) async {
      await _pumpSheet(
        tester,
        result: parsed(),
        duplicates: const {},
        onConfirm: (_) {},
      );

      expect(find.text('Магнит'), findsOneWidget);
      expect(find.text('Зарплата'), findsOneWidget);
      expect(find.text('ВЫБРАНО 2 ИЗ 2'), findsOneWidget);
      expect(find.text('Добавить 2 записи'), findsOneWidget);
    });

    testWidgets('a row that looks to be there already is offered unticked',
        (tester) async {
      List<Expense>? confirmed;
      await _pumpSheet(
        tester,
        result: parsed(),
        duplicates: const {0},
        onConfirm: (expenses) => confirmed = expenses,
      );

      expect(find.text('ВЫБРАНО 1 ИЗ 2'), findsOneWidget);
      expect(find.textContaining('похоже, уже есть'), findsOneWidget);

      await tester.tap(find.text('Добавить запись'));
      await tester.pumpAndSettle();

      expect(confirmed, hasLength(1));
      expect(confirmed!.single.amount, 50000);
      expect(confirmed!.single.type, TransactionType.income);
    });

    testWidgets('an unticked row can be taken back', (tester) async {
      List<Expense>? confirmed;
      await _pumpSheet(
        tester,
        result: parsed(),
        duplicates: const {0},
        onConfirm: (expenses) => confirmed = expenses,
      );

      await tester.tap(find.text('Магнит'));
      await tester.pumpAndSettle();
      expect(find.text('ВЫБРАНО 2 ИЗ 2'), findsOneWidget);

      await tester.tap(find.text('Добавить 2 записи'));
      await tester.pumpAndSettle();
      expect(confirmed, hasLength(2));
    });

    testWidgets('a misread direction can be flipped on the row itself',
        (tester) async {
      List<Expense>? confirmed;
      await _pumpSheet(
        tester,
        result: parsed(),
        duplicates: const {},
        onConfirm: (expenses) => confirmed = expenses,
      );

      await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Это доход'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Добавить 2 записи'));
      await tester.pumpAndSettle();

      expect(confirmed!.first.type, TransactionType.income);
      // Income carries no category: the home screen groups it on its own.
      expect(confirmed!.first.category, isNull);
    });

    testWidgets('a row can be corrected in the ordinary editor',
        (tester) async {
      List<Expense>? confirmed;
      await _pumpSheet(
        tester,
        result: parsed(),
        duplicates: const {},
        onConfirm: (expenses) => confirmed = expenses,
      );

      await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Изменить'));
      await tester.pumpAndSettle();

      expect(find.text('ИЗМЕНИТЬ РАСХОД'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, '2000');
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Добавить 2 записи'));
      await tester.pumpAndSettle();
      expect(confirmed!.first.amount, 2000);
    });

    testWidgets('nothing found says so and offers only a way out',
        (tester) async {
      await _pumpSheet(
        tester,
        result: const ScanResult(
          document: ScanDocument.other,
          transactions: [],
        ),
        duplicates: const {},
        onConfirm: (_) => fail('nothing to confirm'),
      );

      expect(find.text('НИЧЕГО НЕ НАЙДЕНО'), findsOneWidget);
      expect(find.text('Закрыть'), findsOneWidget);
      expect(find.textContaining('Добавить'), findsNothing);
    });

    testWidgets('the sheet survives the dark theme', (tester) async {
      await _pumpSheet(
        tester,
        result: parsed(),
        duplicates: const {1},
        onConfirm: (_) {},
        brightness: Brightness.dark,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
