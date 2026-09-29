import 'currency.dart';
import 'expense.dart';
import 'expense_category.dart';
import 'voice_intent.dart';

/// What answering a [VoiceQueryIntent] locally comes to: the figure itself,
/// for anything that wants it as a number, and a sentence ready to show or
/// speak.
class VoiceAnswer {
  final double amount;
  final String sentence;

  const VoiceAnswer({required this.amount, required this.sentence});
}

/// Category names read fine after "на" in the nominative except "еда" --
/// "на еда" is not a sentence a person would say. Every other category's
/// accusative matches its label, so only food needs its own entry.
String _accusative(ExpenseCategory category) {
  if (category == ExpenseCategory.food) return 'еду';
  return category.label.toLowerCase();
}

const Map<VoiceQueryPeriod, String> _periodPhrase = {
  VoiceQueryPeriod.today: 'сегодня',
  VoiceQueryPeriod.yesterday: 'вчера',
  VoiceQueryPeriod.thisWeek: 'за эту неделю',
  VoiceQueryPeriod.thisMonth: 'за этот месяц',
  VoiceQueryPeriod.lastMonth: 'за прошлый месяц',
  VoiceQueryPeriod.all: 'за всё время',
};

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

/// Whether [date] (already stripped to a day) falls inside [period],
/// measured against [today] (also a day, not a moment).
bool _inPeriod(DateTime date, VoiceQueryPeriod period, DateTime today) {
  switch (period) {
    case VoiceQueryPeriod.today:
      return date == today;
    case VoiceQueryPeriod.yesterday:
      return date == today.subtract(const Duration(days: 1));
    case VoiceQueryPeriod.thisWeek:
      final monday = today.subtract(Duration(days: today.weekday - 1));
      return !date.isBefore(monday) && !date.isAfter(today);
    case VoiceQueryPeriod.thisMonth:
      return date.year == today.year && date.month == today.month;
    case VoiceQueryPeriod.lastMonth:
      final lastMonth = DateTime(today.year, today.month - 1);
      return date.year == lastMonth.year && date.month == lastMonth.month;
    case VoiceQueryPeriod.all:
      return true;
  }
}

double _sum(
  List<Expense> expenses, {
  required bool isIncome,
  required ExpenseCategory? category,
  required VoiceQueryPeriod period,
  required DateTime today,
}) {
  var total = 0.0;
  for (final expense in expenses) {
    if (expense.isIncome != isIncome) continue;
    if (!_inPeriod(_dateOnly(expense.date), period, today)) continue;
    // Income carries no category, so a category filter only ever narrows
    // the expense side -- applying it to income would just zero it out.
    if (!isIncome && category != null && expense.category != category) {
      continue;
    }
    total += expense.amount;
  }
  return total;
}

/// Answers a [VoiceQueryIntent] from records already on the device --
/// nothing about the household's spending goes anywhere for this. [now] is
/// injectable so "today" and "this week" can be tested without waiting for
/// a particular date to come round.
VoiceAnswer answerVoiceQuery(
  List<Expense> expenses,
  VoiceQueryIntent query, {
  required AppCurrency currency,
  DateTime? now,
}) {
  final today = _dateOnly(now ?? DateTime.now());
  final periodPhrase = _periodPhrase[query.period]!;

  switch (query.type) {
    case VoiceQueryType.expense:
      final amount = _sum(
        expenses,
        isIncome: false,
        category: query.category,
        period: query.period,
        today: today,
      );
      final figure = currency.format.format(amount);
      final category = query.category;
      return VoiceAnswer(
        amount: amount,
        sentence: category == null
            ? 'Расходы $periodPhrase — $figure.'
            : 'На ${_accusative(category)} $periodPhrase потрачено $figure.',
      );

    case VoiceQueryType.income:
      final amount = _sum(
        expenses,
        isIncome: true,
        category: null,
        period: query.period,
        today: today,
      );
      return VoiceAnswer(
        amount: amount,
        sentence: 'Доход $periodPhrase — ${currency.format.format(amount)}.',
      );

    case VoiceQueryType.net:
      final income = _sum(
        expenses,
        isIncome: true,
        category: null,
        period: query.period,
        today: today,
      );
      final expense = _sum(
        expenses,
        isIncome: false,
        category: query.category,
        period: query.period,
        today: today,
      );
      final net = income - expense;
      final figure = currency.format.format(net.abs());
      final capitalized =
          periodPhrase[0].toUpperCase() + periodPhrase.substring(1);
      return VoiceAnswer(
        amount: net,
        sentence: net >= 0
            ? '$capitalized доход превысил расходы на $figure.'
            : '$capitalized расходы превысили доход на $figure.',
      );
  }
}
