import 'package:sqflite/sqflite.dart';

const List<(String, String)> _expenseSeed = [
  ('🍔', 'Food'),
  ('🛒', 'Groceries'),
  ('🚌', 'Transport'),
  ('⛽', 'Fuel'),
  ('🏠', 'Rent'),
  ('💡', 'Bills'),
  ('📱', 'Recharge'),
  ('🎬', 'Fun'),
  ('🛍️', 'Shopping'),
  ('💊', 'Health'),
  ('📚', 'Education'),
  ('✈️', 'Travel'),
  ('🎁', 'Gifts'),
  ('🧾', 'Other'),
];

const List<(String, String)> _incomeSeed = [
  ('💼', 'Salary'),
  ('🏪', 'Business'),
  ('🎁', 'Gift'),
  ('📈', 'Interest'),
  ('🔁', 'Refund'),
  ('➕', 'Other income'),
];

class AppDb {
  AppDb._();

  static Database? _db;

  static Future<Database> open() async {
    final existing = _db;
    if (existing != null) return existing;
    final dir = await getDatabasesPath();
    final db = await openDatabase(
      '$dir/pocketwell.db',
      version: 1,
      onCreate: _onCreate,
    );
    _db = db;
    return db;
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE categories(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        emoji TEXT NOT NULL,
        is_income INTEGER NOT NULL,
        sort INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE txns(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        is_income INTEGER NOT NULL,
        amount_minor INTEGER NOT NULL,
        category_id INTEGER,
        note TEXT,
        date INTEGER NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_txns_date ON txns(date)');
    await db.execute('''
      CREATE TABLE people(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT,
        due_date INTEGER,
        created INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE ledger(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        person_id INTEGER NOT NULL,
        gave INTEGER NOT NULL,
        amount_minor INTEGER NOT NULL,
        note TEXT,
        date INTEGER NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_ledger_person ON ledger(person_id)');
    await db.execute('''
      CREATE TABLE goals(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        emoji TEXT NOT NULL,
        target_minor INTEGER NOT NULL,
        saved_minor INTEGER NOT NULL DEFAULT 0,
        deadline INTEGER,
        created INTEGER NOT NULL
      )
    ''');
    await seedCategories(db);
  }

  static Future<void> seedCategories(DatabaseExecutor db) async {
    final batch = db.batch();
    var sort = 0;
    for (final (emoji, name) in _expenseSeed) {
      batch.insert('categories', {
        'name': name,
        'emoji': emoji,
        'is_income': 0,
        'sort': sort++,
      });
    }
    for (final (emoji, name) in _incomeSeed) {
      batch.insert('categories', {
        'name': name,
        'emoji': emoji,
        'is_income': 1,
        'sort': sort++,
      });
    }
    await batch.commit(noResult: true);
  }
}
