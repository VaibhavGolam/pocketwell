import 'package:flutter_test/flutter_test.dart';
import 'package:pocketwell/util/format.dart';

void main() {
  group('formatMinor', () {
    test('uses lakh grouping for rupees', () {
      expect(formatMinor(123456700), '₹12,34,567');
      expect(formatMinor(10000000), '₹1,00,000');
      expect(formatMinor(123400), '₹1,234');
    });

    test('keeps decimals only when needed', () {
      expect(formatMinor(250050), '₹2,500.50');
      expect(formatMinor(250000), '₹2,500');
      expect(formatMinor(5), '₹0.05');
    });

    test('uses thousands grouping for other currencies', () {
      expect(formatMinor(123456700, symbol: '\$'), '\$1,234,567');
    });

    test('handles signs', () {
      expect(formatMinor(-50000), '-₹500');
      expect(formatMinor(50000, showSign: true), '+₹500');
      expect(formatMinor(0, showSign: true), '₹0');
    });
  });

  group('parseAmountMinor', () {
    test('parses plain and formatted numbers', () {
      expect(parseAmountMinor('250'), 25000);
      expect(parseAmountMinor('1,250.50'), 125050);
      expect(parseAmountMinor(' 99.9 '), 9990);
    });

    test('rejects empty, zero and nonsense', () {
      expect(parseAmountMinor(''), isNull);
      expect(parseAmountMinor('0'), isNull);
      expect(parseAmountMinor('abc'), isNull);
      expect(parseAmountMinor('-5'), isNull);
    });
  });

  group('dates', () {
    test('daysBetween counts calendar days', () {
      expect(daysBetween(DateTime(2026, 10, 7), DateTime(2026, 10, 10)), 3);
      expect(daysBetween(DateTime(2026, 10, 10), DateTime(2026, 10, 7)), -3);
      expect(daysBetween(DateTime(2026, 10, 7, 23), DateTime(2026, 10, 8, 1)), 1);
    });

    test('daysInMonth knows February', () {
      expect(daysInMonth(DateTime(2028, 2)), 29);
      expect(daysInMonth(DateTime(2026, 2)), 28);
      expect(daysInMonth(DateTime(2026, 10)), 31);
    });

    test('friendlyDay', () {
      final now = DateTime(2026, 10, 7, 15);
      expect(friendlyDay(DateTime(2026, 10, 7, 9), now), 'Today');
      expect(friendlyDay(DateTime(2026, 10, 6, 22), now), 'Yesterday');
      expect(friendlyDay(DateTime(2026, 9, 1), now), '1 Sep');
      expect(friendlyDay(DateTime(2025, 9, 1), now), '1 Sep 2025');
    });
  });
}
