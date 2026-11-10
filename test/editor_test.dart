import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_assistant/main.dart';
import 'package:spending_assistant/domain.dart';
import 'package:spending_assistant/repository.dart';

class _DemoRepository extends Fake implements SpendingRepository {
  PrototypeSpending? applied;

  @override
  Future<void> applyPrototypeSpending(
    DateTime month,
    PrototypeSpending profile,
  ) async {
    applied = profile;
  }

  @override
  Future<Ledger> load() async => Ledger(
    expenses: [
      const Expense(
        id: 1,
        date: '2026-11-03',
        amount: 6200,
        category: '카페',
        merchant: '카페 테스트',
      ),
      const Expense(
        id: 2,
        date: '2026-11-04',
        amount: 1500,
        category: '교통',
        merchant: '교통 테스트',
      ),
    ],
  );
}

void main() {
  testWidgets('settings offers three monthly spending examples', (
    tester,
  ) async {
    final repository = _DemoRepository();
    await tester.pumpWidget(
      SpendingApp(repository: repository, clock: DateTime(2026, 11)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('설정'));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey('page-scroll')),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('예시 지출 선택하기'));
    await tester.pumpAndSettle();
    for (final profile in PrototypeSpending.values) {
      expect(find.text(profile.title), findsOneWidget);
    }
    await tester.tap(find.text(PrototypeSpending.saving.title));
    await tester.pumpAndSettle();
    expect(repository.applied, PrototypeSpending.saving);
  });

  testWidgets('Gemini action is available in the report card without setup', (
    tester,
  ) async {
    await tester.pumpWidget(
      SpendingApp(repository: _DemoRepository(), clock: DateTime(2026, 11)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('리포트'));
    await tester.pumpAndSettle();
    final action = find.widgetWithText(FilledButton, 'Gemini 조언 받기');
    expect(action, findsOneWidget);
    expect(tester.widget<FilledButton>(action).onPressed, isNotNull);
    expect(tester.getSize(action).height, inInclusiveRange(36, 43));
    expect(tester.takeException(), isNull);
  });

  testWidgets('home expense filter fits and works on a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      SpendingApp(repository: _DemoRepository(), clock: DateTime(2026, 11)),
    );
    await tester.pumpAndSettle();
    final filter = find.byKey(const ValueKey('filter-'));
    final page = find.byKey(const ValueKey('page-scroll'));
    await tester.scrollUntilVisible(
      filter,
      300,
      scrollable: find
          .descendant(of: page, matching: find.byType(Scrollable))
          .first,
    );
    expect(tester.takeException(), isNull);
    await tester.tap(filter);
    await tester.pumpAndSettle();
    await tester.tap(find.text('카페').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('filter-카페')), findsOneWidget);
    expect(find.byKey(const ValueKey('expense-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('expense-2')), findsNothing);
    expect(tester.takeException(), isNull);
  });

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
