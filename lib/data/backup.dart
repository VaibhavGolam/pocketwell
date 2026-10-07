// Pure Dart: the backup file format and the CSV exports.
// No Flutter and no database in here, so all of it can be tested.

import 'dart:convert';

import '../util/format.dart';
import 'models.dart';

const int kBackupVersion = 2;

/// The columns of every table that go into a backup. Anything else found in a
/// file is ignored, so a hand-edited file cannot add surprises to the database.
const Map<String, List<String>> kBackupColumns = {
  'categories': ['id', 'name', 'emoji', 'is_income', 'sort'],
  'txns': [
    'id',
    'is_income',
    'amount_minor',
    'category_id',
    'note',
    'date',
    'recurring_id',
  ],
  'people': ['id', 'name', 'phone', 'due_date', 'created'],
  'ledger': ['id', 'person_id', 'gave', 'amount_minor', 'note', 'date'],
  'goals': [
    'id',
    'name',
    'emoji',
    'target_minor',
    'saved_minor',
    'deadline',
    'created',
  ],
  'budgets': ['category_id', 'limit_minor'],
  'recurring': [
    'id',
    'is_income',
    'amount_minor',
    'category_id',
    'note',
    'frequency',
    'anchor',
    'next_due',
    'active',
  ],
};

class BackupData {
  const BackupData({
    required this.tables,
    required this.currency,
    required this.exported,
  });

  final Map<String, List<Map<String, Object?>>> tables;
  final String? currency;
  final DateTime? exported;

  int count(String table) => tables[table]?.length ?? 0;
}

class Backup {
  Backup._();

  static String encode(
    Map<String, List<Map<String, Object?>>> tables, {
    required String currency,
    required DateTime exported,
  }) {
    return jsonEncode(<String, Object?>{
      'app': 'pocketwell',
      'version': kBackupVersion,
      'exported': exported.toIso8601String(),
      'currency': currency,
      for (final e in tables.entries) e.key: e.value,
    });
  }

  /// Reads and checks a backup file. Throws a [FormatException] whose message
  /// is safe to show to the person.
  static BackupData parse(String text) {
    const notBackup = FormatException('This file is not a Pocketwell backup.');

    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      throw notBackup;
    }
    if (decoded is! Map || decoded['app'] != 'pocketwell') throw notBackup;

    final version = decoded['version'];
    if (version is! int || version < 1) throw notBackup;
    if (version > kBackupVersion) {
      throw const FormatException(
        'This backup was made by a newer version of Pocketwell. Update the app and try again.',
      );
    }

    const damaged = FormatException('This backup file is damaged.');
    final tables = <String, List<Map<String, Object?>>>{};
    for (final entry in kBackupColumns.entries) {
      final raw = decoded[entry.key];
      final rows = <Map<String, Object?>>[];
      if (raw != null) {
        if (raw is! List) throw damaged;
        for (final item in raw) {
          if (item is! Map) throw damaged;
          final row = <String, Object?>{};
          for (final column in entry.value) {
            if (!item.containsKey(column)) continue;
            final v = item[column];
            if (v == null || v is int || v is String) {
              row[column] = v;
            } else if (v is double && v == v.truncateToDouble()) {
              row[column] = v.toInt();
            } else {
              throw damaged;
            }
          }
          rows.add(row);
        }
      }
      tables[entry.key] = rows;
    }

    if (tables['categories']!.isEmpty) {
      throw const FormatException('This backup looks incomplete.');
    }

    final currency = decoded['currency'];
    final exported = decoded['exported'];
    return BackupData(
      tables: tables,
      currency: currency is String && currency.isNotEmpty && currency.length <= 5
          ? currency
          : null,
      exported: exported is String ? DateTime.tryParse(exported) : null,
    );
  }
}

// ---------------------------------------------------------------------- CSV

/// Quotes a text value for CSV. A value that starts with = + - or @ would be
/// run as a formula by Excel or Sheets, so it gets a leading apostrophe.
String csvField(String value) {
  var s = value;
  if (s.isNotEmpty && '=+-@\t\r'.contains(s[0])) s = "'$s";
  if (s.contains(',') ||
      s.contains('"') ||
      s.contains('\n') ||
      s.contains('\r')) {
    s = '"${s.replaceAll('"', '""')}"';
  }
  return s;
}

/// One row per entry, oldest first. Opens cleanly in Excel and Google Sheets.
String buildEntriesCsv(
  List<Txn> txns,
  String Function(int? categoryId) categoryName,
) {
  final sorted = [...txns]..sort((a, b) => a.date.compareTo(b.date));
  final out = StringBuffer('﻿');
  out.write('Date,Type,Category,Amount,Note\r\n');
  for (final t in sorted) {
    out.write(
      '${isoDate(t.date)},${t.isIncome ? 'Income' : 'Expense'},'
      '${csvField(categoryName(t.categoryId))},${amountText(t.amountMinor)},'
      '${csvField(t.note)}\r\n',
    );
  }
  return out.toString();
}

/// One row per udhaar line. "I gave" is money that left your pocket.
String buildUdhaarCsv(
  List<LedgerEntry> ledger,
  String Function(int personId) personName,
) {
  final sorted = [...ledger]..sort((a, b) => a.date.compareTo(b.date));
  final out = StringBuffer('﻿');
  out.write('Date,Person,What happened,Amount,Note\r\n');
  for (final e in sorted) {
    out.write(
      '${isoDate(e.date)},${csvField(personName(e.personId))},'
      '${e.gave ? 'I gave' : 'I got'},${amountText(e.amountMinor)},'
      '${csvField(e.note)}\r\n',
    );
  }
  return out.toString();
}
