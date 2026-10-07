import 'package:flutter_test/flutter_test.dart';
import 'package:pocketwell/util/recurrence.dart';

void main() {
  group('nthOccurrence', () {
    test('monthly on the 31st moves to the last day, then comes back', () {
      final a = DateTime(2026, 1, 31);
      expect(nthOccurrence(a, Frequency.monthly, 0), DateTime(2026, 1, 31));
      expect(nthOccurrence(a, Frequency.monthly, 1), DateTime(2026, 2, 28));
      expect(nthOccurrence(a, Frequency.monthly, 2), DateTime(2026, 3, 31));
      expect(nthOccurrence(a, Frequency.monthly, 3), DateTime(2026, 4, 30));
    });

    test('monthly knows leap years', () {
      expect(
        nthOccurrence(DateTime(2028, 1, 31), Frequency.monthly, 1),
        DateTime(2028, 2, 29),
      );
    });

    test('monthly rolls over the year', () {
      expect(
        nthOccurrence(DateTime(2026, 11, 15), Frequency.monthly, 2),
        DateTime(2027, 1, 15),
      );
    });

    test('weekly adds seven days each time', () {
      final a = DateTime(2026, 10, 7);
      expect(nthOccurrence(a, Frequency.weekly, 1), DateTime(2026, 10, 14));
      expect(nthOccurrence(a, Frequency.weekly, 4), DateTime(2026, 11, 4));
    });

    test('yearly on 29 Feb uses 28 Feb in normal years', () {
      final a = DateTime(2024, 2, 29);
      expect(nthOccurrence(a, Frequency.yearly, 1), DateTime(2025, 2, 28));
      expect(nthOccurrence(a, Frequency.yearly, 4), DateTime(2028, 2, 29));
    });
  });

  group('occurrencesFrom', () {
    test('includes the start day itself', () {
      final first = occurrencesFrom(
        DateTime(2026, 10, 1),
        Frequency.monthly,
        DateTime(2026, 10, 1),
      ).first;
      expect(first, DateTime(2026, 10, 1));
    });

    test('catches up month by month', () {
      final dates = occurrencesFrom(
        DateTime(2026, 8, 1),
        Frequency.monthly,
        DateTime(2026, 8, 1),
      ).takeWhile((d) => !d.isAfter(DateTime(2026, 10, 7))).toList();
      expect(dates, [
        DateTime(2026, 8, 1),
        DateTime(2026, 9, 1),
        DateTime(2026, 10, 1),
      ]);
    });
  });

  group('firstOccurrenceAfter', () {
    test('is strictly after the day given', () {
      expect(
        firstOccurrenceAfter(
          DateTime(2026, 10, 7),
          Frequency.monthly,
          DateTime(2026, 10, 7),
        ),
        DateTime(2026, 11, 7),
      );
      expect(
        firstOccurrenceAfter(
          DateTime(2026, 10, 1),
          Frequency.monthly,
          DateTime(2026, 10, 7),
        ),
        DateTime(2026, 11, 1),
      );
    });
  });

  group('describeSchedule', () {
    test('weekly names the weekday', () {
      // 7 Oct 2026 is a Wednesday.
      expect(
        describeSchedule(Frequency.weekly, DateTime(2026, 10, 7)),
        'Every Wednesday',
      );
    });

    test('monthly says the day and warns for 29 to 31', () {
      expect(
        describeSchedule(Frequency.monthly, DateTime(2026, 10, 1)),
        'Monthly on the 1st',
      );
      expect(
        describeSchedule(Frequency.monthly, DateTime(2026, 1, 31)),
        'Monthly on the 31st (or the last day)',
      );
    });

    test('yearly says the date', () {
      expect(
        describeSchedule(Frequency.yearly, DateTime(2026, 10, 7)),
        'Every 7 Oct',
      );
    });
  });

  test('frequencyFromName falls back to monthly', () {
    expect(frequencyFromName('weekly'), Frequency.weekly);
    expect(frequencyFromName('nonsense'), Frequency.monthly);
    expect(frequencyFromName(null), Frequency.monthly);
  });
}
