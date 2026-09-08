import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/household_repository.dart';
import '../theme.dart';

class HouseholdScreen extends StatefulWidget {
  final void Function(String code) onReady;

  const HouseholdScreen({super.key, required this.onReady});

  @override
  State<HouseholdScreen> createState() => _HouseholdScreenState();
}

class _HouseholdScreenState extends State<HouseholdScreen> {
  final _repository = HouseholdRepository();
  final _codeController = TextEditingController();
  bool _busy = false;
  String? _errorText;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _createHousehold() async {
    setState(() => _busy = true);
    final code = HouseholdRepository.generateCode();
    await _repository.saveHouseholdCode(code);
    if (!mounted) return;
    await _showCodeDialog(code);
    if (!mounted) return;
    widget.onReady(code);
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
            const Text('Отправьте этот код супруге/супругу, '
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

  Future<void> _joinHousehold() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.length < 4) {
      setState(() => _errorText = 'Введите код бюджета целиком');
      return;
    }
    setState(() {
      _busy = true;
      _errorText = null;
    });
    await _repository.saveHouseholdCode(code);
    if (!mounted) return;
    widget.onReady(code);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
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
                  const SizedBox(height: 32),
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
                      Expanded(child: Divider(color: Colors.grey.withValues(alpha: 0.3))),
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
                      Expanded(child: Divider(color: Colors.grey.withValues(alpha: 0.3))),
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
                      errorText: _errorText,
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
