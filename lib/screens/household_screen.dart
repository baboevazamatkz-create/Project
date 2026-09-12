import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/household_repository.dart';
import '../data/household_settings_repository.dart';
import '../models/currency.dart';
import '../models/household.dart';
import '../theme.dart';
import '../widgets/app_background_pattern.dart';

class HouseholdScreen extends StatefulWidget {
  final void Function(Household household) onReady;
  final bool canCancel;

  const HouseholdScreen({
    super.key,
    required this.onReady,
    this.canCancel = false,
  });

  @override
  State<HouseholdScreen> createState() => _HouseholdScreenState();
}

class _HouseholdScreenState extends State<HouseholdScreen> {
  final _labelController = TextEditingController();
  final _codeController = TextEditingController();
  final _settingsRepository = HouseholdSettingsRepository();
  AppCurrency _selectedCurrency = AppCurrency.rub;
  bool _busy = false;
  String? _labelError;
  String? _codeError;

  @override
  void dispose() {
    _labelController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  bool _validateLabel() {
    if (_labelController.text.trim().isEmpty) {
      setState(() => _labelError = 'Введите название бюджета');
      return false;
    }
    setState(() => _labelError = null);
    return true;
  }

  Future<void> _createHousehold() async {
    if (!_validateLabel()) return;
    setState(() => _busy = true);
    final code = HouseholdRepository.generateCode();
    final label = _labelController.text.trim();
    await _settingsRepository.setCurrency(code, _selectedCurrency);
    await _settingsRepository.setLabel(code, label);
    if (!mounted) return;
    await _showCodeDialog(code);
    if (!mounted) return;
    widget.onReady(Household(code: code, label: label));
  }

  Future<void> _joinHousehold() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.length < 4) {
      setState(() => _codeError = 'Введите код бюджета целиком');
      return;
    }
    setState(() {
      _busy = true;
      _codeError = null;
    });
    String label;
    try {
      label = await _settingsRepository.fetchLabel(code) ?? 'Бюджет';
    } catch (_) {
      label = 'Бюджет';
    }
    if (!mounted) return;
    widget.onReady(Household(code: code, label: label));
  }

  Future<void> _showCodeDialog(String code) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        // Tinted to match the welcome screen it is opened from, rather than
        // the plain black-on-white the Material default gives it.
        backgroundColor: Color.alphaBlend(
          goldFor(context).withValues(alpha: isDark ? 0.08 : 0.04),
          Theme.of(context).dialogTheme.backgroundColor ??
              Theme.of(context).colorScheme.surface,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: goldFor(context).withValues(alpha: 0.3)),
        ),
        titleTextStyle: TextStyle(
          fontFamily: 'Onest',
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
          color: accentForeground(context),
        ),
        title: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: goldFor(context), size: 21),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Бюджет создан',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Отправьте этот код супруге/супругу или коллегам, '
              'чтобы вести бюджет вместе:',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.color
                    ?.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: goldFor(context).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
                border:
                    Border.all(color: goldFor(context).withValues(alpha: 0.35)),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  code,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 5,
                    color: goldFor(context),
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: goldFor(context)),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Код скопирован')),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Скопировать'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Готово'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          widget.canCancel ? AppBar(title: const Text('Новый бюджет')) : null,
      body: AppBackgroundPattern(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!widget.canCancel) ...[
                      Center(
                        child: Text(
                          'ГДЕБАБЛО?',
                          style: microLabel(
                            context,
                            size: 11,
                            color: goldFor(context).withValues(alpha: 0.9),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Общий бюджет\nна двоих',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 30,
                          height: 1.15,
                          fontWeight: FontWeight.w300,
                          letterSpacing: -0.8,
                          color: accentForeground(context),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Text(
                      'Создайте общий бюджет и поделитесь кодом, '
                      'чтобы вести расходы вместе',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.color
                            ?.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Center(
                      child: Text('ВАЛЮТА БЮДЖЕТА', style: microLabel(context)),
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: _CurrencyPicker(
                        selected: _selectedCurrency,
                        onChanged: (currency) =>
                            setState(() => _selectedCurrency = currency),
                      ),
                    ),
                    const SizedBox(height: 28),
                    TextField(
                      controller: _labelController,
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        hintText: 'Название бюджета (например, Семья)',
                        errorText: _labelError,
                      ),
                      onChanged: (_) {
                        if (_labelError != null) {
                          setState(() => _labelError = null);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _busy ? null : _createHousehold,
                        icon: const Icon(Icons.add_circle_outline, size: 19),
                        label: const Text(
                          'Создать новый бюджет',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(child: Divider(color: hairlineColor(context))),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child:
                              Text('ИЛИ', style: microLabel(context, size: 10)),
                        ),
                        Expanded(child: Divider(color: hairlineColor(context))),
                      ],
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _codeController,
                      textAlign: TextAlign.center,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [UpperCaseTextFormatter()],
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 4,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Код бюджета',
                        // The field letterspaces its code digits; the hint is
                        // a sentence and should not inherit that.
                        hintStyle: Theme.of(context)
                            .inputDecorationTheme
                            .hintStyle
                            ?.copyWith(fontSize: 15, letterSpacing: 0.2),
                        errorText: _codeError,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 52,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor:
                              accentForeground(context).withValues(alpha: 0.85),
                          side: BorderSide(color: hairlineColor(context)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          textStyle: const TextStyle(
                            fontFamily: 'Onest',
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        onPressed: _busy ? null : _joinHousehold,
                        icon: const Icon(Icons.group_add_rounded, size: 19),
                        label: const Text(
                          'Присоединиться по коду',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}

class _CurrencyPicker extends StatelessWidget {
  final AppCurrency selected;
  final ValueChanged<AppCurrency> onChanged;

  const _CurrencyPicker({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).inputDecorationTheme.fillColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: hairlineColor(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: AppCurrency.values.map((currency) {
          final isSelected = currency == selected;
          return GestureDetector(
            onTap: () => onChanged(currency),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 64,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected
                    ? goldFor(context).withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: isSelected
                    ? Border.all(
                        color: goldFor(context).withValues(alpha: 0.45))
                    : null,
              ),
              child: Text(
                '${currency.symbol} ${currency.label}',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isSelected
                      ? goldFor(context)
                      : accentForeground(context).withValues(alpha: 0.55),
                  fontWeight: FontWeight.w500,
                  fontSize: 11,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
