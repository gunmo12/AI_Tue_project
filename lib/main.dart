import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'domain.dart';
import 'repository.dart';
import 'design.dart';
part 'editors.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: bg,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const SpendingApp());
}

class SpendingApp extends StatelessWidget {
  final SpendingRepository? repository;
  final DateTime? clock;
  const SpendingApp({super.key, this.repository, this.clock});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: '소비 어시스턴트',
    debugShowCheckedModeBanner: false,
    locale: const Locale('ko'),
    supportedLocales: const [Locale('ko'), Locale('en')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: purple,
        surface: Colors.white,
      ),
      scaffoldBackgroundColor: bg,
      textTheme: ThemeData.light().textTheme.apply(
        bodyColor: ink,
        displayColor: ink,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: track),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: purple,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 44),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xff30263f),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    home: LedgerScreen(repository: repository, clock: clock),
  );
}

class LedgerScreen extends StatefulWidget {
  final SpendingRepository? repository;
  final DateTime? clock;
  const LedgerScreen({super.key, this.repository, this.clock});
  @override
  State<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends State<LedgerScreen> {
  SpendingRepository? repo;
  Ledger? ledger;
  String? error;
  late DateTime month;
  int tab = 0, analysis = 0, week = 0;
  bool saving = false;
  String categoryFilter = '', query = '';
  int? selectedDay;
  final searchController = TextEditingController();
  final scroll = ScrollController();
  MonthSummary get summary => ledger!.summary(month);
  void update(VoidCallback action) => setState(action);
  @override
  void initState() {
    super.initState();
    month = shiftMonth(widget.clock ?? DateTime.now(), 0);
    initialize();
  }

  Future<void> initialize() async {
    try {
      repo =
          widget.repository ??
          await SpendingRepository.open(clock: widget.clock);
      await reload();
    } catch (_) {
      if (mounted) setState(() => error = '저장소를 열지 못했어요. 앱을 다시 실행해 주세요.');
    }
  }

  Future<void> reload() async {
    final value = await repo!.load();
    if (mounted) {
      setState(() {
        ledger = value;
        error = null;
      });
    }
  }

  void notice(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
  Future<bool> commit(Future<void> Function() action, String message) async {
    if (saving) return false;
    setState(() => saving = true);
    try {
      await action();
      await reload();
      if (mounted) notice(message);
      return true;
    } catch (e) {
      if (mounted) {
        notice(
          e is FormatException ? e.message : '저장하지 못했어요. 잠시 후 다시 시도해 주세요.',
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  void go(int i) {
    setState(() {
      tab = i;
      categoryFilter = '';
      query = '';
      searchController.clear();
      selectedDay = null;
    });
    if (scroll.hasClients) scroll.jumpTo(0);
  }

  void moveMonth(int by) {
    final next = shiftMonth(month, by);
    if (next.year < 1900 || next.year > 2100) return;
    setState(() {
      month = next;
      week = 0;
      selectedDay = null;
    });
  }

  void filterCategory(String c) => setState(() {
    tab = 1;
    analysis = 1;
    categoryFilter = c;
    query = '';
    searchController.clear();
  });
  @override
  void dispose() {
    searchController.dispose();
    scroll.dispose();
    if (widget.repository == null) repo?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: tab == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) go(0);
      },
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: ledger == null
                  ? Center(
                      child: error == null
                          ? const CircularProgressIndicator()
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(error!),
                                TextButton(
                                  onPressed: initialize,
                                  child: const Text('다시 시도'),
                                ),
                              ],
                            ),
                    )
                  : Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              txt('나의 소비 어시스턴트', size: 10),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.circle,
                                    color: Color(0xff35bd96),
                                    size: 5,
                                  ),
                                  const SizedBox(width: 5),
                                  txt('기기에 저장', size: 10),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView(
                            key: const ValueKey('page-scroll'),
                            controller: scroll,
                            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                            children: switch (tab) {
                              0 => home(),
                              1 => analysisPage(),
                              2 => reportPage(),
                              3 => budgetPage(),
                              _ => settingsPage(),
                            },
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Container(
            color: Colors.white,
            child: Center(
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  child: Row(children: List.generate(5, navItem)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget navItem(int i) => Expanded(
    child: Semantics(
      selected: tab == i,
      button: true,
      label: ['홈', '분석', '리포트', '예산', '설정'][i],
      child: InkWell(
        key: ValueKey('nav-$i'),
        onTap: () => go(i),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FigIcon(
              i == 0
                  ? (tab == i ? 'imgGroup8' : 'imgGroup4')
                  : i == 1
                  ? (tab == i ? 'imgGroup7' : 'imgGroup3')
                  : i == 2
                  ? (tab == i ? 'imgGroup6' : 'imgGroup2')
                  : i == 3
                  ? (tab == i ? 'imgGroup1' : 'imgGroup5')
                  : 'imgGroup',
            ),
            const SizedBox(height: 4),
            txt(
              ['홈', '분석', '리포트', '예산', '설정'][i],
              size: 10,
              color: tab == i ? purple : muted,
              bold: tab == i,
            ),
          ],
        ),
      ),
    ),
  );
  Widget monthPicker() => panel(
    Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          tooltip: '이전 달',
          onPressed: () => moveMonth(-1),
          icon: const Icon(Icons.chevron_left, size: 20, color: muted),
        ),
        TextButton(
          onPressed: pickMonth,
          child: txt(
            '${month.year}년 ${month.month}월 ⌄',
            size: 14,
            color: ink,
            bold: true,
          ),
        ),
        IconButton(
          tooltip: '다음 달',
          onPressed: () => moveMonth(1),
          icon: const Icon(Icons.chevron_right, size: 20, color: muted),
        ),
      ],
    ),
    padding: const EdgeInsets.symmetric(horizontal: 4),
  );
  Widget metric(
    String title,
    String value,
    String asset,
    Color color, {
    Color text = ink,
  }) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(17),
      ),
      child: Column(
        children: [
          FigIcon(asset),
          const SizedBox(height: 5),
          txt(title, size: 11, color: ink),
          const SizedBox(height: 3),
          FittedBox(child: txt(value, size: 16, color: text, bold: true)),
        ],
      ),
    ),
  );
  List<Widget> home() => [
    heading('안녕하세요, ${ledger!.name}님 👋', '오늘도 현명한 소비, 잘 관리하고 있어요!'),
    monthPicker(),
    Row(
      children: [
        metric(
          '총 지출',
          won(summary.total),
          'imgGroup9',
          const Color(0xfff4edff),
        ),
        const SizedBox(width: 10),
        metric(
          '남은 예산',
          won(summary.remaining),
          'imgGroup10',
          const Color(0xfffff5f5),
          text: (summary.remaining ?? 0) < 0 ? red : ink,
        ),
        const SizedBox(width: 10),
        metric(
          '예산 사용률',
          percent(summary.usage),
          'imgGroup11',
          const Color(0xffeefaf6),
          text: green,
        ),
      ],
    ),
    const SizedBox(height: 14),
    Row(
      children: [
        Expanded(
          child: FilledButton(
            key: const ValueKey('add-expense'),
            onPressed: saving ? null : () => editExpense(),
            child: const Text('＋ 지출 기록하기'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FilledButton.tonal(
            onPressed: () => go(3),
            child: const Text('예산 확인하기', style: TextStyle(fontSize: 12)),
          ),
        ),
      ],
    ),
    const SizedBox(height: 14),
    donutCard(),
    weeklyCard(),
    expenseList(),
    if (ledger!.demo)
      txt('가상 예시 데이터가 포함돼요. 설정에서 초기화한 뒤 실제 지출을 기록할 수 있어요.', size: 10),
  ];
  Widget donutCard() => panel(
    Column(
      children: [
        section('지출 카테고리', action: txt('${monthKey(month)} 기준', size: 10)),
        LayoutBuilder(
          builder: (ctx, box) {
            final size = math.min(164.0, box.maxWidth * .53);
            return Row(
              children: [
                SizedBox(
                  width: size,
                  height: size,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: Size.square(size),
                        painter: DonutPainter(
                          summary.categoryTotals.map((c) => c.spent).toList(),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          txt('총 지출', color: ink),
                          FittedBox(
                            child: txt(
                              won(summary.total),
                              size: 16,
                              color: ink,
                              bold: true,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    children: List.generate(6, (i) {
                      final c = summary.categoryTotals[i];
                      return InkWell(
                        onTap: () => filterCategory(c.name),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: palette[i],
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              txt(c.name, size: 11, color: ink),
                              const Spacer(),
                              txt(
                                percent(c.share),
                                size: 10,
                                color: ink,
                                bold: true,
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    ),
  );
  Widget weeklyCard() {
    final days = summary.daily.skip(week * 7).take(7).toList();
    return panel(
      Column(
        children: [
          section(
            '주간 지출 추이',
            action: txt('합계 ${won(days.fold<int>(0, (n, v) => n + v))}', size: 10),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                tooltip: '이전 주',
                onPressed: week > 0 ? () => setState(() => week--) : null,
                icon: const Icon(Icons.chevron_left, size: 18),
              ),
              txt(
                '${month.month}월 ${week * 7 + 1}~${week * 7 + days.length}일',
                size: 11,
              ),
              IconButton(
                tooltip: '다음 주',
                onPressed: week < (summary.days - 1) ~/ 7
                    ? () => setState(() => week++)
                    : null,
                icon: const Icon(Icons.chevron_right, size: 18),
              ),
            ],
          ),
          SizedBox(
            height: 150,
            width: double.infinity,
            child: CustomPaint(painter: TrendPainter(days)),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(
              days.length,
              (i) => txt('${week * 7 + i + 1}일', size: 10),
            ),
          ),
          const SizedBox(height: 8),
          txt('선택한 7일 구간의 실제 지출 합계입니다.', size: 10),
        ],
      ),
    );
  }

  Widget expenseList({
    List<Expense>? records,
    bool filters = true,
    String title = '지출 내역',
  }) {
    final rows = (records ?? summary.expenses)
        .where(
          (r) =>
              (!filters ||
                  categoryFilter.isEmpty ||
                  r.category == categoryFilter) &&
              (!filters ||
                  query.isEmpty ||
                  '${r.merchant} ${r.memo}'.toLowerCase().contains(
                    query.toLowerCase(),
                  )),
        )
        .toList();
    return panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          section(
            title,
            action: Row(
              children: [
                txt('${rows.length}건', size: 10),
                const SizedBox(width: 8),
                smallButton('＋ 추가', () => editExpense()),
              ],
            ),
          ),
          if (filters) ...[
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('search-expenses'),
                    controller: searchController,
                    decoration: const InputDecoration(
                      hintText: '사용처·메모 검색',
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 12),
                    onChanged: (v) => setState(() => query = v),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 100,
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('filter-$categoryFilter'),
                    initialValue: categoryFilter,
                    decoration: const InputDecoration(isDense: true),
                    style: const TextStyle(fontSize: 12, color: ink),
                    items: ['', ...categories]
                        .map(
                          (c) => DropdownMenuItem(
                            value: c,
                            child: Text(c.isEmpty ? '전체 항목' : c),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => categoryFilter = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(child: txt('조건에 맞는 지출이 없어요.\n새 지출을 기록해 보세요.')),
            ),
          ...rows.map(
            (r) => InkWell(
              key: ValueKey('expense-${r.id}'),
              onTap: () => editExpense(expense: r),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xfff2edf9))),
                ),
                child: Row(
                  children: [
                    categoryIcon(categories.indexOf(r.category)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          txt(r.merchant, size: 12, color: ink, bold: true),
                          txt(
                            '${r.date.substring(5).replaceAll('-', '.')} · ${r.category}${r.recurring ? ' · 반복' : ''}',
                            size: 10,
                          ),
                          if (r.memo.isNotEmpty) txt(r.memo, size: 10),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        txt(won(r.amount), size: 12, color: ink, bold: true),
                        txt('수정 ›', size: 10),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> analysisPage() => [
    heading('소비 분석', '이번 달 지출 패턴을 자세히 살펴보세요.', icon: 'imgGroup7'),
    monthPicker(),
    Row(
      children: List.generate(
        3,
        (i) => Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < 2 ? 7 : 0),
            child: ChoiceChip(
              label: Text(
                ['지출 패턴', '카테고리 분석', '소비 트렌드'][i],
                style: TextStyle(
                  fontSize: 10,
                  color: analysis == i ? Colors.white : muted,
                ),
              ),
              showCheckmark: false,
              selected: analysis == i,
              selectedColor: purple,
              backgroundColor: track,
              side: BorderSide.none,
              padding: const EdgeInsets.symmetric(horizontal: 1),
              onSelected: (_) => setState(() => analysis = i),
            ),
          ),
        ),
      ),
    ),
    const SizedBox(height: 14),
    if (analysis != 2) categoryCard(),
    if (analysis == 1) expenseList() else historyCard(),
    if (analysis == 2) weeklyCard(),
  ];
  Widget categoryCard() => panel(
    Column(
      children: [
        section('카테고리별 지출 현황', action: txt(monthKey(month), size: 10)),
        ...List.generate(6, (i) {
          final c = summary.categoryTotals[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: InkWell(
              onTap: () => filterCategory(c.name),
              child: Row(
                children: [
                  categoryIcon(i),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            txt(c.name, size: 13, color: ink, bold: true),
                            txt(won(c.spent), size: 13, color: ink, bold: true),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Expanded(
                              child: progress(c.share, color: palette[i]),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 36,
                              child: txt(percent(c.share), size: 10),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    ),
  );
  Widget historyCard() {
    final values = List.generate(
      4,
      (i) => ledger!.summary(shiftMonth(month, i - 3)),
    );
    final max = values.fold(1, (n, s) => math.max(n, s.total));
    return panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          section('월별 지출 비교', action: txt('저장된 내역 기준', size: 10)),
          SizedBox(
            height: 165,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(4, (i) {
                final s = values[i];
                return Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      txt(
                        s.expenses.isEmpty
                            ? '기록 없음'
                            : '${(s.total / 10000).toStringAsFixed(1)}만',
                        size: 10,
                      ),
                      const SizedBox(height: 5),
                      Container(
                        width: 30,
                        height: s.total / max * 110,
                        decoration: BoxDecoration(
                          color: i == 3 ? palette[0] : const Color(0xffddd1fb),
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                      const SizedBox(height: 10),
                      txt('${s.month.month}월', size: 11),
                    ],
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 14),
          txt(
            summary.comparable
                ? '${summary.delta! > 0 ? '↑' : '↓'} 지난달 대비 ${percent(summary.change!.abs())} ${summary.delta! > 0
                      ? '증가'
                      : summary.delta! < 0
                      ? '감소'
                      : '변화 없음'} (${won(summary.delta)})'
                : '이전 달 비교 자료가 부족해 증감률을 계산하지 않아요.',
            size: 11,
            color: summary.comparable
                ? (summary.delta! > 0 ? red : green)
                : muted,
            bold: true,
          ),
          const SizedBox(height: 10),
          txt('각 달 1일~말일까지 저장된 전체 내역 비교\n월말 예상액이나 같은 경과일 비교가 아닙니다.', size: 10),
        ],
      ),
    );
  }

  List<Widget> reportPage() {
    final r = ledger!.reports[monthKey(month)];
    return [
      heading('소비 리포트', '내 지출에서 찾는 인사이트와 절약 계획', icon: 'imgGroup6'),
      monthPicker(),
      panel(
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xffece4ff),
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xff51428d),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Text(
                  '••',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    letterSpacing: 3,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  txt(
                    '${ledger!.name}님, 저장된 소비를 살펴볼까요?',
                    size: 12,
                    color: ink,
                    bold: true,
                  ),
                  txt('계산 기반 리포트 · AI API 미연결', size: 10),
                ],
              ),
            ),
          ],
        ),
      ),
      if (r == null)
        panel(
          Column(
            children: [
              const SizedBox(height: 12),
              const FigIcon('imgGroup6'),
              const SizedBox(height: 14),
              txt('이번 달 리포트를 만들어 보세요', color: ink, bold: true),
              const SizedBox(height: 12),
              txt('항목별 비중과 비교, 예산 사용 현황을\n한 번에 정리해요.'),
              const SizedBox(height: 18),
              FilledButton(
                key: const ValueKey('generate-report'),
                onPressed: saving ? null : () => generateReport(),
                child: const Text('소비 리포트 생성하기'),
              ),
              const SizedBox(height: 10),
            ],
          ),
        )
      else ...[
        if (r['signature'] != summary.signature)
          panel(
            txt(
              '지출 또는 예산이 바뀌었어요.\n리포트를 다시 생성해 주세요.',
              color: const Color(0xff8d641f),
            ),
            color: const Color(0xfffff6e9),
          ),
        section(
          '이번 달 핵심 인사이트',
          action: smallButton(
            '다시 생성 ↻',
            saving ? null : () => generateReport(),
          ),
        ),
        ...List.generate((r['insights'] as List).length, (i) {
          final v = r['insights'][i];
          return panel(
            Row(
              children: [
                FigIcon(['imgGroup17', 'imgGroup18', 'imgGroup19'][i], box: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      txt(v['title'], size: 12, color: ink, bold: true),
                      const SizedBox(height: 5),
                      txt(
                        v['body'],
                        size: 11,
                        color: i == 0
                            ? purple
                            : i == 1
                            ? green
                            : const Color(0xffbb791a),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
        panel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              txt('✦ 나의 절약 시뮬레이션', size: 11, color: purple, bold: true),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: txt(
                      (r['available'] as int) > 0
                          ? '카페 이용 ${r['count']}회를 줄이면\n${won(r['savings'])} 절약 예상'
                          : '카페 내역을 추가하면\n절약 금액을 계산해 드려요.',
                      size: 16,
                      color: ink,
                      bold: true,
                    ),
                  ),
                  const FigIcon('imgGroup20', box: 38),
                ],
              ),
              const SizedBox(height: 10),
              txt(
                '평균 단가 ${won(r['unit'])} × ${r['count']}회\n주 ${r['skip']}회 × ${r['weeks']}주 가정 · 기록된 ${r['available']}회 이내',
                size: 11,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: saving ? null : () => planDialog(r),
                  child: const Text('절약 플랜 조정하기 ›'),
                ),
              ),
            ],
          ),
          color: const Color(0xffece3ff),
        ),
        panel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              section('반복 결제 점검'),
              txt(
                '직접 표시한 ${r['recurringCount']}건 · ${won(r['recurringTotal'])}',
              ),
              const SizedBox(height: 8),
              txt(
                '기록만으로 불필요한 구독을 판단하지 않아요. 사용 빈도를 확인한 뒤 유지 여부를 결정하세요.',
                size: 11,
              ),
              smallButton('반복 결제 내역 보기 ›', recurringDialog),
            ],
          ),
        ),
        txt(
          '생성: ${DateTime.parse(r['generated']).toLocal().toString().substring(0, 19)} (기기 시간)\n분석: ${monthKey(month)}-01 ~ ${monthKey(month)}-${summary.days}\n각 달 전체 기록 비교 · 실제 LLM이 아닌 집계 규칙 기반입니다.',
          size: 10,
        ),
      ],
    ];
  }

  Future<void> generateReport({int skip = 2, int weeks = 4}) async {
    await commit(
      () => repo!.saveReport(
        month,
        buildReport(summary, skip: skip, weeks: weeks),
      ),
      '계산한 리포트를 저장했어요.',
    );
  }

  void recurringDialog() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: expenseList(
          records: summary.expenses.where((r) => r.recurring).toList(),
          filters: false,
          title: '직접 표시한 반복 결제',
        ),
      ),
    ),
  );
  List<Widget> budgetPage() => [
    heading('예산 관리', '카테고리별 예산을 설정하고 사용 현황을 관리해요.', icon: 'imgGroup1'),
    monthPicker(),
    panel(
      Column(
        children: [
          Row(
            children: [
              const FigIcon('imgGroup10'),
              const SizedBox(width: 10),
              ...['전체 예산', '사용 금액', '사용률'].asMap().entries.map(
                (e) => Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      txt(e.value, size: 10),
                      FittedBox(
                        child: txt(
                          [
                            won(
                              summary.budget.total == 0
                                  ? null
                                  : summary.budget.total,
                            ),
                            won(summary.total),
                            percent(summary.usage),
                          ][e.key],
                          size: 13,
                          color: e.key == 2 ? purple : ink,
                          bold: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          progress(summary.usage),
          if (summary.usage == null) smallButton('이번 달 예산 설정하기 ›', editBudget),
          if ((summary.remaining ?? 0) < 0)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: txt(
                '전체 예산을 ${won(-summary.remaining!)} 초과했어요.',
                color: red,
              ),
            ),
        ],
      ),
    ),
    section('카테고리별 예산 현황', action: smallButton('✎ 예산 조정', editBudget)),
    ...List.generate(6, (i) {
      final c = summary.categoryTotals[i];
      return panel(
        InkWell(
          onTap: editBudget,
          child: Row(
            children: [
              categoryIcon(i, budget: true),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        txt(c.name, size: 13, color: ink, bold: true),
                        txt(
                          c.status == '미설정'
                              ? '설정하기 ›'
                              : c.status == '여유'
                              ? '여유 ›'
                              : '! 예산 ${c.status}',
                          size: 10,
                          color: c.status == '초과'
                              ? red
                              : c.status == '주의'
                              ? const Color(0xffbb791a)
                              : muted,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        txt(
                          '${won(c.spent)} / ${won(c.limit == 0 ? null : c.limit)}',
                          size: 11,
                          color: ink,
                        ),
                        txt(percent(c.usage), size: 10),
                      ],
                    ),
                    const SizedBox(height: 5),
                    progress(
                      c.usage,
                      color: c.status == '초과' ? red : palette[i],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      );
    }),
    calendarCard(),
    txt(
      '90% 이상은 주의, 100% 초과는 초과로 표시해요.\n항목별 예산은 전체 예산과 따로 관리하는 독립 한도입니다.',
      size: 10,
    ),
  ];
  Widget calendarCard() {
    final offset = (DateTime(month.year, month.month).weekday - 1) % 7;
    return panel(
      Column(
        children: [
          section('이번 달 지출 플래너', action: txt('● 지출  ● 주의', size: 10)),
          Row(
            children: ['월', '화', '수', '목', '금', '토', '일']
                .map((d) => Expanded(child: Center(child: txt(d, size: 10))))
                .toList(),
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: offset + summary.days,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 3,
              crossAxisSpacing: 3,
            ),
            itemBuilder: (ctx, index) {
              if (index < offset) return const SizedBox();
              final day = index - offset + 1;
              final rows = summary.expenses.where(
                (r) => int.parse(r.date.substring(8)) == day,
              );
              final warn = rows.any((r) {
                final c = summary.categoryTotals.firstWhere(
                  (c) => c.name == r.category,
                );
                return c.status == '주의' || c.status == '초과';
              });
              return InkWell(
                key: ValueKey('calendar-$day'),
                borderRadius: BorderRadius.circular(16),
                onTap: () => setState(
                  () => selectedDay = selectedDay == day ? null : day,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: selectedDay == day ? purple : null,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      txt(
                        '$day',
                        color: selectedDay == day ? Colors.white : ink,
                      ),
                      if (rows.isNotEmpty)
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: selectedDay == day
                                ? Colors.white
                                : warn
                                ? const Color(0xffeea33b)
                                : purple,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          if (selectedDay != null) ...[
            const Divider(color: track),
            section(
              '${month.month}월 $selectedDay일 지출',
              action: smallButton(
                '＋ 추가',
                () => editExpense(
                  date: DateTime(month.year, month.month, selectedDay!),
                ),
              ),
            ),
            ...summary.expenses
                .where((r) => int.parse(r.date.substring(8)) == selectedDay)
                .map(
                  (r) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      r.merchant,
                      style: const TextStyle(fontSize: 12),
                    ),
                    subtitle: Text(
                      r.category,
                      style: const TextStyle(fontSize: 10),
                    ),
                    trailing: Text(won(r.amount)),
                    onTap: () => editExpense(expense: r),
                  ),
                ),
            if (!summary.expenses.any(
              (r) => int.parse(r.date.substring(8)) == selectedDay,
            ))
              txt('이 날의 지출이 없어요.'),
          ],
          const SizedBox(height: 10),
          txt('날짜를 눌러 내역을 확인하세요. 주의는 해당 항목의 월 예산 사용률 90% 이상을 의미합니다.', size: 10),
        ],
      ),
    );
  }

  List<Widget> settingsPage() => [
    heading('설정', '나에게 맞게, 내 기기에 안전하게', icon: 'imgGroup'),
    panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          section('내 프로필', action: smallButton('이름 변경', editName)),
          txt('${ledger!.name}님', color: ink),
        ],
      ),
    ),
    panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          section('데이터 관리'),
          txt('지출과 예산은 휴대폰 안의 SQLite에 저장돼요. 앱을 완전히 종료해도 유지됩니다.'),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: exportCsv,
              child: const Text('선택한 월의 CSV 내보내기'),
            ),
          ),
          const SizedBox(height: 8),
          txt(
            '휴대폰의 파일 저장 창에서 위치를 고르면 CSV를 저장해요. 앱을 삭제하면 저장된 내역도 지워집니다.',
            size: 11,
          ),
        ],
      ),
    ),
    panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          section('프로토타입 안내'),
          txt('Flutter로 만든 안드로이드 앱입니다. 인터넷이나 PC 서버 없이 사용할 수 있어요.'),
          const SizedBox(height: 10),
          txt('계산 기반 리포트 · AI API 미연결', size: 11, color: purple, bold: true),
          const SizedBox(height: 10),
          txt(
            '계좌·카드번호와 소득 정보를 수집하지 않아 저축률은 표시하지 않습니다. 반복 결제는 직접 확인한 기록만 사용합니다.',
            size: 11,
          ),
        ],
      ),
    ),
    panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          section(ledger!.demo ? '예시 데이터로 시작했어요' : '모든 데이터 초기화'),
          txt(
            ledger!.demo
                ? '현재 월 862,000원 및 지난달 비교용 가상 예시가 포함돼요. 월말까지의 가상 날짜가 있을 수 있어요. 실제 기록을 시작하려면 초기화하세요.'
                : '모든 월의 지출·예산·리포트를 삭제합니다. 이름은 유지됩니다.',
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: saving ? null : clearDialog,
            style: OutlinedButton.styleFrom(foregroundColor: red),
            child: const Text('모든 내역 초기화'),
          ),
        ],
      ),
    ),
    txt(
      '소비 어시스턴트 Android V1 · 개인용 프로토타입\n디자인: 사용자 제공 Figma · 데이터: 사용자 입력 / 가상 예시',
      size: 10,
    ),
  ];
}
