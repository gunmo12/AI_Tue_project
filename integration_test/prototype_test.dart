import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'package:spending_assistant/cloud_report.dart';
import 'package:spending_assistant/domain.dart';
import 'package:spending_assistant/repository.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final month = DateTime(2026, 11);

  testWidgets('Android receives Gemini advice for synthetic data', (_) async {
    final summary = MonthSummary(
      month,
      PrototypeSpending.everyday.records(month),
      [],
      const Budget(total: 900000),
    );
    final advice = await CloudReport(
      'https://moneymate-mobile-693983780937.asia-northeast3.run.app',
    ).advice(summary);
    expect(advice, isNotEmpty);
  }, skip: !const bool.fromEnvironment('MONEYMATE_LIVE_TEST'));

  testWidgets('switching examples preserves personal and edited entries', (
    _,
  ) async {
    final filename =
        'prototype-test-${DateTime.now().microsecondsSinceEpoch}.db';
    final repository = await SpendingRepository.open(
      filename: filename,
      clock: month,
    );
    try {
      await repository.saveExpense(
        Expense(
          date: '2026-11-10',
          amount: 7777,
          category: categories.first,
          merchant: 'Personal',
        ),
      );
      await repository.applyPrototypeSpending(month, PrototypeSpending.saving);
      final initial = (await repository.load()).summary(month).expenses;
      final sample = initial.firstWhere(
        (entry) => entry.memo == PrototypeSpending.saving.title,
      );
      await repository.saveExpense(
        Expense(
          id: sample.id,
          date: sample.date,
          amount: 9999,
          category: sample.category,
          merchant: 'Edited',
        ),
      );
      await repository.applyPrototypeSpending(
        month,
        PrototypeSpending.shopping,
      );
      await repository.applyPrototypeSpending(
        month,
        PrototypeSpending.shopping,
      );
      final result = (await repository.load()).summary(month).expenses;
      expect(
        result.where((entry) => entry.memo == PrototypeSpending.shopping.title),
        hasLength(33),
      );
      expect(
        result.where((entry) => entry.memo == PrototypeSpending.saving.title),
        isEmpty,
      );
      expect(result.any((entry) => entry.merchant == 'Personal'), isTrue);
      expect(result.any((entry) => entry.merchant == 'Edited'), isTrue);
    } finally {
      await repository.close();
      await deleteDatabase(path.join(await getDatabasesPath(), filename));
    }
  });
}
