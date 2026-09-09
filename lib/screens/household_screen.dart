import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/household_repository.dart';
import '../data/household_settings_repository.dart';
import '../models/currency.dart';
import '../models/household.dart';

const _screenGreen = Color(0xFF22C55E);

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
    await _settingsRepository.setCurrency(code, _selectedCurrency);
    if (!mounted) return;
    await _showCodeDialog(code);
    if (!mounted) return;
    widget.onReady(Household(code: code, label: _labelController.text.trim()));
  }

  Future<void> _joinHousehold() async {
    final labelOk = _validateLabel();
    final code = _codeController.text.trim().toUpperCase();
    if (code.length < 4) {
      setState(() => _codeError = 'Введите код бюджета целиком');
      return;
    }
    if (!labelOk) return;
    setState(() {
      _busy = true;
      _codeError = null;
    });
    widget.onReady(Household(code: code, label: _labelController.text.trim()));
  }

  Future<void> _showCodeDialog(String code) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Бюджет создан'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Отправьте этот код супруге/супругу или коллегам, '
                'чтобы вести бюджет вместе:'),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: _screenGreen.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                code,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.normal,
                  letterSpacing: 4,
                  color: _screenGreen,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
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
            style: ElevatedButton.styleFrom(backgroundColor: _screenGreen),
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!widget.canCancel) ...[
                    const Text(
                      'Трекинг расходов',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.normal,
                        color: _screenGreen,
                      ),
                    ),
                    const SizedBox(height: 8),
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
                  Text(
                    'Валюта бюджета',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.color
                          ?.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 8),
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
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _screenGreen,
                      ),
                      onPressed: _busy ? null : _createHousehold,
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text('Создать новый бюджет'),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                          child: Divider(
                              color: Colors.grey.withValues(alpha: 0.3))),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'или',
                          style: TextStyle(
                            color: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.color
                                ?.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                      Expanded(
                          child: Divider(
                              color: Colors.grey.withValues(alpha: 0.3))),
                    ],
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _codeController,
                    textAlign: TextAlign.center,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [UpperCaseTextFormatter()],
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.normal,
                      letterSpacing: 4,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Код бюджета',
                      hintStyle:
                          Theme.of(context).inputDecorationTheme.hintStyle,
                      errorText: _codeError,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 52,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _screenGreen,
                        side: const BorderSide(color: _screenGreen),
                      ),
                      onPressed: _busy ? null : _joinHousehold,
                      icon: const Icon(Icons.group_add_rounded),
                      label: const Text('Присоединиться по коду'),
                    ),
                  ),
                ],
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
                    ? _screenGreen.withValues(alpha: 0.14)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: isSelected
                    ? Border.all(color: _screenGreen.withValues(alpha: 0.4))
                    : null,
              ),
              child: Text(
                '${currency.symbol} ${currency.label}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isSelected
                      ? _screenGreen
                      : Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.color
                          ?.withValues(alpha: 0.6),
                  fontWeight: FontWeight.normal,
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
