import 'package:uuid/uuid.dart';

import 'currency.dart';
import 'expense.dart';
import 'expense_category.dart';
import 'transaction_type.dart';

const _uuid = Uuid();

/// What the snapshot turned out to be. A receipt yields one record, a
/// statement usually several; the sheet uses this only to word its title.
enum ScanDocument { receipt, statement, other }

/// One operation read off a snapshot, before the user has confirmed it.
///
/// Deliberately not an [Expense]: nothing is written until the user says
/// so, and this carries two things an expense has no business holding --
/// how sure the model was, and whether the same record looks to be in the
/// budget already.
class ScannedTransaction {
  final TransactionType type;
  final double amount;
  final AppCurrency currency;
  final DateTime date;
  final String note;
  final ExpenseCategory category;

  /// 0..1, as reported by the model. Anything below [uncertainBelow] is
  /// marked in the list: the amount or the date was hard to read.
  final double confidence;

  static const uncertainBelow = 0.6;

  const ScannedTransaction({
    required this.type,
    required this.amount,
    required this.currency,
    required this.date,
    required this.note,
    required this.category,
    this.confidence = 1,
  });

  bool get isUncertain => confidence < uncertainBelow;

  ScannedTransaction copyWith({
    TransactionType? type,
    double? amount,
    AppCurrency? currency,
    DateTime? date,
    String? note,
    ExpenseCategory? category,
  }) =>
      ScannedTransaction(
        type: type ?? this.type,
        amount: amount ?? this.amount,
        currency: currency ?? this.currency,
        date: date ?? this.date,
        note: note ?? this.note,
        category: category ?? this.category,
        confidence: confidence,
      );

  /// The worker validates and clamps before answering, so anything that
  /// arrives here is already within range; this still refuses a record
  /// without a usable amount rather than writing a zero into the budget.
  static ScannedTransaction? tryFromJson(
    Map<String, dynamic> json, {
    required AppCurrency fallbackCurrency,
  }) {
    final amount = (json['amount'] as num?)?.toDouble();
    if (amount == null || !amount.isFinite || amount <= 0) return null;

    final rawDate = json['date'];
    final date = rawDate is String ? DateTime.tryParse(rawDate) : null;

    return ScannedTransaction(
      type: TransactionTypeX.fromStorageKey(json['type'] as String?),
      amount: amount,
      currency: json['currency'] == null
          ? fallbackCurrency
          : AppCurrencyX.fromStorageKey(json['currency'] as String?),
      date: date ?? DateTime.now(),
      note: (json['note'] as String? ?? '').trim(),
      category: json['category'] == null
          ? ExpenseCategory.other
          : ExpenseCategoryX.fromStorageKey(json['category'] as String),
      confidence: ((json['confidence'] as num?)?.toDouble() ?? 1).clamp(0, 1),
    );
  }

  /// The record as it will be stored. The budget's own currency wins: a
  /// budget holds one currency, and the toggle on the home screen is the
  /// place where anything else is shown.
  Expense toExpense({required AppCurrency householdCurrency}) => Expense(
        id: _uuid.v4(),
        amount: amount,
        date: date,
        category: type == TransactionType.income ? null : category,
        note: note,
        currency: householdCurrency,
        type: type,
      );
}

class ScanResult {
  final ScanDocument document;
  final List<ScannedTransaction> transactions;

  const ScanResult({required this.document, required this.transactions});

  static const empty =
      ScanResult(document: ScanDocument.other, transactions: []);

  factory ScanResult.fromJson(
    Map<String, dynamic> json, {
    required AppCurrency fallbackCurrency,
  }) {
    final raw = json['transactions'];
    final transactions = <ScannedTransaction>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is! Map<String, dynamic>) continue;
        final parsed = ScannedTransaction.tryFromJson(
          item,
          fallbackCurrency: fallbackCurrency,
        );
        if (parsed != null) transactions.add(parsed);
      }
    }
    return ScanResult(
      document: ScanDocument.values.firstWhere(
        (d) => d.name == json['document'],
        orElse: () => ScanDocument.other,
      ),
      transactions: transactions,
    );
  }
}

/// Marks the records that look to be in the budget already.
///
/// Same direction, same day and a sum within a hundredth: a repeated
/// scan of the same receipt, or a screenshot overlapping the previous
/// one. These are still offered, just unticked, because two identical
/// coffees on one day are also a real thing.
Set<int> findDuplicates(
  List<ScannedTransaction> scanned,
  List<Expense> existing,
) {
  final seen = <String>{};
  for (final expense in existing) {
    seen.add(_dedupeKey(
      expense.type,
      expense.amount,
      expense.date,
    ));
  }
  final duplicates = <int>{};
  for (var i = 0; i < scanned.length; i++) {
    final item = scanned[i];
    final key = _dedupeKey(item.type, item.amount, item.date);
    if (!seen.add(key)) duplicates.add(i);
  }
  return duplicates;
}

String _dedupeKey(TransactionType type, double amount, DateTime date) =>
    '${type.storageKey}|${amount.toStringAsFixed(2)}'
    '|${date.year}-${date.month}-${date.day}';
