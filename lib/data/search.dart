// Pure Dart: the rules behind the search screen.

import '../util/format.dart';
import 'models.dart';

enum EntryKind { all, expense, income }

/// Used as a category id to mean "entries with no category".
const int kNoCategory = -1;

class TxnFilter {
  const TxnFilter({
    this.query = '',
    this.kind = EntryKind.all,
    this.categoryId,
    this.from,
    this.to,
    this.minMinor,
    this.maxMinor,
  });

  final String query;
  final EntryKind kind;

  /// null means any category. [kNoCategory] means entries without one.
  final int? categoryId;

  /// Whole days, both ends included.
  final DateTime? from;
  final DateTime? to;

  final int? minMinor;
  final int? maxMinor;

  bool get isActive =>
      query.trim().isNotEmpty ||
      kind != EntryKind.all ||
      categoryId != null ||
      from != null ||
      to != null ||
      minMinor != null ||
      maxMinor != null;

  /// Every word typed must appear in the note or the category name. A word that
  /// is a number also matches an entry of exactly that amount, so "5000" finds
  /// a 5,000 entry even when its note says something else.
  bool matches(Txn t, String categoryName) {
    if (kind == EntryKind.expense && t.isIncome) return false;
    if (kind == EntryKind.income && !t.isIncome) return false;

    final cat = categoryId;
    if (cat != null) {
      if (cat == kNoCategory) {
        if (t.categoryId != null) return false;
      } else if (t.categoryId != cat) {
        return false;
      }
    }

    final start = from;
    if (start != null && t.date.isBefore(dateOnly(start))) return false;
    final end = to;
    if (end != null &&
        !t.date.isBefore(DateTime(end.year, end.month, end.day + 1))) {
      return false;
    }

    final low = minMinor;
    if (low != null && t.amountMinor < low) return false;
    final high = maxMinor;
    if (high != null && t.amountMinor > high) return false;

    final words = query
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty);
    if (words.isNotEmpty) {
      final haystack = '${t.note} $categoryName'.toLowerCase();
      for (final w in words) {
        if (haystack.contains(w)) continue;
        if (parseAmountMinor(w) == t.amountMinor) continue;
        return false;
      }
    }
    return true;
  }
}
