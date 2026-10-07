import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocketwell/data/backup.dart';
import 'package:pocketwell/data/models.dart';

Txn _txn({
  required DateTime date,
  required bool isIncome,
  required int amount,
  int? category,
  String note = '',
}) =>
    Txn(
      id: 1,
      isIncome: isIncome,
      amountMinor: amount,
      categoryId: category,
      note: note,
      date: date,
    );

String _backupJson(Map<String, Object?> overrides) => jsonEncode({
      'app': 'pocketwell',
      'version': kBackupVersion,
      'currency': '₹',
      'categories': [
        {'id': 1, 'name': 'Food', 'emoji': '🍔', 'is_income': 0, 'sort': 0},
      ],
      ...overrides,
    });

void main() {
  group('csvField', () {
    test('leaves plain text alone', () {
      expect(csvField('hello'), 'hello');
      expect(csvField(''), '');
    });

    test('quotes commas, quotes and new lines', () {
      expect(csvField('a,b'), '"a,b"');
      expect(csvField('say "hi"'), '"say ""hi"""');
      expect(csvField('one\ntwo'), '"one\ntwo"');
    });

    test('defuses spreadsheet formulas', () {
      expect(csvField('=SUM(A1)'), "'=SUM(A1)");
      expect(csvField('+91 98765'), "'+91 98765");
      expect(csvField('-5 refund'), "'-5 refund");
      expect(csvField('@home'), "'@home");
    });
  });

  group('CSV exports', () {
    test('entries are oldest first with two decimals', () {
      final csv = buildEntriesCsv(
        [
          _txn(
            date: DateTime(2026, 10, 2, 12),
            isIncome: false,
            amount: 250050,
            category: 1,
            note: 'Lunch, with team',
          ),
          _txn(
            date: DateTime(2026, 10, 1, 9),
            isIncome: true,
            amount: 5000000,
            category: 2,
          ),
        ],
        (id) => id == 1 ? 'Food' : 'Salary',
      );
      expect(
        csv,
        '﻿Date,Type,Category,Amount,Note\r\n'
        '2026-10-01,Income,Salary,50000.00,\r\n'
        '2026-10-02,Expense,Food,2500.50,"Lunch, with team"\r\n',
      );
    });

    test('udhaar lines say who and what happened', () {
      final csv = buildUdhaarCsv(
        [
          LedgerEntry(
            id: 1,
            personId: 7,
            gave: true,
            amountMinor: 100000,
            note: 'Bike repair',
            date: DateTime(2026, 9, 30),
          ),
          LedgerEntry(
            id: 2,
            personId: 7,
            gave: false,
            amountMinor: 25000,
            note: '',
            date: DateTime(2026, 10, 5),
          ),
        ],
        (id) => 'Ravi',
      );
      expect(
        csv,
        '﻿Date,Person,What happened,Amount,Note\r\n'
        '2026-09-30,Ravi,I gave,1000.00,Bike repair\r\n'
        '2026-10-05,Ravi,I got,250.00,\r\n',
      );
    });
  });

  group('Backup', () {
    test('encode then parse keeps rows and currency', () {
      final json = Backup.encode(
        {
          'categories': [
            {'id': 1, 'name': 'Food', 'emoji': '🍔', 'is_income': 0, 'sort': 0},
          ],
          'txns': [
            {
              'id': 1,
              'is_income': 0,
              'amount_minor': 12300,
              'category_id': 1,
              'note': 'Tea',
              'date': 1790000000000,
              'recurring_id': null,
            },
          ],
        },
        currency: '₹',
        exported: DateTime(2026, 10, 7),
      );
      final data = Backup.parse(json);
      expect(data.count('categories'), 1);
      expect(data.count('txns'), 1);
      expect(data.count('goals'), 0);
      expect(data.currency, '₹');
      expect(data.exported, DateTime(2026, 10, 7));
      expect(data.tables['txns']!.first['amount_minor'], 12300);
      expect(data.tables['txns']!.first['note'], 'Tea');
    });

    test('ignores columns it does not know', () {
      final data = Backup.parse(
        _backupJson({
          'txns': [
            {
              'id': 1,
              'is_income': 0,
              'amount_minor': 100,
              'date': 1,
              'evil': 'DROP TABLE txns',
            },
          ],
        }),
      );
      expect(data.tables['txns']!.first.containsKey('evil'), isFalse);
      expect(data.tables['txns']!.first['amount_minor'], 100);
    });

    test('rejects things that are not backups', () {
      expect(() => Backup.parse('not json'), throwsFormatException);
      expect(() => Backup.parse('[1,2,3]'), throwsFormatException);
      expect(
        () => Backup.parse(jsonEncode({'app': 'other', 'version': 1})),
        throwsFormatException,
      );
    });

    test('rejects a backup from a newer version', () {
      expect(
        () => Backup.parse(_backupJson({'version': kBackupVersion + 1})),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('newer'),
          ),
        ),
      );
    });

    test('rejects a backup with no categories', () {
      expect(
        () => Backup.parse(_backupJson({'categories': []})),
        throwsFormatException,
      );
    });

    test('rejects rows that are not objects', () {
      expect(
        () => Backup.parse(_backupJson({'txns': [1, 2]})),
        throwsFormatException,
      );
    });
  });
}
