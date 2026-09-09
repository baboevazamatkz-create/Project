import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/expense_category.dart';

class BudgetRepository {
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _doc(String householdCode) =>
      _firestore
          .collection('households')
          .doc(householdCode)
          .collection('settings')
          .doc('budgets');

  Stream<Map<String, double>> watchBudgets(String householdCode) {
    return _doc(householdCode).snapshots().map((snapshot) {
      final data = snapshot.data() ?? {};
      return data.map((key, value) => MapEntry(key, (value as num).toDouble()));
    });
  }

  static double? budgetFor(
      Map<String, double> budgets, ExpenseCategory category) {
    return budgets[category.storageKey];
  }

  Future<void> setBudget(
    String householdCode,
    ExpenseCategory category,
    double? amount,
  ) {
    final key = category.storageKey;
    if (amount == null || amount <= 0) {
      return _doc(householdCode)
          .set({key: FieldValue.delete()}, SetOptions(merge: true));
    }
    return _doc(householdCode).set({key: amount}, SetOptions(merge: true));
  }
}
