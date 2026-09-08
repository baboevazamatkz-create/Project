import 'package:cloud_firestore/cloud_firestore.dart';

import 'currency.dart';
import 'expense_category.dart';
import 'transaction_type.dart';

class Expense {
  final String id;
  final double amount;
  final ExpenseCategory? category;
  final String note;
  final DateTime date;
  final AppCurrency currency;
  final TransactionType type;

  const Expense({
    required this.id,
    required this.amount,
    required this.date,
    this.category,
    this.note = '',
    this.currency = AppCurrency.rub,
    this.type = TransactionType.expense,
  });

  bool get isIncome => type == TransactionType.income;

  Map<String, dynamic> toJson() => {
        'id': id,
        'amount': amount,
        'category': category?.storageKey,
        'note': note,
        'date': Timestamp.fromDate(date),
        'currency': currency.storageKey,
        'type': type.storageKey,
      };

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
        id: json['id'] as String,
        amount: (json['amount'] as num).toDouble(),
        category: json['category'] != null
            ? ExpenseCategoryX.fromStorageKey(json['category'] as String)
            : null,
        note: json['note'] as String? ?? '',
        date: (json['date'] as Timestamp).toDate(),
        currency: AppCurrencyX.fromStorageKey(json['currency'] as String?),
        type: TransactionTypeX.fromStorageKey(json['type'] as String?),
      );
}
