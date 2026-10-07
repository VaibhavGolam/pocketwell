import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../services/notifier.dart';
import '../util/format.dart';
import 'db.dart';
import 'models.dart';

class CategoryTotal {
  const CategoryTotal(this.categoryId, this.total);

  /// null means "no category" (shown as Other).
  final int? categoryId;
  final int total;
}

/// All app data lives here, in memory, backed by SQLite.
/// A personal expense log is small, so loading everything is fast and keeps
/// the screens simple.
class Store extends ChangeNotifier {
  late Database _db;
  late SharedPreferences _prefs;

  final ValueNotifier<ThemeMode> themeMode = ValueNotifier(ThemeMode.system);
  String currencySymbol = '₹';

  List<Category> categories = [];
  List<Txn> txns = [];
  List<Person> people = [];
  List<LedgerEntry> ledger = [];
  List<Goal> goals = [];

  // ---------------------------------------------------------------- startup

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final savedTheme = _prefs.getString('theme_mode');
    themeMode.value = ThemeMode.values.firstWhere(
      (m) => m.name == savedTheme,
      orElse: () => ThemeMode.system,
    );
    currencySymbol = _prefs.getString('currency') ?? '₹';
    _db = await AppDb.open();
    await _loadCategories();
    await _loadTxns();
    await _loadPeople();
    await _loadLedger();
    await _loadGoals();
    notifyListeners();
  }

  Future<void> _loadCategories() async {
    final rows = await _db.query('categories', orderBy: 'sort ASC, id ASC');
    categories = rows.map(Category.fromMap).toList();
  }

  Future<void> _loadTxns() async {
    final rows = await _db.query('txns', orderBy: 'date DESC, id DESC');
    txns = rows.map(Txn.fromMap).toList();
  }

  Future<void> _loadPeople() async {
    final rows = await _db.query('people', orderBy: 'id ASC');
    people = rows.map(Person.fromMap).toList();
  }

  Future<void> _loadLedger() async {
    final rows = await _db.query('ledger', orderBy: 'date DESC, id DESC');
    ledger = rows.map(LedgerEntry.fromMap).toList();
  }

  Future<void> _loadGoals() async {
    final rows = await _db.query('goals', orderBy: 'id ASC');
    goals = rows.map(Goal.fromMap).toList();
  }

  // --------------------------------------------------------------- settings

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode.value = mode;
    await _prefs.setString('theme_mode', mode.name);
  }

  Future<void> setCurrency(String symbol) async {
    currencySymbol = symbol;
    await _prefs.setString('currency', symbol);
    notifyListeners();
  }

  String fmt(int minor, {bool sign = false}) =>
      formatMinor(minor, symbol: currencySymbol, showSign: sign);

  // ------------------------------------------------------------ tip of day

  String _dayKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

  bool get shouldShowTipToday =>
      _prefs.getString('tip_day') != _dayKey(DateTime.now());

  Future<void> markTipShown() =>
      _prefs.setString('tip_day', _dayKey(DateTime.now()));

  // ------------------------------------------------------------- categories

  Category? categoryById(int? id) {
    if (id == null) return null;
    for (final c in categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  Future<int> addCategory({
    required String name,
    required String emoji,
    required bool isIncome,
  }) async {
    var nextSort = 0;
    for (final c in categories) {
      if (c.sort >= nextSort) nextSort = c.sort + 1;
    }
    final id = await _db.insert('categories', {
      'name': name,
      'emoji': emoji,
      'is_income': isIncome ? 1 : 0,
      'sort': nextSort,
    });
    await _loadCategories();
    notifyListeners();
    return id;
  }

  Future<void> updateCategory(int id, String name, String emoji) async {
    await _db.update(
      'categories',
      {'name': name, 'emoji': emoji},
      where: 'id = ?',
      whereArgs: [id],
    );
    await _loadCategories();
    notifyListeners();
  }

  /// Entries in a deleted category are kept and shown as Other.
  Future<void> deleteCategory(int id) async {
    await _db.update(
      'txns',
      {'category_id': null},
      where: 'category_id = ?',
      whereArgs: [id],
    );
    await _db.delete('categories', where: 'id = ?', whereArgs: [id]);
    await _loadCategories();
    await _loadTxns();
    notifyListeners();
  }

  // ----------------------------------------------------------- transactions

  Future<void> addTxn({
    required bool isIncome,
    required int amountMinor,
    required int? categoryId,
    required String note,
    required DateTime date,
  }) async {
    await _db.insert('txns', {
      'is_income': isIncome ? 1 : 0,
      'amount_minor': amountMinor,
      'category_id': categoryId,
      'note': note,
      'date': date.millisecondsSinceEpoch,
    });
    await _loadTxns();
    notifyListeners();
  }

  Future<void> updateTxn(
    int id, {
    required bool isIncome,
    required int amountMinor,
    required int? categoryId,
    required String note,
    required DateTime date,
  }) async {
    await _db.update(
      'txns',
      {
        'is_income': isIncome ? 1 : 0,
        'amount_minor': amountMinor,
        'category_id': categoryId,
        'note': note,
        'date': date.millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    await _loadTxns();
    notifyListeners();
  }

  Future<void> deleteTxn(int id) async {
    await _db.delete('txns', where: 'id = ?', whereArgs: [id]);
    await _loadTxns();
    notifyListeners();
  }

  List<Txn> txnsInMonth(DateTime month) => txns
      .where((t) => t.date.year == month.year && t.date.month == month.month)
      .toList();

  int totalIn(DateTime month) => txnsInMonth(month)
      .where((t) => t.isIncome)
      .fold<int>(0, (sum, t) => sum + t.amountMinor);

  int totalOut(DateTime month) => txnsInMonth(month)
      .where((t) => !t.isIncome)
      .fold<int>(0, (sum, t) => sum + t.amountMinor);

  /// Expenses for the month grouped by category, biggest first.
  List<CategoryTotal> spendingByCategory(DateTime month) {
    final map = <int?, int>{};
    for (final t in txnsInMonth(month)) {
      if (t.isIncome) continue;
      map[t.categoryId] = (map[t.categoryId] ?? 0) + t.amountMinor;
    }
    final list =
        map.entries.map((e) => CategoryTotal(e.key, e.value)).toList();
    list.sort((a, b) => b.total.compareTo(a.total));
    return list;
  }

  /// Expense total for each day of the month (index 0 is the 1st).
  List<int> dailySpending(DateTime month) {
    final days = List<int>.filled(daysInMonth(month), 0);
    for (final t in txnsInMonth(month)) {
      if (t.isIncome) continue;
      days[t.date.day - 1] += t.amountMinor;
    }
    return days;
  }

  // ----------------------------------------------------------------- people

  Person? personById(int id) {
    for (final p in people) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Positive: they owe me. Negative: I owe them.
  Map<int, int> get balances {
    final map = <int, int>{};
    for (final e in ledger) {
      map[e.personId] =
          (map[e.personId] ?? 0) + (e.gave ? e.amountMinor : -e.amountMinor);
    }
    return map;
  }

  int balanceOf(int personId) => balances[personId] ?? 0;

  List<LedgerEntry> entriesFor(int personId) =>
      ledger.where((e) => e.personId == personId).toList();

  DateTime lastActivity(Person p) {
    var latest = p.created;
    for (final e in ledger) {
      if (e.personId == p.id && e.date.isAfter(latest)) latest = e.date;
    }
    return latest;
  }

  Future<int> addPerson(String name, String phone) async {
    final id = await _db.insert('people', {
      'name': name,
      'phone': phone,
      'due_date': null,
      'created': DateTime.now().millisecondsSinceEpoch,
    });
    await _loadPeople();
    notifyListeners();
    return id;
  }

  Future<void> updatePerson(int id, String name, String phone) async {
    await _db.update(
      'people',
      {'name': name, 'phone': phone},
      where: 'id = ?',
      whereArgs: [id],
    );
    await _loadPeople();
    notifyListeners();
    await _syncReminder(id);
  }

  Future<void> deletePerson(int id) async {
    await Notifier.cancelPerson(id);
    await _db.delete('ledger', where: 'person_id = ?', whereArgs: [id]);
    await _db.delete('people', where: 'id = ?', whereArgs: [id]);
    await _loadPeople();
    await _loadLedger();
    notifyListeners();
  }

  Future<void> setPersonDue(int id, DateTime? due) async {
    await _db.update(
      'people',
      {'due_date': due?.millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
    await _loadPeople();
    notifyListeners();
    await _syncReminder(id);
  }

  Future<void> addLedger({
    required int personId,
    required bool gave,
    required int amountMinor,
    required String note,
    required DateTime date,
    DateTime? dueDate,
  }) async {
    await _db.insert('ledger', {
      'person_id': personId,
      'gave': gave ? 1 : 0,
      'amount_minor': amountMinor,
      'note': note,
      'date': date.millisecondsSinceEpoch,
    });
    await _loadLedger();
    if (dueDate != null) {
      await _db.update(
        'people',
        {'due_date': dueDate.millisecondsSinceEpoch},
        where: 'id = ?',
        whereArgs: [personId],
      );
    }
    // A settled balance has nothing left to be due.
    if (balanceOf(personId) == 0) {
      await _db.update(
        'people',
        {'due_date': null},
        where: 'id = ?',
        whereArgs: [personId],
      );
    }
    await _loadPeople();
    notifyListeners();
    await _syncReminder(personId);
  }

  Future<void> deleteLedger(int entryId, int personId) async {
    await _db.delete('ledger', where: 'id = ?', whereArgs: [entryId]);
    await _loadLedger();
    if (balanceOf(personId) == 0) {
      await _db.update(
        'people',
        {'due_date': null},
        where: 'id = ?',
        whereArgs: [personId],
      );
      await _loadPeople();
    }
    notifyListeners();
    await _syncReminder(personId);
  }

  /// Keeps the phone's scheduled reminder in step with the person's balance
  /// and due date. Reminder fires at 9:00 on the due date.
  Future<void> _syncReminder(int personId) async {
    final p = personById(personId);
    final due = p?.dueDate;
    final bal = balanceOf(personId);
    if (p == null || due == null || bal == 0) {
      await Notifier.cancelPerson(personId);
      return;
    }
    final when = DateTime(due.year, due.month, due.day, 9);
    final amount = fmt(bal.abs());
    await Notifier.scheduleDue(
      personId: personId,
      title: bal > 0 ? 'Money to collect today' : 'Money to pay today',
      body: bal > 0 ? '${p.name} owes you $amount.' : 'You owe ${p.name} $amount.',
      when: when,
    );
  }

  // ------------------------------------------------------------------ goals

  Future<void> addGoal({
    required String name,
    required String emoji,
    required int targetMinor,
    required int savedMinor,
    required DateTime? deadline,
  }) async {
    await _db.insert('goals', {
      'name': name,
      'emoji': emoji,
      'target_minor': targetMinor,
      'saved_minor': savedMinor,
      'deadline': deadline?.millisecondsSinceEpoch,
      'created': DateTime.now().millisecondsSinceEpoch,
    });
    await _loadGoals();
    notifyListeners();
  }

  Future<void> updateGoal(
    int id, {
    required String name,
    required String emoji,
    required int targetMinor,
    required int savedMinor,
    required DateTime? deadline,
  }) async {
    await _db.update(
      'goals',
      {
        'name': name,
        'emoji': emoji,
        'target_minor': targetMinor,
        'saved_minor': savedMinor,
        'deadline': deadline?.millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    await _loadGoals();
    notifyListeners();
  }

  Future<void> addToGoal(int id, int deltaMinor) async {
    await _db.rawUpdate(
      'UPDATE goals SET saved_minor = saved_minor + ? WHERE id = ?',
      [deltaMinor, id],
    );
    await _loadGoals();
    notifyListeners();
  }

  Future<void> deleteGoal(int id) async {
    await _db.delete('goals', where: 'id = ?', whereArgs: [id]);
    await _loadGoals();
    notifyListeners();
  }

  // ------------------------------------------------------------------ reset

  Future<void> resetAll() async {
    await Notifier.cancelAll();
    await _db.delete('txns');
    await _db.delete('ledger');
    await _db.delete('people');
    await _db.delete('goals');
    await _db.delete('categories');
    await AppDb.seedCategories(_db);
    await _loadCategories();
    await _loadTxns();
    await _loadPeople();
    await _loadLedger();
    await _loadGoals();
    notifyListeners();
  }
}

final Store store = Store();
