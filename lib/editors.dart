part of 'main.dart';

extension _Editors on _LedgerScreenState {
  Future<void> pickMonth() async {
    var year = month.year, m = month.month;
    final chosen = await showDialog<DateTime>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: const Text('조회 월 선택'),
          content: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: year,
                  items: List.generate(
                    201,
                    (i) => DropdownMenuItem(
                      value: 1900 + i,
                      child: Text('${1900 + i}년'),
                    ),
                  ),
                  onChanged: (v) => set(() => year = v!),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: m,
                  items: List.generate(
                    12,
                    (i) => DropdownMenuItem(
                      value: i + 1,
                      child: Text('${i + 1}월'),
                    ),
                  ),
                  onChanged: (v) => set(() => m = v!),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, DateTime(year, m)),
              child: const Text('조회'),
            ),
          ],
        ),
      ),
    );
    if (chosen != null && mounted) {
      update(() {
        month = chosen;
        week = 0;
        selectedDay = null;
      });
    }
  }

  Future<void> editExpense({Expense? expense, DateTime? date}) async {
    final now = widget.clock ?? DateTime.now();
    final result = await showModalBottomSheet<Object>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => ExpenseEditor(
        expense: expense,
        date: date ?? (monthKey(now) == monthKey(month) ? now : month),
      ),
    );
    if (result is Expense) {
      final ok = await commit(() => repo!.saveExpense(result), '지출을 저장했어요.');
      if (ok && mounted) {
        update(() {
          month = shiftMonth(DateTime.parse(result.date), 0);
          selectedDay = null;
          week = 0;
        });
      }
    }
    if (result == 'delete' && expense != null) {
      await commit(() => repo!.deleteExpense(expense.id!), '지출을 삭제했어요.');
    }
  }

  Future<void> editBudget() async {
    final selectedMonth = month;
    final result = await showModalBottomSheet<Budget>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) =>
          BudgetEditor(budget: summary.budget, month: selectedMonth),
    );
    if (result != null) {
      await commit(() => repo!.saveBudget(selectedMonth, result), '예산을 저장했어요.');
    }
  }

  Future<void> planDialog(Map<String, dynamic> report) async {
    var skip = report['skip'] as int, weeks = report['weeks'] as int;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: const Text('절약 플랜 조정'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              txt('현재 월 카페 결제의 평균 단가로 계산해요. 횟수는 실제 기록 건수 이내로 제한합니다.'),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: skip,
                decoration: const InputDecoration(labelText: '주당 줄일 횟수'),
                items: List.generate(
                  8,
                  (i) => DropdownMenuItem(value: i, child: Text('주 $i회')),
                ),
                onChanged: (v) => set(() => skip = v!),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<int>(
                initialValue: weeks,
                decoration: const InputDecoration(labelText: '계획 기간'),
                items: List.generate(
                  5,
                  (i) =>
                      DropdownMenuItem(value: i + 1, child: Text('${i + 1}주')),
                ),
                onChanged: (v) => set(() => weeks = v!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('적용'),
            ),
          ],
        ),
      ),
    );
    if (result == true) await generateReport(skip: skip, weeks: weeks);
  }

  Future<void> editName() async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) =>
          TextPrompt(title: '이름 변경', hint: '화면에 표시할 이름', initial: ledger!.name),
    );
    if (result != null) {
      await commit(() => repo!.saveName(result), '이름을 변경했어요.');
    }
  }

  Future<void> clearDialog() async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => const TextPrompt(
        title: '모든 내역을 초기화할까요?',
        hint: '확인하려면 ‘초기화’ 입력',
        description: '모든 월의 지출·예산·리포트를 삭제합니다. 필요한 내역은 먼저 내보내 주세요.',
        confirmation: '초기화',
      ),
    );
    if (result == '초기화') await commit(() => repo!.clear(), '모든 내역을 초기화했어요.');
  }

  Future<void> exportCsv() async {
    String safe(String s) {
      final value = RegExp(r'^[=+@\-\t\r]').hasMatch(s) ? "'$s" : s;
      return '"${value.replaceAll('"', '""')}"';
    }

    final lines = [
      '날짜,금액,항목,사용처,메모,반복 결제',
      ...summary.expenses.map(
        (r) => [
          safe(r.date),
          r.amount,
          safe(r.category),
          safe(r.merchant),
          safe(r.memo),
          r.recurring ? '예' : '아니오',
        ].join(','),
      ),
    ];
    try {
      final result = await const MethodChannel('spending_assistant/files')
          .invokeMethod<bool>('saveCsv', {
            'name': '지출내역_${monthKey(month)}.csv',
            'content': '\ufeff${lines.join('\r\n')}\r\n',
          });
      if (result == true && mounted) notice('CSV 파일을 저장했어요.');
    } catch (_) {
      if (mounted) notice('파일을 저장하지 못했어요. 다른 위치를 선택해 보세요.');
    }
  }
}

Widget amountInput(
  TextEditingController controller,
  String title, {
  bool allowZero = false,
  Key? fieldKey,
}) => TextFormField(
  key: fieldKey,
  controller: controller,
  keyboardType: TextInputType.number,
  decoration: InputDecoration(labelText: title),
  validator: (v) {
    try {
      validAmount(v ?? '', allowZero: allowZero);
      return null;
    } on FormatException catch (e) {
      return e.message;
    }
  },
  autovalidateMode: AutovalidateMode.onUserInteraction,
);
Widget editorLayout(BuildContext context, Widget child) => Padding(
  padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
  child: SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: child,
    ),
  ),
);

class ExpenseEditor extends StatefulWidget {
  final Expense? expense;
  final DateTime date;
  const ExpenseEditor({super.key, this.expense, required this.date});
  @override
  State<ExpenseEditor> createState() => _ExpenseEditorState();
}

class _ExpenseEditorState extends State<ExpenseEditor> {
  final form = GlobalKey<FormState>();
  late TextEditingController amount, merchant, memo;
  late DateTime date;
  late String category;
  late bool recurring;
  @override
  void initState() {
    super.initState();
    final e = widget.expense;
    amount = TextEditingController(text: e == null ? '' : '${e.amount}');
    merchant = TextEditingController(text: e?.merchant ?? '');
    memo = TextEditingController(text: e?.memo ?? '');
    date = e == null ? widget.date : DateTime.parse(e.date);
    category = e?.category ?? '식비';
    recurring = e?.recurring ?? false;
  }

  @override
  void dispose() {
    amount.dispose();
    merchant.dispose();
    memo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => editorLayout(
    context,
    Form(
      key: form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          section(widget.expense == null ? '새 지출 기록' : '지출 수정'),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final value = await showDatePicker(
                      context: context,
                      initialDate: date,
                      firstDate: DateTime(1900),
                      lastDate: DateTime(2100, 12, 31),
                    );
                    if (value != null && mounted) setState(() => date = value);
                  },
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(
                    dayKey(date),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: const ValueKey('expense-category'),
                  initialValue: category,
                  decoration: const InputDecoration(labelText: '항목'),
                  items: categories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setState(() => category = v!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          amountInput(
            amount,
            '금액 (원)',
            fieldKey: const ValueKey('expense-amount'),
          ),
          const SizedBox(height: 16),
          TextFormField(
            key: const ValueKey('expense-merchant'),
            controller: merchant,
            maxLength: 80,
            decoration: const InputDecoration(labelText: '사용처'),
            validator: (v) =>
                v == null || v.trim().isEmpty ? '사용처를 입력해 주세요.' : null,
          ),
          const SizedBox(height: 8),
          TextFormField(
            key: const ValueKey('expense-memo'),
            controller: memo,
            maxLength: 300,
            maxLines: 2,
            decoration: const InputDecoration(labelText: '메모 (선택)'),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('직접 확인한 반복 결제', style: TextStyle(fontSize: 12)),
            value: recurring,
            onChanged: (v) => setState(() => recurring = v!),
          ),
          txt('저장을 누르면 입력한 내용이 확정돼요.', size: 11),
          const SizedBox(height: 16),
          Row(
            children: [
              if (widget.expense != null) ...[
                OutlinedButton(
                  onPressed: delete,
                  child: const Text('삭제', style: TextStyle(color: red)),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: FilledButton(
                  key: const ValueKey('save-expense'),
                  onPressed: () {
                    if (form.currentState!.validate()) {
                      Navigator.pop(
                        context,
                        Expense(
                          id: widget.expense?.id,
                          date: dayKey(date),
                          amount: validAmount(amount.text),
                          category: category,
                          merchant: merchant.text,
                          memo: memo.text,
                          recurring: recurring,
                        ),
                      );
                    }
                  },
                  child: Text(widget.expense == null ? '지출 저장' : '수정 저장'),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
  Future<void> delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('지출을 삭제할까요?'),
        content: Text(
          '${widget.expense!.merchant} · ${won(widget.expense!.amount)}\n삭제하면 통계와 예산 사용률이 다시 계산됩니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제 확정', style: TextStyle(color: red)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) Navigator.pop(context, 'delete');
  }
}

class BudgetEditor extends StatefulWidget {
  final Budget budget;
  final DateTime month;
  const BudgetEditor({super.key, required this.budget, required this.month});
  @override
  State<BudgetEditor> createState() => _BudgetEditorState();
}

class _BudgetEditorState extends State<BudgetEditor> {
  final form = GlobalKey<FormState>();
  late TextEditingController total;
  late Map<String, TextEditingController> fields;
  @override
  void initState() {
    super.initState();
    total = TextEditingController(text: '${widget.budget.total}');
    fields = {
      for (final c in categories)
        c: TextEditingController(text: '${widget.budget.limits[c] ?? 0}'),
    };
  }

  @override
  void dispose() {
    total.dispose();
    for (final f in fields.values) {
      f.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => editorLayout(
    context,
    Form(
      key: form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          section('이번 달 예산 조정'),
          txt('${monthKey(widget.month)} · 0원은 미설정으로 처리해요.', size: 11),
          const SizedBox(height: 16),
          amountInput(
            total,
            '전체 월 예산 (원)',
            allowZero: true,
            fieldKey: const ValueKey('budget-total'),
          ),
          const SizedBox(height: 14),
          ...categories.map(
            (c) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: amountInput(
                fields[c]!,
                '$c (원)',
                allowZero: true,
                fieldKey: ValueKey('budget-$c'),
              ),
            ),
          ),
          txt('항목별 예산은 독립 한도입니다. 합계를 전체 예산에 맞추면 관리하기 쉬워요.', size: 11),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const ValueKey('save-budget'),
              onPressed: () {
                if (form.currentState!.validate()) {
                  Navigator.pop(
                    context,
                    Budget(
                      total: validAmount(total.text, allowZero: true),
                      limits: {
                        for (final c in categories)
                          c: validAmount(fields[c]!.text, allowZero: true),
                      },
                    ),
                  );
                }
              },
              child: const Text('예산 저장하기'),
            ),
          ),
        ],
      ),
    ),
  );
}

class TextPrompt extends StatefulWidget {
  final String title, hint, initial, description;
  final String? confirmation;
  const TextPrompt({
    super.key,
    required this.title,
    required this.hint,
    this.initial = '',
    this.description = '',
    this.confirmation,
  });
  @override
  State<TextPrompt> createState() => _TextPromptState();
}

class _TextPromptState extends State<TextPrompt> {
  late TextEditingController controller;
  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.description.isNotEmpty) ...[
          txt(widget.description),
          const SizedBox(height: 16),
        ],
        TextField(
          controller: controller,
          maxLength: 20,
          decoration: InputDecoration(labelText: widget.hint),
          onChanged: (_) => setState(() {}),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('취소'),
      ),
      FilledButton(
        onPressed:
            (widget.confirmation == null
                ? controller.text.trim().isNotEmpty
                : controller.text == widget.confirmation)
            ? () => Navigator.pop(context, controller.text)
            : null,
        style: FilledButton.styleFrom(
          backgroundColor: widget.confirmation == null ? purple : red,
        ),
        child: Text(widget.confirmation == null ? '저장' : '전체 삭제 확정'),
      ),
    ],
  );
}
