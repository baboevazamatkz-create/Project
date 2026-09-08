import 'package:flutter/material.dart';

enum ExpenseCategory {
  food,
  transport,
  housing,
  entertainment,
  health,
  shopping,
  other,
}

extension ExpenseCategoryX on ExpenseCategory {
  String get label {
    switch (this) {
      case ExpenseCategory.food:
        return 'Еда';
      case ExpenseCategory.transport:
        return 'Транспорт';
      case ExpenseCategory.housing:
        return 'Жильё';
      case ExpenseCategory.entertainment:
        return 'Развлечения';
      case ExpenseCategory.health:
        return 'Здоровье';
      case ExpenseCategory.shopping:
        return 'Покупки';
      case ExpenseCategory.other:
        return 'Другое';
    }
  }

  IconData get icon {
    switch (this) {
      case ExpenseCategory.food:
        return Icons.restaurant_rounded;
      case ExpenseCategory.transport:
        return Icons.directions_bus_rounded;
      case ExpenseCategory.housing:
        return Icons.home_rounded;
      case ExpenseCategory.entertainment:
        return Icons.celebration_rounded;
      case ExpenseCategory.health:
        return Icons.favorite_rounded;
      case ExpenseCategory.shopping:
        return Icons.shopping_bag_rounded;
      case ExpenseCategory.other:
        return Icons.category_rounded;
    }
  }

  String get storageKey => name;

  static ExpenseCategory fromStorageKey(String key) {
    return ExpenseCategory.values.firstWhere(
      (c) => c.name == key,
      orElse: () => ExpenseCategory.other,
    );
  }
}
