import 'package:flutter_test/flutter_test.dart';
import 'package:pocketwell/data/models.dart';
import 'package:pocketwell/data/search.dart';

Txn _t({
  required int amount,
  bool income = false,
  int? category = 1,
  String note = '',
  DateTime? date,
}) =>
    Txn(
      id: 1,
      isIncome: income,
      amountMinor: amount,
      categoryId: category,
      note: note,
      date: date ?? DateTime(2026, 10, 5, 12),
    );

void main() {
  final petrol = _t(amount: 50000, note: 'Petrol at Shell');

  group('text', () {
    test('matches the note, ignoring case', () {
      expect(const TxnFilter(query: 'petrol').matches(petrol, 'Fuel'), isTrue);
      expect(const TxnFilter(query: 'SHELL').matches(petrol, 'Fuel'), isTrue);
    });

    test('matches the category name', () {
      expect(const TxnFilter(query: 'fuel').matches(petrol, 'Fuel'), isTrue);
    });

    test('every word must match', () {
      expect(
        const TxnFilter(query: 'petrol shell').matches(petrol, 'Fuel'),
        isTrue,
      );
      expect(
        const TxnFilter(query: 'petrol diesel').matches(petrol, 'Fuel'),
        isFalse,
      );
    });

    test('a number matches an entry of exactly that amount', () {
      expect(const TxnFilter(query: '500').matches(petrol, 'Fuel'), isTrue);
      expect(const TxnFilter(query: '501').matches(petrol, 'Fuel'), isFalse);
    });

    test('blank query matches everything', () {
      expect(const TxnFilter(query: '   ').matches(petrol, 'Fuel'), isTrue);
    });
  });

  group('type and category', () {
    final salary = _t(amount: 5000000, income: true, category: 2);

    test('type', () {
      const expenses = TxnFilter(kind: EntryKind.expense);
      const income = TxnFilter(kind: EntryKind.income);
      expect(expenses.matches(petrol, 'Fuel'), isTrue);
      expect(expenses.matches(salary, 'Salary'), isFalse);
      expect(income.matches(salary, 'Salary'), isTrue);
      expect(income.matches(petrol, 'Fuel'), isFalse);
    });

    test('category', () {
      expect(const TxnFilter(categoryId: 1).matches(petrol, 'Fuel'), isTrue);
      expect(const TxnFilter(categoryId: 2).matches(petrol, 'Fuel'), isFalse);
    });

    test('no category', () {
      final loose = _t(amount: 100, category: null);
      const filter = TxnFilter(categoryId: kNoCategory);
      expect(filter.matches(loose, 'Other'), isTrue);
      expect(filter.matches(petrol, 'Fuel'), isFalse);
    });
  });

  group('dates', () {
    final filter = TxnFilter(
      from: DateTime(2026, 10, 1),
      to: DateTime(2026, 10, 7),
    );

    test('both ends count as whole days', () {
      expect(
        filter.matches(_t(amount: 1, date: DateTime(2026, 10, 1, 0, 0)), 'x'),
        isTrue,
      );
      expect(
        filter.matches(_t(amount: 1, date: DateTime(2026, 10, 7, 23, 59)), 'x'),
        isTrue,
      );
    });

    test('outside the range does not match', () {
      expect(
        filter.matches(_t(amount: 1, date: DateTime(2026, 9, 30, 23, 59)), 'x'),
        isFalse,
      );
      expect(
        filter.matches(_t(amount: 1, date: DateTime(2026, 10, 8, 0, 0)), 'x'),
        isFalse,
      );
    });
  });

  group('amount', () {
    test('min and max are inclusive', () {
      const filter = TxnFilter(minMinor: 40000, maxMinor: 60000);
      expect(filter.matches(_t(amount: 40000), 'x'), isTrue);
      expect(filter.matches(_t(amount: 60000), 'x'), isTrue);
      expect(filter.matches(_t(amount: 39999), 'x'), isFalse);
      expect(filter.matches(_t(amount: 60001), 'x'), isFalse);
    });

    test('only a minimum', () {
      const filter = TxnFilter(minMinor: 500000);
      expect(filter.matches(_t(amount: 500000), 'x'), isTrue);
      expect(filter.matches(_t(amount: 499999), 'x'), isFalse);
    });
  });

  test('isActive', () {
    expect(const TxnFilter().isActive, isFalse);
    expect(const TxnFilter(query: '  ').isActive, isFalse);
    expect(const TxnFilter(query: 'a').isActive, isTrue);
    expect(const TxnFilter(kind: EntryKind.income).isActive, isTrue);
    expect(const TxnFilter(minMinor: 1).isActive, isTrue);
  });
}
