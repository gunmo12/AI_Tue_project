import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_assistant/main.dart';
import 'package:spending_assistant/domain.dart';

void main() {
  testWidgets('expense editor blocks empty and zero amounts', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ExpenseEditor(date: DateTime(2026, 11, 3))),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('save-expense')));
    await tester.pump();
    expect(find.text('금액은 원 단위 정수로 입력해 주세요.'), findsOneWidget);
    expect(find.text('사용처를 입력해 주세요.'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('expense-amount')), '0');
    await tester.pump();
    expect(find.text('1~1,000,000,000원 사이로 입력해 주세요.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('native budget editor fits narrow screens and keyboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BudgetEditor(budget: demoBudget, month: DateTime(2026, 11)),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('budget-total')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
