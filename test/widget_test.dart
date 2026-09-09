import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:expense_tracker/screens/household_screen.dart';

void main() {
  testWidgets('Household screen offers create and join actions',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HouseholdScreen(onReady: (_) {}),
      ),
    );

    expect(find.text('Трекинг расходов'), findsOneWidget);
    expect(find.text('Создать новый бюджет'), findsOneWidget);
    expect(find.text('Присоединиться по коду'), findsOneWidget);
  });
}
