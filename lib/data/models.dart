DateTime? _dateFrom(Object? v) =>
    v == null ? null : DateTime.fromMillisecondsSinceEpoch(v as int);

class Category {
  const Category({
    required this.id,
    required this.name,
    required this.emoji,
    required this.isIncome,
    required this.sort,
  });

  final int id;
  final String name;
  final String emoji;
  final bool isIncome;
  final int sort;

  factory Category.fromMap(Map<String, Object?> m) => Category(
        id: m['id'] as int,
        name: m['name'] as String,
        emoji: m['emoji'] as String,
        isIncome: (m['is_income'] as int) == 1,
        sort: m['sort'] as int,
      );
}

/// One income or expense entry. Amounts are in minor units.
class Txn {
  const Txn({
    required this.id,
    required this.isIncome,
    required this.amountMinor,
    required this.categoryId,
    required this.note,
    required this.date,
  });

  final int id;
  final bool isIncome;
  final int amountMinor;
  final int? categoryId;
  final String note;
  final DateTime date;

  factory Txn.fromMap(Map<String, Object?> m) => Txn(
        id: m['id'] as int,
        isIncome: (m['is_income'] as int) == 1,
        amountMinor: m['amount_minor'] as int,
        categoryId: m['category_id'] as int?,
        note: (m['note'] as String?) ?? '',
        date: DateTime.fromMillisecondsSinceEpoch(m['date'] as int),
      );
}

class Person {
  const Person({
    required this.id,
    required this.name,
    required this.phone,
    required this.dueDate,
    required this.created,
  });

  final int id;
  final String name;
  final String phone;
  final DateTime? dueDate;
  final DateTime created;

  factory Person.fromMap(Map<String, Object?> m) => Person(
        id: m['id'] as int,
        name: m['name'] as String,
        phone: (m['phone'] as String?) ?? '',
        dueDate: _dateFrom(m['due_date']),
        created: DateTime.fromMillisecondsSinceEpoch(m['created'] as int),
      );
}

/// One line in a person's running balance.
/// gave = true: money left my pocket (I lent, or paid back).
/// gave = false: money came to me (I borrowed, or got paid back).
class LedgerEntry {
  const LedgerEntry({
    required this.id,
    required this.personId,
    required this.gave,
    required this.amountMinor,
    required this.note,
    required this.date,
  });

  final int id;
  final int personId;
  final bool gave;
  final int amountMinor;
  final String note;
  final DateTime date;

  factory LedgerEntry.fromMap(Map<String, Object?> m) => LedgerEntry(
        id: m['id'] as int,
        personId: m['person_id'] as int,
        gave: (m['gave'] as int) == 1,
        amountMinor: m['amount_minor'] as int,
        note: (m['note'] as String?) ?? '',
        date: DateTime.fromMillisecondsSinceEpoch(m['date'] as int),
      );
}

class Goal {
  const Goal({
    required this.id,
    required this.name,
    required this.emoji,
    required this.targetMinor,
    required this.savedMinor,
    required this.deadline,
    required this.created,
  });

  final int id;
  final String name;
  final String emoji;
  final int targetMinor;
  final int savedMinor;
  final DateTime? deadline;
  final DateTime created;

  factory Goal.fromMap(Map<String, Object?> m) => Goal(
        id: m['id'] as int,
        name: m['name'] as String,
        emoji: m['emoji'] as String,
        targetMinor: m['target_minor'] as int,
        savedMinor: m['saved_minor'] as int,
        deadline: _dateFrom(m['deadline']),
        created: DateTime.fromMillisecondsSinceEpoch(m['created'] as int),
      );
}
