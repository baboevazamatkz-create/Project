import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/household_repository.dart';
import '../models/household.dart';
import '../theme.dart';

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
                color: kAccentColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                code,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 4,
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
                    Container(
                      width: 72,
                      height: 72,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: kAccentColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.people_alt_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Семейный бюджет',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
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
                  TextField(
                    controller: _labelController,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w600),
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
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
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
                      fontWeight: FontWeight.w700,
                      letterSpacing: 4,
                    ),
                    decoration: InputDecoration(
                      hintText: 'КОД БЮДЖЕТА',
                      errorText: _codeError,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 52,
                    child: OutlinedButton.icon(
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
