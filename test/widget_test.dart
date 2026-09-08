import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:expense_tracker/main.dart';

void main() {
  testWidgets('App renders home screen with title', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const ExpenseTrackerApp());
    await tester.pumpAndSettle();

    expect(find.text('Расходы'), findsOneWidget);
  });
}
