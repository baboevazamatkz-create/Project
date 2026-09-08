import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/currency.dart';

class HouseholdSettingsRepository {
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _doc(String householdCode) =>
      _firestore
          .collection('households')
          .doc(householdCode)
          .collection('settings')
          .doc('meta');

  Stream<AppCurrency> watchCurrency(String householdCode) {
    return _doc(householdCode).snapshots().map((snap) =>
        AppCurrencyX.fromStorageKey(snap.data()?['currency'] as String?));
  }

  Future<void> setCurrency(String householdCode, AppCurrency currency) {
    return _doc(householdCode)
        .set({'currency': currency.storageKey}, SetOptions(merge: true));
  }

  Future<void> clearAllExpenses(String householdCode) async {
    final collection = _firestore
        .collection('households')
        .doc(householdCode)
        .collection('expenses');
    final snapshot = await collection.get();
    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}
