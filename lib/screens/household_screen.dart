import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/household_repository.dart';
import '../data/household_settings_repository.dart';
import '../models/currency.dart';
import '../models/household.dart';
import '../theme.dart';
import '../widgets/readable_width.dart';
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

/// This screen reads at a size of its own: it is the first thing a new
/// user meets and is read once rather than scanned daily, so its type runs
/// [_kTextScale] larger than the rest of the app and the wordmark above it
/// larger still. Two factors rather than a spray of figures, so the
/// proportions hold if either is retuned.
const double _kTextScale = 1.5;
const double _kWordmarkScale = 3.0;

double _t(double value) => value * _kTextScale;

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
      body: _scaledTheme(
        context,
        child: AppBackgroundPattern(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ReadableWidth(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // The wordmark is the brand, so it stands above the
                        // form whether this is the first run or a second
                        // budget opened from the switcher. Only the headline
                        // under it belongs to the first run.
                        Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'SOLIDUS',
                              style: microLabel(
                                context,
                                size: 12 * _kWordmarkScale,
                                color: goldFor(context).withValues(alpha: 0.9),
                              ).copyWith(letterSpacing: 4),
                            ),
                          ),
                        ),
                        SizedBox(height: widget.canCancel ? 28 : 20),
                        if (!widget.canCancel) ...[
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Единый ритм\nмалых финансов',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: _t(30),
                                height: 1.15,
                                fontWeight: FontWeight.w300,
                                letterSpacing: -0.8,
                                color: accentForeground(context),
                              ),
                            ),
                          ),
                          SizedBox(height: _t(12)),
                        ],
                        Text(
                          'Создайте общий бюджет и поделитесь кодом, '
                          'чтобы вести расходы вместе',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: _t(14),
                            color: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.color
                                ?.withValues(alpha: 0.6),
                          ),
                        ),
                        SizedBox(height: _t(28)),
                        Center(
                          child: Text('ВАЛЮТА БЮДЖЕТА',
                              style: microLabel(context, size: _t(10.5))),
                        ),
                        SizedBox(height: _t(10)),
                        Center(
                          child: _CurrencyPicker(
                            selected: _selectedCurrency,
                            onChanged: (currency) =>
                                setState(() => _selectedCurrency = currency),
                          ),
                        ),
                        SizedBox(height: _t(28)),
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
                        SizedBox(height: _t(16)),
                        SizedBox(
                          height: _t(52),
                          child: ElevatedButton.icon(
                            onPressed: _busy ? null : _createHousehold,
                            icon: Icon(Icons.add_circle_outline, size: _t(19)),
                            // Shrinks rather than truncating: on a narrow
                            // phone "Создать новый ..." drops the word that
                            // says what is being created.
                            label: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text('Создать новый бюджет', maxLines: 1),
                            ),
                          ),
                        ),
                        SizedBox(height: _t(24)),
                        Row(
                          children: [
                            Expanded(
                                child: Divider(color: hairlineColor(context))),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: _t(14)),
                              child: Text('ИЛИ',
                                  style: microLabel(context, size: _t(10))),
                            ),
                            Expanded(
                                child: Divider(color: hairlineColor(context))),
                          ],
                        ),
                        SizedBox(height: _t(24)),
                        TextField(
                          controller: _codeController,
                          textAlign: TextAlign.center,
                          textCapitalization: TextCapitalization.characters,
                          inputFormatters: [UpperCaseTextFormatter()],
                          style: TextStyle(
                            fontSize: _t(19),
                            fontWeight: FontWeight.w500,
                            letterSpacing: _t(4),
                          ),
                          decoration: InputDecoration(
                            hintText: 'Код бюджета',
                            // The field letterspaces its code digits; the hint is
                            // a sentence and should not inherit that.
                            hintStyle: Theme.of(context)
                                .inputDecorationTheme
                                .hintStyle
                                ?.copyWith(
                                    fontSize: _t(15), letterSpacing: 0.2),
                            errorText: _codeError,
                          ),
                        ),
                        SizedBox(height: _t(12)),
                        SizedBox(
                          height: _t(52),
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: accentForeground(context)
                                  .withValues(alpha: 0.85),
                              side: BorderSide(color: hairlineColor(context)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              textStyle: TextStyle(
                                fontFamily: 'Onest',
                                fontSize: _t(14),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            onPressed: _busy ? null : _joinHousehold,
                            icon: Icon(Icons.group_add_rounded, size: _t(19)),
                            // Shrinks rather than truncating: on a narrow
                            // phone "Создать новый ..." drops the word that
                            // says what is being created.
                            label: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child:
                                  Text('Присоединиться по коду', maxLines: 1),
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
        ),
      ),
    );
  }
}

/// The fields and buttons on this screen take their metrics from the app
/// theme, so scaling only the figures written above would grow the labels
/// and leave the controls at their old height. This scales them to match,
/// and stops at this screen.
Widget _scaledTheme(BuildContext context, {required Widget child}) {
  final theme = Theme.of(context);
  final input = theme.inputDecorationTheme;
  return Theme(
    data: theme.copyWith(
      inputDecorationTheme: input.copyWith(
        contentPadding:
            EdgeInsets.symmetric(horizontal: _t(16), vertical: _t(15)),
        hintStyle:
            (input.hintStyle ?? const TextStyle()).copyWith(fontSize: _t(15)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: theme.elevatedButtonTheme.style?.copyWith(
          textStyle: WidgetStatePropertyAll(
            TextStyle(
              fontFamily: 'Onest',
              fontSize: _t(15),
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
            ),
          ),
        ),
      ),
    ),
    child: child,
  );
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
    // Three chips at this size are wider than a 320pt phone's content
    // column, so the whole control scales down to fit rather than
    // overflowing. On anything roomier it is drawn at full size.
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Container(
        padding: EdgeInsets.all(_t(4)),
        decoration: BoxDecoration(
          color: Theme.of(context).inputDecorationTheme.fillColor,
          borderRadius: BorderRadius.circular(_t(14)),
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
                width: _t(64),
                height: _t(40),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected
                      ? goldFor(context).withValues(alpha: 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(_t(10)),
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
                    fontSize: _t(11),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
