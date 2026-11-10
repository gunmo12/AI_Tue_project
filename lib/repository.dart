import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'domain.dart';

class SpendingRepository {
  final Database database;
  SpendingRepository(this.database);
  static Future<SpendingRepository> open({
    String filename = 'spending-assistant.db',
    DateTime? clock,
  }) async {
    final now = clock ?? DateTime.now();
    final db = await openDatabase(
      p.join(await getDatabasesPath(), filename),
      version: 2,
      onUpgrade: (db, oldVersion, _) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE expenses ADD COLUMN prototype_month TEXT',
          );
        }
      },
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE expenses (id INTEGER PRIMARY KEY AUTOINCREMENT, date TEXT NOT NULL, amount INTEGER NOT NULL CHECK(amount>0), category TEXT NOT NULL, merchant TEXT NOT NULL, memo TEXT NOT NULL, recurring INTEGER NOT NULL, prototype_month TEXT)',
        );
        await db.execute('CREATE INDEX expense_date ON expenses(date)');
        await db.execute(
          'CREATE TABLE budgets (month TEXT PRIMARY KEY, body TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE reports (month TEXT PRIMARY KEY, body TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
        );
        await db.insert('settings', {'key': 'name', 'value': '반석'});
        await db.insert('settings', {'key': 'demo', 'value': '1'});
        for (final record in demoExpenses(now)) {
          await db.insert('expenses', {
            ...record.toMap(),
            if (record.date.startsWith(monthKey(now)))
              'prototype_month': monthKey(now),
          });
        }
        await db.insert('budgets', {
          'month': monthKey(now),
          'body': jsonEncode(demoBudget.toMap()),
        });
      },
    );
    return SpendingRepository(db);
  }

  Future<Ledger> load() async {
    final expenses = (await database.query(
      'expenses',
      orderBy: 'date DESC, id DESC',
    )).map(Expense.fromMap).toList();
    final budgets = <String, Budget>{};
    for (final row in await database.query('budgets')) {
      budgets[row['month'] as String] = Budget.fromMap(
        jsonDecode(row['body'] as String),
      );
    }
    final reports = <String, Map<String, dynamic>>{};
    for (final row in await database.query('reports')) {
      reports[row['month'] as String] = Map<String, dynamic>.from(
        jsonDecode(row['body'] as String),
      );
    }
    final settings = {
      for (final row in await database.query('settings'))
        row['key'] as String: row['value'] as String,
    };
    return Ledger(
      expenses: expenses,
      budgets: budgets,
      reports: reports,
      name: settings['name'] ?? '사용자',
      demo: settings['demo'] == '1',
    );
  }

  Future<void> saveExpense(Expense expense) async {
    expense.validate();
    if (expense.id == null) {
      await database.insert('expenses', expense.toMap());
    } else {
      final count = await database.update(
        'expenses',
        {...expense.toMap(), 'prototype_month': null},
        where: 'id=?',
        whereArgs: [expense.id],
      );
      if (count != 1) throw StateError('지출 내역을 찾지 못했어요. 다시 확인해 주세요.');
    }
  }

  Future<void> applyPrototypeSpending(
    DateTime month,
    PrototypeSpending profile,
  ) async {
    final key = monthKey(month);
    final records = profile.records(month);
    await database.transaction((txn) async {
      await txn.delete(
        'expenses',
        where: 'prototype_month = ?',
        whereArgs: [key],
      );
      for (final expense in records) {
        await txn.insert('expenses', {
          ...expense.toMap(),
          'prototype_month': key,
        });
      }
    });
  }

  Future<void> deleteExpense(int id) async =>
      database.delete('expenses', where: 'id=?', whereArgs: [id]);
  Future<void> saveBudget(DateTime month, Budget budget) async {
    budget.validate();
    await database.insert('budgets', {
      'month': monthKey(month),
      'body': jsonEncode(budget.toMap()),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> saveReport(DateTime month, Map<String, dynamic> report) async =>
      database.insert('reports', {
        'month': monthKey(month),
        'body': jsonEncode(report),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
  Future<void> saveName(String name) async {
    if (name.trim().isEmpty || name.length > 20) {
      throw const FormatException('이름은 1~20자로 입력해 주세요.');
    }
    await database.insert('settings', {
      'key': 'name',
      'value': name.trim(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> clear() async => database.transaction((txn) async {
    await txn.delete('expenses');
    await txn.delete('budgets');
    await txn.delete('reports');
    await txn.insert('settings', {
      'key': 'demo',
      'value': '0',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  });
  Future<void> close() => database.close();
}
