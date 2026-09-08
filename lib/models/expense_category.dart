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

  Color get color {
    switch (this) {
      case ExpenseCategory.food:
        return const Color(0xFFFF8A5C);
      case ExpenseCategory.transport:
        return const Color(0xFF4C6FFF);
      case ExpenseCategory.housing:
        return const Color(0xFF9B59D9);
      case ExpenseCategory.entertainment:
        return const Color(0xFFEC4899);
      case ExpenseCategory.health:
        return const Color(0xFFEF4444);
      case ExpenseCategory.shopping:
        return const Color(0xFF14B8A6);
      case ExpenseCategory.other:
        return const Color(0xFF8B8FA3);
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
