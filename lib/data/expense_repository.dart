import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/expense.dart';

class ExpenseRepository {
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _expensesRef(
          String householdCode) =>
      _firestore
          .collection('households')
          .doc(householdCode)
          .collection('expenses');

  Stream<List<Expense>> watchExpenses(String householdCode) {
    return _expensesRef(householdCode)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Expense.fromJson(doc.data())).toList());
  }

  Future<void> addExpense(String householdCode, Expense expense) {
    return _expensesRef(householdCode).doc(expense.id).set(expense.toJson());
  }

  /// Writes several records at once.
  ///
  /// One batch rather than a loop of writes: the scanner can hand over a
  /// dozen rows off a single screenshot, and a batch is both one round
  /// trip and all-or-nothing -- a half-entered statement would be worse
  /// than none of it.
  Future<void> addExpenses(String householdCode, List<Expense> expenses) {
    if (expenses.isEmpty) return Future.value();
    final batch = _firestore.batch();
    final ref = _expensesRef(householdCode);
    for (final expense in expenses) {
      batch.set(ref.doc(expense.id), expense.toJson());
    }
    return batch.commit();
  }

  Future<void> deleteExpense(String householdCode, String expenseId) {
    return _expensesRef(householdCode).doc(expenseId).delete();
  }
}
