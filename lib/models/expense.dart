import 'package:cloud_firestore/cloud_firestore.dart';

import 'currency.dart';
import 'expense_category.dart';

class Expense {
  final String id;
  final double amount;
  final ExpenseCategory category;
  final String note;
  final DateTime date;
  final AppCurrency currency;

  const Expense({
    required this.id,
    required this.amount,
    required this.category,
    required this.date,
    this.note = '',
    this.currency = AppCurrency.rub,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'amount': amount,
        'category': category.storageKey,
        'note': note,
        'date': Timestamp.fromDate(date),
        'currency': currency.storageKey,
      };

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
        id: json['id'] as String,
        amount: (json['amount'] as num).toDouble(),
        category: ExpenseCategoryX.fromStorageKey(json['category'] as String),
        note: json['note'] as String? ?? '',
        date: (json['date'] as Timestamp).toDate(),
        currency: AppCurrencyX.fromStorageKey(json['currency'] as String?),
      );
}
