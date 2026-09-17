import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/advice_service.dart';
import '../data/budget_repository.dart';
import '../models/currency.dart';
import '../models/expense.dart';
import '../models/expense_category.dart';
import '../models/spending_advice.dart';
import '../models/spending_snapshot.dart';
import '../theme.dart';
import '../widgets/app_background_pattern.dart';
import '../widgets/readable_width.dart';

enum _AdviceState { loading, insufficient, error, loaded }

/// The screen behind the "СОВЕТЫ" tab: hands the household's own numbers
/// to [AdviceService] and shows back what it says.
///
/// [expenses] arrives as a fixed snapshot, the same way [StatsScreen]
/// receives it -- the list this screen analyses is the one on screen when
/// it was opened, not a live one that would otherwise make its own cached
/// advice look stale mid-read for no reason the user did anything about.
class AdviceScreen extends StatefulWidget {
  final String householdCode;
  final AppCurrency currency;
  final List<Expense> expenses;

  const AdviceScreen({
    super.key,
    required this.householdCode,
    required this.currency,
    required this.expenses,
  });

  @override
  State<AdviceScreen> createState() => _AdviceScreenState();
}

class _AdviceScreenState extends State<AdviceScreen> {
  final _budgetRepository = BudgetRepository();
  final _service = AdviceService();

  _AdviceState _state = _AdviceState.loading;
  SpendingAdvice? _advice;
  String? _error;
  bool _fromCache = false;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  String get _cacheKey => 'advice_cache_${widget.householdCode}';

  Future<SpendingSnapshot> _buildSnapshot() async {
    final budgets =
        await _budgetRepository.watchBudgets(widget.householdCode).first;
    final limits = <ExpenseCategory, double>{
      for (final category in ExpenseCategory.values)
        if (BudgetRepository.budgetFor(budgets, category) != null)
          category: BudgetRepository.budgetFor(budgets, category)!,
    };
    return buildSpendingSnapshot(
      widget.expenses,
      currency: widget.currency,
      limits: limits,
    );
  }

  Future<SpendingAdvice?> _readCache(String fingerprint) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      if (decoded['fingerprint'] != fingerprint) return null;
      final advice = decoded['advice'];
      if (advice is! Map<String, dynamic>) return null;
      return SpendingAdvice.tryFromJson(advice);
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeCache(String fingerprint, SpendingAdvice advice) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _cacheKey,
      jsonEncode({'fingerprint': fingerprint, 'advice': advice.toJson()}),
    );
  }

  Future<void> _load({bool forceRefresh = false}) async {
    setState(() {
      if (forceRefresh) {
        _refreshing = true;
      } else {
        _state = _AdviceState.loading;
      }
    });

    final snapshot = await _buildSnapshot();
    if (!mounted) return;

    if (snapshot.recordCount < 3) {
      setState(() {
        _state = _AdviceState.insufficient;
        _refreshing = false;
      });
      return;
    }

    if (!forceRefresh) {
      final cached = await _readCache(snapshot.fingerprint);
      if (cached != null && mounted) {
        setState(() {
          _advice = cached;
          _fromCache = true;
          _state = _AdviceState.loaded;
        });
        return;
      }
    }
    if (!mounted) return;

    try {
      final advice = await _service.advise(snapshot);
      await _writeCache(snapshot.fingerprint, advice);
      if (!mounted) return;
      setState(() {
        _advice = advice;
        _fromCache = false;
        _state = _AdviceState.loaded;
        _refreshing = false;
      });
    } on AdviceException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _state = _AdviceState.error;
        _refreshing = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Не удалось получить советы';
        _state = _AdviceState.error;
        _refreshing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Советы'),
        actions: [
          if (_state == _AdviceState.loaded || _state == _AdviceState.error)
            IconButton(
              icon: _refreshing
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: goldFor(context),
                      ),
                    )
                  : const Icon(Icons.refresh_rounded),
              tooltip: 'Обновить анализ',
              onPressed: _refreshing ? null : () => _load(forceRefresh: true),
            ),
        ],
      ),
      body: AppBackgroundPattern(
        child: ReadableWidth(
          child: switch (_state) {
            _AdviceState.loading => Center(
                child: CircularProgressIndicator(
                  backgroundColor: goldFor(context).withValues(alpha: 0.16),
                  color: goldFor(context),
                ),
              ),
            _AdviceState.insufficient => const _MessageView(
                icon: Icons.hourglass_top_rounded,
                message: 'Пока маловато записей для разбора.\n'
                    'Добавьте ещё расходов — и здесь появится анализ',
              ),
            _AdviceState.error => _MessageView(
                icon: Icons.error_outline_rounded,
                message: _error ?? 'Не удалось получить советы',
                action: TextButton(
                  onPressed: () => _load(forceRefresh: true),
                  child: const Text('Повторить'),
                ),
              ),
            _AdviceState.loaded => _AdviceContent(
                advice: _advice!,
                fromCache: _fromCache,
              ),
          },
        ),
      ),
    );
  }
}

class _MessageView extends StatelessWidget {
  final IconData icon;
  final String message;
  final Widget? action;

  const _MessageView({required this.icon, required this.message, this.action});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 40, color: goldFor(context).withValues(alpha: 0.6)),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: accentForeground(context).withValues(alpha: 0.75),
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: 12),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class _AdviceContent extends StatelessWidget {
  final SpendingAdvice advice;
  final bool fromCache;

  const _AdviceContent({required this.advice, required this.fromCache});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        _VerdictBadge(verdict: advice.verdict),
        const SizedBox(height: 14),
        Text(
          advice.headline,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w500,
            height: 1.35,
            color: accentForeground(context),
          ),
        ),
        const SizedBox(height: 28),
        for (final tip in advice.tips) ...[
          _TipCard(tip: tip),
          const SizedBox(height: 12),
        ],
        if (fromCache) ...[
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Показан прошлый анализ — цифры с тех пор не менялись',
              style: microLabel(context, size: 10),
            ),
          ),
        ],
      ],
    );
  }
}

class _VerdictBadge extends StatelessWidget {
  final SpendingVerdict verdict;

  const _VerdictBadge({required this.verdict});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (verdict) {
      SpendingVerdict.positive => ('ВСЁ ХОРОШО', incomeColor(context)),
      SpendingVerdict.neutral => ('В ЦЕЛОМ РОВНО', goldFor(context)),
      SpendingVerdict.concerning => (
          'ЕСТЬ О ЧЁМ ЗАДУМАТЬСЯ',
          expenseColor(context)
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label, style: microLabel(context, color: color)),
    );
  }
}

class _TipCard extends StatelessWidget {
  final SpendingTip tip;

  const _TipCard({required this.tip});

  @override
  Widget build(BuildContext context) {
    final category = tip.category;
    final icon = category?.icon ?? Icons.auto_awesome_rounded;
    final tint = category?.color ?? goldFor(context);
    final isWarning = tip.severity == TipSeverity.warning;

    return Container(
      decoration: BoxDecoration(
        color: glassFill(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isWarning
              ? overBudgetColor(context).withValues(alpha: 0.35)
              : glassEdge(context),
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.13),
              shape: BoxShape.circle,
              border: Border.all(color: tint.withValues(alpha: 0.22)),
            ),
            child: Icon(icon, color: tint, size: 17),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tip.title,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: accentForeground(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tip.detail,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.4,
                    color: accentForeground(context).withValues(alpha: 0.72),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
