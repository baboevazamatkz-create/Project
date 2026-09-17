import 'expense_category.dart';

/// The month, at a glance: whether it went well, and why the headline
/// picks the tone it does.
enum SpendingVerdict { positive, neutral, concerning }

/// How much attention a tip is asking for. Purely presentational -- a
/// [warning] gets the tinted rail an over-limit category deserves, an
/// [info] tip stays quiet.
enum TipSeverity { info, warning }

/// One recommendation: what it's about, if anything in particular, and
/// what to actually do about it.
class SpendingTip {
  final ExpenseCategory? category;
  final TipSeverity severity;
  final String title;
  final String detail;

  const SpendingTip({
    required this.category,
    required this.severity,
    required this.title,
    required this.detail,
  });

  Map<String, dynamic> toJson() => {
        'category': category?.storageKey,
        'severity': severity.name,
        'title': title,
        'detail': detail,
      };

  /// Refuses a tip with nothing to say rather than render an empty card;
  /// the worker already drops these, but a cached copy read back from disk
  /// gets no such guarantee.
  static SpendingTip? tryFromJson(Map<String, dynamic> json) {
    final title = (json['title'] as String? ?? '').trim();
    final detail = (json['detail'] as String? ?? '').trim();
    if (title.isEmpty || detail.isEmpty) return null;

    final categoryKey = json['category'] as String?;
    return SpendingTip(
      category: categoryKey == null || categoryKey == 'general'
          ? null
          : ExpenseCategoryX.fromStorageKey(categoryKey),
      severity: TipSeverity.values.firstWhere(
        (s) => s.name == json['severity'],
        orElse: () => TipSeverity.info,
      ),
      title: title,
      detail: detail,
    );
  }
}

/// What the worker hands back for a month of spending: a verdict, one
/// headline sentence, and the tips behind it.
class SpendingAdvice {
  final SpendingVerdict verdict;
  final String headline;
  final List<SpendingTip> tips;

  const SpendingAdvice({
    required this.verdict,
    required this.headline,
    required this.tips,
  });

  Map<String, dynamic> toJson() => {
        'verdict': verdict.name,
        'headline': headline,
        'tips': tips.map((t) => t.toJson()).toList(),
      };

  /// Refuses to become an "empty success" -- a headline with nothing
  /// behind it says less than the screen's own "not enough yet" message,
  /// and would be a stranger thing to cache and show again later.
  static SpendingAdvice? tryFromJson(Map<String, dynamic> json) {
    final headline = (json['headline'] as String? ?? '').trim();
    if (headline.isEmpty) return null;

    final rawTips = json['tips'];
    final tips = <SpendingTip>[];
    if (rawTips is List) {
      for (final item in rawTips) {
        if (item is! Map<String, dynamic>) continue;
        final tip = SpendingTip.tryFromJson(item);
        if (tip != null) tips.add(tip);
      }
    }
    if (tips.isEmpty) return null;

    return SpendingAdvice(
      verdict: SpendingVerdict.values.firstWhere(
        (v) => v.name == json['verdict'],
        orElse: () => SpendingVerdict.neutral,
      ),
      headline: headline,
      tips: tips,
    );
  }
}
