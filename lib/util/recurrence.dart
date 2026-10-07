// Pure Dart: how repeating entries work out their dates.
// Nothing here touches Flutter or the database, so it is easy to test.

import 'format.dart';

enum Frequency { weekly, monthly, yearly }

Frequency frequencyFromName(String? name) => Frequency.values.firstWhere(
      (f) => f.name == name,
      orElse: () => Frequency.monthly,
    );

String frequencyLabel(Frequency f) {
  switch (f) {
    case Frequency.weekly:
      return 'Weekly';
    case Frequency.monthly:
      return 'Monthly';
    case Frequency.yearly:
      return 'Yearly';
  }
}

DateTime _clamped(int year, int month, int day) {
  final last = DateTime(year, month + 1, 0).day;
  return DateTime(year, month, day > last ? last : day);
}

/// The n-th occurrence of a repeating entry. 0 is the anchor date itself.
/// Always local midnight. A monthly or yearly entry that lands on a day the
/// month does not have (the 31st in April, 29 Feb in a normal year) moves to
/// the last day of that month, and goes back to its real day the month after.
DateTime nthOccurrence(DateTime anchor, Frequency f, int n) {
  switch (f) {
    case Frequency.weekly:
      return DateTime(anchor.year, anchor.month, anchor.day + 7 * n);
    case Frequency.monthly:
      final index = anchor.month - 1 + n;
      return _clamped(anchor.year + index ~/ 12, index % 12 + 1, anchor.day);
    case Frequency.yearly:
      return _clamped(anchor.year + n, anchor.month, anchor.day);
  }
}

/// Occurrences on or after [from], in order. It stops after a very long time
/// so a bad date can never loop forever.
Iterable<DateTime> occurrencesFrom(
  DateTime anchor,
  Frequency f,
  DateTime from,
) sync* {
  final start = DateTime(from.year, from.month, from.day);
  for (var n = 0; n < 20000; n++) {
    final d = nthOccurrence(anchor, f, n);
    if (d.isBefore(start)) continue;
    yield d;
  }
}

/// The first occurrence strictly after [day].
DateTime firstOccurrenceAfter(DateTime anchor, Frequency f, DateTime day) =>
    occurrencesFrom(anchor, f, DateTime(day.year, day.month, day.day + 1))
        .first;

/// "Monthly on the 1st", "Every Monday", "Every 7 Oct".
String describeSchedule(Frequency f, DateTime anchor) {
  switch (f) {
    case Frequency.weekly:
      return 'Every ${kWeekdayNames[anchor.weekday - 1]}';
    case Frequency.monthly:
      final day = ordinal(anchor.day);
      return anchor.day > 28
          ? 'Monthly on the $day (or the last day)'
          : 'Monthly on the $day';
    case Frequency.yearly:
      return 'Every ${anchor.day} ${kMonthShort[anchor.month - 1]}';
  }
}
