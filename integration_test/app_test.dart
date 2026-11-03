import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:spending_assistant/main.dart';
import 'package:spending_assistant/domain.dart';
import 'package:spending_assistant/repository.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final captureKey = GlobalKey();
  Future<void> capture(WidgetTester tester, String name) async {
    ScaffoldMessenger.of(tester.element(find.byType(Scaffold).first))
        .clearSnackBars();
    await tester.pumpAndSettle();
    final boundary =
        captureKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    void repaint(RenderObject node) {
      node.markNeedsPaint();
      node.visitChildren(repaint);
    }

    repaint(boundary);
    await tester.pump();
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    binding.reportData ??= {};
    final screenshots = binding.reportData!.putIfAbsent(
      'screenshots',
      () => <Map<String, dynamic>>[],
    ) as List;
    screenshots.add({
      'screenshotName': name,
      'bytes': bytes!.buffer.asUint8List().toList(),
    });
  }

  testWidgets('Android SQLite and four-screen end-to-end flow', (tester) async {
    const filename = 'integration-validation.db';
    final clock = DateTime(2026, 11, 3);
    await deleteDatabase(p.join(await getDatabasesPath(), filename));
    var repo = await SpendingRepository.open(filename: filename, clock: clock);
    await tester.pumpWidget(
      RepaintBoundary(
        key: captureKey,
        child: SpendingApp(repository: repo, clock: clock),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('862,000원'), findsWidgets);
    expect(find.text('78.4%'), findsOneWidget);
    await capture(tester, 'android-home');

    await tester.tap(find.byKey(const ValueKey('add-expense')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('expense-amount')),
      '5800',
    );
    await tester.enterText(
      find.byKey(const ValueKey('expense-merchant')),
      '통합검증 카페',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('save-expense')));
    await tester.tap(find.byKey(const ValueKey('save-expense')));
    await tester.pumpAndSettle();
    expect((await repo.load()).summary(clock).total, 867800);
    final added = (await repo.load()).expenses.firstWhere(
      (e) => e.merchant == '통합검증 카페',
    );
    await repo.saveExpense(
      Expense(
        id: added.id,
        date: added.date,
        amount: 6200,
        category: '카페',
        merchant: added.merchant,
      ),
    );

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await repo.close();
    repo = await SpendingRepository.open(filename: filename, clock: clock);
    expect((await repo.load()).summary(clock).total, 868200);
    await repo.deleteExpense(added.id!);
    expect((await repo.load()).summary(clock).total, 862000);
    await tester.pumpWidget(
      RepaintBoundary(
        key: captureKey,
        child: SpendingApp(repository: repo, clock: clock),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('nav-1')));
    await tester.pumpAndSettle();
    expect(find.text('카테고리별 지출 현황'), findsOneWidget);
    await capture(tester, 'android-analysis');
    await tester.tap(find.byKey(const ValueKey('nav-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('generate-report')));
    await tester.pumpAndSettle();
    expect(find.text('이번 달 핵심 인사이트'), findsOneWidget);
    expect((await repo.load()).reports['2026-11']!['savings'], 47040);
    await capture(tester, 'android-report');
    await tester.tap(find.byKey(const ValueKey('nav-3')));
    await tester.pumpAndSettle();
    expect(find.text('! 예산 주의'), findsOneWidget);
    expect(find.text('95.0%'), findsOneWidget);
    await capture(tester, 'android-budget');

    await repo.saveBudget(
      clock,
      const Budget(total: 800000, limits: {'쇼핑': 100000}),
    );
    final over = (await repo.load()).summary(clock);
    expect(over.remaining, -62000);
    expect(over.status, '초과');
    await repo.saveBudget(clock, demoBudget);
    await repo.saveName('검증 사용자');
    await repo.close();
    repo = await SpendingRepository.open(filename: filename, clock: clock);
    expect((await repo.load()).name, '검증 사용자');
    await repo.clear();
    await repo.close();
    repo = await SpendingRepository.open(filename: filename, clock: clock);
    expect((await repo.load()).expenses, isEmpty);
    expect((await repo.load()).demo, false);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await repo.close();
    binding.reportData = {
      ...?binding.reportData,
      'status': 'passed',
      'initialTotal': 862000,
      'usage': '78.4%',
      'shoppingWarning': '95.0%',
      'sqliteReopen': true,
      'crud': true,
      'reportSavings': 47040,
      'resetDoesNotReseed': true,
    };
  });
}
