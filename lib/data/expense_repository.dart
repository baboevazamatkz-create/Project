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

  Future<void> deleteExpense(String householdCode, String expenseId) {
    return _expensesRef(householdCode).doc(expenseId).delete();
  }
}
