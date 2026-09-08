import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/currency.dart';
import '../models/expense_category.dart';

class BudgetRepository {
  final _firestore = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _doc(String householdCode) =>
      _firestore
          .collection('households')
          .doc(householdCode)
          .collection('settings')
          .doc('budgets');

  String _key(ExpenseCategory category, AppCurrency currency) =>
      '${category.storageKey}_${currency.storageKey}';

  Stream<Map<String, double>> watchBudgets(String householdCode) {
    return _doc(householdCode).snapshots().map((snapshot) {
      final data = snapshot.data() ?? {};
      return data.map((key, value) => MapEntry(key, (value as num).toDouble()));
    });
  }

  double? budgetFor(
    Map<String, double> budgets,
    ExpenseCategory category,
    AppCurrency currency,
  ) {
    return budgets[_key(category, currency)];
  }

  Future<void> setBudget(
    String householdCode,
    ExpenseCategory category,
    AppCurrency currency,
    double? amount,
  ) {
    final key = _key(category, currency);
    if (amount == null || amount <= 0) {
      return _doc(householdCode)
          .set({key: FieldValue.delete()}, SetOptions(merge: true));
    }
    return _doc(householdCode).set({key: amount}, SetOptions(merge: true));
  }
}
