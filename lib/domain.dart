import 'dart:convert';
import 'dart:math';

import 'package:intl/intl.dart';

const categories = ['식비', '교통', '쇼핑', '구독', '카페', '기타'];
String won(int? value) =>
    value == null ? '미설정' : '${NumberFormat('#,###').format(value)}원';
String percent(double? value) =>
    value == null ? '미설정' : '${value.toStringAsFixed(1)}%';
String monthKey(DateTime date) => DateFormat('yyyy-MM').format(date);
String dayKey(DateTime date) => DateFormat('yyyy-MM-dd').format(date);
DateTime shiftMonth(DateTime date, int by) =>
    DateTime(date.year, date.month + by);
String budgetStatus(int spent, int limit) => limit == 0
    ? '미설정'
    : spent > limit
    ? '초과'
    : spent * 10 >= limit * 9
    ? '주의'
    : '여유';
int validAmount(String value, {bool allowZero = false}) {
  final clean = value.trim();
  if (!RegExp(r'^\d+$').hasMatch(clean)) {
    throw const FormatException('금액은 원 단위 정수로 입력해 주세요.');
  }
  final amount = int.tryParse(clean);
  if (amount == null || amount < (allowZero ? 0 : 1) || amount > 1000000000) {
    throw FormatException(
      '${allowZero ? '0' : '1'}~1,000,000,000원 사이로 입력해 주세요.',
    );
  }
  return amount;
}

class Expense {
  final int? id;
  final String date, category, merchant, memo;
  final int amount;
  final bool recurring;
  const Expense({
    this.id,
    required this.date,
    required this.amount,
    required this.category,
    required this.merchant,
    this.memo = '',
    this.recurring = false,
  });
  void validate() {
    validAmount(amount.toString());
    if (!categories.contains(category)) {
      throw const FormatException('항목을 선택해 주세요.');
    }
    final parsed = DateTime.tryParse(date);
    if (parsed == null || dayKey(parsed) != date) {
      throw const FormatException('날짜를 확인해 주세요.');
    }
    if (merchant.trim().isEmpty || merchant.length > 80) {
      throw const FormatException('사용처는 1~80자로 입력해 주세요.');
    }
    if (memo.length > 300) throw const FormatException('메모는 300자 이내로 입력해 주세요.');
  }

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'date': date,
    'amount': amount,
    'category': category,
    'merchant': merchant.trim(),
    'memo': memo.trim(),
    'recurring': recurring ? 1 : 0,
  };
  factory Expense.fromMap(Map<String, Object?> m) => Expense(
    id: m['id'] as int?,
    date: m['date'] as String,
    amount: m['amount'] as int,
    category: m['category'] as String,
    merchant: m['merchant'] as String,
    memo: m['memo'] as String,
    recurring: m['recurring'] == 1,
  );
}

class Budget {
  final int total;
  final Map<String, int> limits;
  const Budget({this.total = 0, this.limits = const {}});
  void validate() {
    validAmount(total.toString(), allowZero: true);
    for (final entry in limits.entries) {
      if (!categories.contains(entry.key)) {
        throw const FormatException('예산 항목을 확인해 주세요.');
      }
      validAmount(entry.value.toString(), allowZero: true);
    }
  }

  Map<String, Object?> toMap() => {'total': total, 'limits': limits};
  factory Budget.fromMap(Map<String, dynamic> m) => Budget(
    total: m['total'] as int,
    limits: Map<String, int>.from(m['limits'] as Map),
  );
}

class CategoryTotal {
  final String name;
  final int spent, limit, total;
  const CategoryTotal(this.name, this.spent, this.limit, this.total);
  double get share => total == 0 ? 0 : spent / total * 100;
  double? get usage => limit == 0 ? null : spent / limit * 100;
  String get status => budgetStatus(spent, limit);
}

class MonthSummary {
  final DateTime month;
  final List<Expense> expenses, previous;
  final Budget budget;
  MonthSummary(this.month, this.expenses, this.previous, this.budget);
  int get total => expenses.fold(0, (sum, r) => sum + r.amount);
  int get previousTotal => previous.fold(0, (sum, r) => sum + r.amount);
  int? get remaining => budget.total == 0 ? null : budget.total - total;
  double? get usage => budget.total == 0 ? null : total / budget.total * 100;
  String get status => budgetStatus(total, budget.total);
  bool get comparable => expenses.isNotEmpty && previousTotal > 0;
  int? get delta => comparable ? total - previousTotal : null;
  double? get change =>
      comparable ? (total - previousTotal) / previousTotal * 100 : null;
  List<CategoryTotal> get categoryTotals => categories
      .map(
        (c) => CategoryTotal(
          c,
          expenses
              .where((e) => e.category == c)
              .fold(0, (s, e) => s + e.amount),
          budget.limits[c] ?? 0,
          total,
        ),
      )
      .toList();
  int get days => DateTime(month.year, month.month + 1, 0).day;
  List<int> get daily => List.generate(
    days,
    (i) => expenses
        .where((r) => r.date.endsWith('-${(i + 1).toString().padLeft(2, '0')}'))
        .fold(0, (sum, r) => sum + r.amount),
  );
  String get signature =>
      jsonEncode([expenses.map((r) => r.toMap()).toList(), budget.toMap()]);
}

class Ledger {
  final List<Expense> expenses;
  final Map<String, Budget> budgets;
  final Map<String, Map<String, dynamic>> reports;
  final String name;
  final bool demo;
  const Ledger({
    this.expenses = const [],
    this.budgets = const {},
    this.reports = const {},
    this.name = '반석',
    this.demo = true,
  });
  MonthSummary summary(DateTime month) => MonthSummary(
    month,
    expenses.where((r) => r.date.startsWith(monthKey(month))).toList(),
    expenses
        .where((r) => r.date.startsWith(monthKey(shiftMonth(month, -1))))
        .toList(),
    budgets[monthKey(month)] ?? const Budget(),
  );
}

Map<String, dynamic> buildReport(
  MonthSummary s, {
  int skip = 2,
  int weeks = 4,
  DateTime? now,
}) {
  if (skip < 0 || skip > 7 || weeks < 1 || weeks > 5) {
    throw const FormatException('주당 0~7회, 1~5주를 선택해 주세요.');
  }
  final cafe = s.expenses.where((r) => r.category == '카페').toList();
  final unit = cafe.isEmpty
      ? 0
      : (cafe.fold(0, (n, r) => n + r.amount) / cafe.length).round();
  final count = (skip * weeks).clamp(0, cafe.length);
  final sorted = [...s.categoryTotals]
    ..sort((a, b) => b.spent.compareTo(a.spent));
  final top = sorted.first;
  final recurring = s.expenses.where((r) => r.recurring).toList();
  return {
    'signature': s.signature,
    'generated': (now ?? DateTime.now()).toIso8601String(),
    'insights': [
      {
        'title': s.expenses.isEmpty
            ? '아직 분석할 지출이 없어요.'
            : '가장 큰 지출은 ${top.name}예요.',
        'body': s.expenses.isEmpty
            ? '지출을 기록하면 실제 내역을 분석해 드려요.'
            : '${won(top.spent)} · 전체 지출의 ${percent(top.share)}를 차지해요.',
      },
      {
        'title': s.comparable
            ? '${monthKey(shiftMonth(s.month, -1))} 대비 ${percent(s.change!.abs())} ${s.delta! > 0
                  ? '증가'
                  : s.delta! < 0
                  ? '감소'
                  : '동일'}'
            : '이전 기간 비교 자료가 부족해요.',
        'body': s.comparable
            ? '${won(s.previousTotal)} → ${won(s.total)} · 차이 ${won(s.delta)}'
            : '지난달의 비교 가능한 기록이 없어 증감률을 만들지 않아요.',
      },
      {
        'title': s.usage == null
            ? '이번 달 예산을 설정해 주세요.'
            : '예산 사용률 ${percent(s.usage)} · ${s.status}',
        'body': s.remaining == null
            ? '예산이 없어서 잔여 금액과 사용률을 계산할 수 없어요.'
            : '전체 예산 ${won(s.budget.total)} 중 ${won(s.total)} 사용 · ${won(s.remaining!.abs())} ${s.remaining! < 0 ? '초과' : '남음'}',
      },
    ],
    'unit': unit,
    'skip': skip,
    'weeks': weeks,
    'count': count,
    'available': cafe.length,
    'savings': unit * count,
    'recurringCount': recurring.length,
    'recurringTotal': recurring.fold(0, (n, r) => n + r.amount),
  };
}

List<Expense> demoExpenses(DateTime month) {
  final groups = <String, List<int>>{
    '식비': [35000, 28000, 42000, 23000, 37000, 45000, 32000, 38000],
    '교통': [55000, 15000, 12000, 18000],
    '쇼핑': [89000, 45000, 56000],
    '구독': [14900, 10900, 9900, 43500],
    '카페': [5800, 6200, 5500, 6000, 5900, 5800, 6200, 5500, 6000, 5900],
    '기타': [54000, 30000, 40000, 30000],
  };
  final names = ['식당', '교통 이용', '쇼핑몰', '구독 서비스', '카페', '생활 지출'];
  final records = <Expense>[];
  for (var c = 0; c < categories.length; c++) {
    final values = groups[categories[c]]!;
    for (var i = 0; i < values.length; i++) {
      records.add(
        Expense(
          date: dayKey(
            DateTime(month.year, month.month, 1 + ((i * 3 + c * 2) % 28)),
          ),
          amount: values[i],
          category: categories[c],
          merchant: '${names[c]} ${i + 1}',
          memo: '가상 예시 데이터',
          recurring: c == 3,
        ),
      );
    }
  }
  final prev = shiftMonth(month, -1);
  const amounts = [300000, 100000, 200000, 79200, 51800, 194000];
  for (var i = 0; i < categories.length; i++) {
    records.add(
      Expense(
        date: dayKey(DateTime(prev.year, prev.month, 15)),
        amount: amounts[i],
        category: categories[i],
        merchant: '지난달 예시',
        memo: '월별 비교용 가상 데이터',
      ),
    );
  }
  return records;
}

enum PrototypeSpending {
  everyday('일상 소비형', '식비, 교통, 카페 지출이 고르게 섞인 달', [1, 1, 0.65, 0.8, 1.2, 0.7]),
  saving('절약 실천형', '필수 생활비 위주로 쓰고 카페와 쇼핑을 줄인 달', [
    0.65,
    0.85,
    0.35,
    0.5,
    0.4,
    0.45,
  ]),
  shopping('쇼핑 집중형', '쇼핑과 여가 지출이 큰 달', [1.1, 0.85, 2.7, 1, 1.4, 1.2]);

  const PrototypeSpending(this.title, this.description, this.weights);
  final String title, description;
  final List<double> weights;

  List<Expense> records(DateTime month) {
    final random = Random(month.year * 1000 + month.month * 10 + index);
    final days = DateTime(month.year, month.month + 1, 0).day;
    return [
      for (final item in demoExpenses(
        month,
      ).where((e) => e.date.startsWith(monthKey(month))))
        Expense(
          date: dayKey(
            DateTime(month.year, month.month, random.nextInt(days) + 1),
          ),
          amount:
              (item.amount *
                      weights[categories.indexOf(item.category)] *
                      (0.8 + random.nextDouble() * 0.4) /
                      100)
                  .round() *
              100,
          category: item.category,
          merchant: '[예시] ${item.merchant}',
          memo: title,
          recurring: item.recurring,
        ),
    ];
  }
}

Budget get demoBudget => const Budget(
  total: 1100000,
  limits: {
    '식비': 350000,
    '교통': 150000,
    '쇼핑': 200000,
    '구독': 100000,
    '카페': 100000,
    '기타': 200000,
  },
);
