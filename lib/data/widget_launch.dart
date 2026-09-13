import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/expense_category.dart';
import '../models/transaction_type.dart';

/// What the home-screen widget was asked to add.
@immutable
class WidgetLaunch {
  final TransactionType type;

  /// Set only for an expense: the category the widget's chip was showing.
  final ExpenseCategory? category;

  const WidgetLaunch({required this.type, this.category});
}

/// Reads the tap that started (or resumed) the app from the widget.
///
/// The widget cannot record an expense by itself -- it has no Firestore
/// client and no household code -- so it hands the choice over and the app
/// opens its own sheet. Each tap is delivered once: the native side clears
/// what it handed back, so a resume that follows for any other reason does
/// not reopen the sheet.
class WidgetLaunchChannel {
  static const _channel = MethodChannel('solidus/widget');

  /// Android only; every other platform has no widget and returns null
  /// rather than throwing on a missing channel.
  static Future<WidgetLaunch?> consume() async {
    if (defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      final result =
          await _channel.invokeMapMethod<String, String>('consumeLaunchAction');
      if (result == null) return null;
      final type = result['type'] == 'income'
          ? TransactionType.income
          : TransactionType.expense;
      final key = result['category'];
      return WidgetLaunch(
        type: type,
        category: type == TransactionType.expense && key != null
            ? ExpenseCategoryX.fromStorageKey(key)
            : null,
      );
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}
