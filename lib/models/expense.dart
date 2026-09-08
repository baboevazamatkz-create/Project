import 'expense_category.dart';

class Expense {
  final String id;
  final double amount;
  final ExpenseCategory category;
  final String note;
  final DateTime date;

  const Expense({
    required this.id,
    required this.amount,
    required this.category,
    required this.date,
    this.note = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'amount': amount,
        'category': category.storageKey,
        'note': note,
        'date': date.toIso8601String(),
      };

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
        id: json['id'] as String,
        amount: (json['amount'] as num).toDouble(),
        category: ExpenseCategoryX.fromStorageKey(json['category'] as String),
        note: json['note'] as String? ?? '',
        date: DateTime.parse(json['date'] as String),
      );
}
