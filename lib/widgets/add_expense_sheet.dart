import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../models/currency.dart';
import '../models/expense.dart';
import '../models/expense_category.dart';
import '../models/transaction_type.dart';
import '../theme.dart';
import 'currency_symbol_icon.dart';

final _dateFormat = DateFormat('d MMMM y', 'ru');

String _groupThousands(String digits) {
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(' ');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

class _ThousandsSeparatorFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;

    final cleaned = newValue.text.replaceAll(RegExp(r'[^\d.,]'), '');
    final separatorMatch = RegExp(r'[.,]').firstMatch(cleaned);

    String integerPart;
    var separator = '';
    var decimalPart = '';
    if (separatorMatch != null) {
      integerPart = cleaned.substring(0, separatorMatch.start);
      separator = cleaned[separatorMatch.start];
      decimalPart = cleaned
          .substring(separatorMatch.start + 1)
          .replaceAll(RegExp(r'[.,]'), '');
    } else {
      integerPart = cleaned;
    }
    integerPart = integerPart.replaceAll(RegExp(r'[^\d]'), '');

    final result = '${_groupThousands(integerPart)}$separator$decimalPart';
    return TextEditingValue(
      text: result,
      selection: TextSelection.collapsed(offset: result.length),
    );
  }
}

class AddExpenseSheet extends StatefulWidget {
  final TransactionType type;
  final AppCurrency currency;
  final Expense? existing;
  final void Function(Expense expense) onSubmit;

  const AddExpenseSheet({
    super.key,
    required this.type,
    required this.currency,
    this.existing,
    required this.onSubmit,
  });

  @override
  State<AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends State<AddExpenseSheet> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  ExpenseCategory _selectedCategory = ExpenseCategory.food;
  DateTime _selectedDate = DateTime.now();
  String? _errorText;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      final rawAmount = existing.amount == existing.amount.roundToDouble()
          ? existing.amount.toInt().toString()
          : existing.amount.toString();
      final dotIndex = rawAmount.indexOf('.');
      _amountController.text = dotIndex == -1
          ? _groupThousands(rawAmount)
          : '${_groupThousands(rawAmount.substring(0, dotIndex))}${rawAmount.substring(dotIndex)}';
      _selectedCategory = existing.category ?? ExpenseCategory.food;
      _selectedDate = existing.date;
      _noteController.text = existing.note;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _submit() {
    final amountText =
        _amountController.text.replaceAll(' ', '').replaceAll(',', '.').trim();
    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      setState(() => _errorText = 'Введите корректную сумму');
      return;
    }

    widget.onSubmit(
      Expense(
        id: widget.existing?.id ?? const Uuid().v4(),
        amount: amount,
        category:
            widget.type == TransactionType.expense ? _selectedCategory : null,
        note: _noteController.text.trim(),
        date: _selectedDate,
        currency: widget.currency,
        type: widget.type,
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(bottom: 22),
                decoration: BoxDecoration(
                  color: accentForeground(context).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              (_isEditing
                      ? (widget.type == TransactionType.expense
                          ? 'Изменить расход'
                          : 'Изменить доход')
                      : (widget.type == TransactionType.expense
                          ? 'Новый расход'
                          : 'Новый доход'))
                  .toUpperCase(),
              style: microLabel(
                context,
                size: 11,
                color: goldFor(context).withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [_ThousandsSeparatorFormatter()],
              autofocus: true,
              style: moneyStyle(
                size: 26,
                weight: FontWeight.w300,
                color: accentForeground(context),
                letterSpacing: -0.5,
              ),
              decoration: InputDecoration(
                hintText: 'Сумма, ${widget.currency.symbol}',
                hintStyle: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w300,
                  color: accentForeground(context).withValues(alpha: 0.28),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                errorText: _errorText,
                // The currency's own symbol, not a generic money icon --
                // wrong to imply "dollar" when the budget is in rubles or
                // tenge.
                prefixIcon: CurrencySymbolIcon(currency: widget.currency),
              ),
              onChanged: (_) {
                if (_errorText != null) setState(() => _errorText = null);
              },
            ),
            if (widget.type == TransactionType.expense) ...[
              const SizedBox(height: 16),
              Text('КАТЕГОРИЯ', style: microLabel(context)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: ExpenseCategory.values.map((category) {
                  final selected = category == _selectedCategory;
                  const onSelectedInk = Color(0xFFF6F2EA);
                  return ChoiceChip(
                    selected: selected,
                    showCheckmark: false,
                    onSelected: (_) =>
                        setState(() => _selectedCategory = category),
                    avatar: Icon(
                      category.icon,
                      size: 17,
                      color: selected ? onSelectedInk : category.color,
                    ),
                    label: Text(category.label),
                    labelStyle: TextStyle(
                      fontSize: 13,
                      color: selected ? onSelectedInk : category.color,
                      fontWeight: FontWeight.w500,
                    ),
                    selectedColor: category.color,
                    backgroundColor: category.color.withValues(alpha: 0.08),
                    side: BorderSide(
                      color: category.color.withValues(
                        alpha: selected ? 0 : 0.28,
                      ),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                hintText: 'Заметка',
                prefixIcon: Icon(Icons.edit_note_rounded),
              ),
            ),
            const SizedBox(height: 16),
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: _pickDate,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Theme.of(context).inputDecorationTheme.fillColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: hairlineColor(context)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 18),
                    const SizedBox(width: 12),
                    // A long month name at a large system font scale used to
                    // run past the edge of the row; the date shrinks to fit
                    // rather than being clipped.
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _dateFormat.format(_selectedDate),
                          maxLines: 1,
                          softWrap: false,
                          style: const TextStyle(fontWeight: FontWeight.normal),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: widget.type == TransactionType.income
                    ? ElevatedButton.styleFrom(
                        backgroundColor: incomeColor(context),
                        foregroundColor: const Color(0xFFF6F2EA),
                      )
                    : null,
                onPressed: _submit,
                child: Text(_isEditing ? 'Сохранить' : 'Добавить'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
