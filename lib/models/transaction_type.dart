enum TransactionType { expense, income }

extension TransactionTypeX on TransactionType {
  String get storageKey => name;

  static TransactionType fromStorageKey(String? key) {
    return TransactionType.values.firstWhere(
      (t) => t.name == key,
      orElse: () => TransactionType.expense,
    );
  }
}
