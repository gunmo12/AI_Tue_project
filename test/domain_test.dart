import 'package:flutter_test/flutter_test.dart';
import 'package:spending_assistant/domain.dart';

void main() {
  final month = DateTime(2026, 11);
  Ledger demo() => Ledger(
    expenses: demoExpenses(month),
    budgets: {monthKey(month): demoBudget},
  );
  test('T01 document totals and daily/category reconciliation', () {
    final s = demo().summary(month);
    expect(s.total, 862000);
    expect(s.remaining, 238000);
    expect(percent(s.usage), '78.4%');
    expect(s.expenses.length, 33);
    expect(s.daily.fold(0, (a, b) => a + b), 862000);
    expect(s.categoryTotals.fold(0, (a, c) => a + c.spent), 862000);
  });
  test('T02 shopping 95% warning', () {
    final c = demo()
        .summary(month)
        .categoryTotals
        .firstWhere((c) => c.name == '쇼핑');
    expect(c.usage, 95);
    expect(c.limit - c.spent, 10000);
    expect(c.status, '주의');
  });
  test('T03 missing comparison creates no invented change', () {
    final s = Ledger(
      expenses: demoExpenses(month)
          .where((r) => r.date.startsWith('2026-11'))
          .toList(),
    ).summary(month);
    expect(s.comparable, false);
    expect(s.change, isNull);
    expect(buildReport(s)['insights'][1]['title'], contains('부족'));
  });
  test('thresholds use unrounded integers', () {
    expect(budgetStatus(89999, 100000), '여유');
    expect(budgetStatus(90000, 100000), '주의');
    expect(budgetStatus(100000, 100000), '주의');
    expect(budgetStatus(100001, 100000), '초과');
    expect(budgetStatus(5, 0), '미설정');
  });
  test('previous month matches exact source amounts', () {
    final s = demo().summary(month);
    expect(s.previousTotal, 925000);
    expect(s.delta, -63000);
    expect(percent(s.change), '-6.8%');
  });
  test('empty month and unset budget', () {
    final s = const Ledger().summary(month);
    expect(s.total, 0);
    expect(s.usage, isNull);
    expect(s.remaining, isNull);
    expect(buildReport(s)['savings'], 0);
  });
  test('savings specify unit and cap at real transaction count', () {
    final s = demo().summary(month);
    final r = buildReport(s);
    expect(r['unit'], 5880);
    expect(r['count'], 8);
    expect(r['savings'], 47040);
    expect(buildReport(s, skip: 7, weeks: 5)['savings'], 58800);
    expect(r['recurringCount'], 4);
    expect(r['recurringTotal'], 79200);
  });
  test('signature changes after budget or expense changes', () {
    final s = demo().summary(month);
    final r = buildReport(s);
    final changed = Ledger(
      expenses: s.expenses,
      budgets: {monthKey(month): const Budget(total: 800000)},
    ).summary(month);
    expect(r['signature'], isNot(changed.signature));
  });
  test('invalid monetary/date inputs rejected', () {
    for (final v in ['', '0', '-1', '1.5', 'abc', '1000000001']) {
      expect(() => validAmount(v), throwsFormatException);
    }
    expect(validAmount('0', allowZero: true), 0);
    expect(validAmount('5800'), 5800);
    expect(
      () => const Expense(
        date: '2026-02-30',
        amount: 1,
        category: '식비',
        merchant: 'test',
      ).validate(),
      throwsFormatException,
    );
    expect(
      () => const Expense(
        date: '2026-11-03',
        amount: 1,
        category: '식비',
        merchant: ' ',
      ).validate(),
      throwsFormatException,
    );
  });
  test('year transitions and leap year', () {
    expect(monthKey(shiftMonth(DateTime(2026, 1), -1)), '2025-12');
    expect(monthKey(shiftMonth(DateTime(2026, 12), 1)), '2027-01');
    expect(const Ledger().summary(DateTime(2028, 2)).days, 29);
  });
  test('out of range savings assumptions rejected', () {
    expect(
      () => buildReport(demo().summary(month), skip: 8),
      throwsFormatException,
    );
    expect(
      () => buildReport(demo().summary(month), weeks: 0),
      throwsFormatException,
    );
  });
}
