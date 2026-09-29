import 'expense_category.dart';

/// What a direction means depends on which half of [VoiceIntent] it is
/// attached to -- see [VoiceAddIntent] and [VoiceQueryIntent].
enum VoiceRecordType { expense, income }

/// [net] only makes sense for a question: "how much am I up this month"
/// is income minus expense, not a direction a single record can carry.
enum VoiceQueryType { expense, income, net }

/// The stretch of time a question is asked about. A closed set rather than
/// free-form dates -- see the note on [VoiceQueryIntent.period].
enum VoiceQueryPeriod { today, yesterday, thisWeek, thisMonth, lastMonth, all }

/// What a spoken command turned out to mean, once the worker has read it.
///
/// A closed hierarchy of exactly three shapes rather than one class with
/// optional fields everywhere: matching on it with `switch` is what makes
/// the screen's three outcomes (show a record to confirm, show an answer,
/// say "didn't catch that") impossible to leave a case out of.
sealed class VoiceIntent {
  const VoiceIntent();

  /// Never returns null: an unrecognised or malformed answer becomes
  /// [VoiceUnclearIntent] rather than nothing at all, the same way the
  /// worker itself falls back to `intent: "unclear"` rather than refusing
  /// to answer.
  static VoiceIntent fromJson(Map<String, dynamic> json) {
    switch (json['intent']) {
      case 'add':
        return _addFromJson(json) ?? const VoiceUnclearIntent();
      case 'query':
        return _queryFromJson(json);
      default:
        return const VoiceUnclearIntent();
    }
  }

  static VoiceAddIntent? _addFromJson(Map<String, dynamic> json) {
    final amount = (json['amount'] as num?)?.toDouble();
    if (amount == null || amount <= 0) return null;

    final type = json['type'] == 'income'
        ? VoiceRecordType.income
        : VoiceRecordType.expense;
    final categoryKey = json['category'] as String?;

    return VoiceAddIntent(
      type: type,
      amount: amount,
      category: type == VoiceRecordType.expense
          ? (categoryKey == null
              ? ExpenseCategory.other
              : ExpenseCategoryX.fromStorageKey(categoryKey))
          : null,
      date: _parseDate(json['date'] as String?) ?? DateTime.now(),
      note: (json['note'] as String? ?? '').trim(),
    );
  }

  static VoiceQueryIntent _queryFromJson(Map<String, dynamic> json) {
    final categoryKey = json['category'] as String?;
    return VoiceQueryIntent(
      type: switch (json['type']) {
        'income' => VoiceQueryType.income,
        'net' => VoiceQueryType.net,
        _ => VoiceQueryType.expense,
      },
      category: categoryKey == null || categoryKey == 'all'
          ? null
          : ExpenseCategoryX.fromStorageKey(categoryKey),
      period: switch (json['period']) {
        'today' => VoiceQueryPeriod.today,
        'yesterday' => VoiceQueryPeriod.yesterday,
        'this_week' => VoiceQueryPeriod.thisWeek,
        'last_month' => VoiceQueryPeriod.lastMonth,
        'all' => VoiceQueryPeriod.all,
        _ => VoiceQueryPeriod.thisMonth,
      },
    );
  }

  static DateTime? _parseDate(String? raw) {
    if (raw == null) return null;
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(raw);
    if (match == null) return null;
    return DateTime(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
  }
}

/// "Add 500 for a taxi": a record ready to show for confirmation, the same
/// way a scanned receipt is -- nothing heard by a microphone is written
/// straight to the budget without being seen first.
class VoiceAddIntent extends VoiceIntent {
  final VoiceRecordType type;
  final double amount;

  /// Set for an expense, null for income -- income carries no category
  /// anywhere else in this app either.
  final ExpenseCategory? category;
  final DateTime date;
  final String note;

  const VoiceAddIntent({
    required this.type,
    required this.amount,
    required this.category,
    required this.date,
    required this.note,
  });
}

/// "How much did I spend on groceries yesterday": answered entirely on the
/// device from records already loaded -- see answerVoiceQuery in
/// voice_answer.dart. The worker only ever sees the question, never a
/// figure.
class VoiceQueryIntent extends VoiceIntent {
  final VoiceQueryType type;

  /// Null means every category at once.
  final ExpenseCategory? category;
  final VoiceQueryPeriod period;

  const VoiceQueryIntent({
    required this.type,
    required this.category,
    required this.period,
  });
}

/// The phrase wasn't a record to add or a question this app can answer.
class VoiceUnclearIntent extends VoiceIntent {
  const VoiceUnclearIntent();
}
