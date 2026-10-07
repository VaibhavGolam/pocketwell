// Pure Dart helpers: money formatting, amount parsing and date maths.
// Nothing here touches Flutter, so it is easy to test.

const List<String> kMonthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

const List<String> kMonthShort = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// 1234567 -> "12,34,567" (indian) or "1,234,567".
String groupDigits(int n, {required bool indian}) {
  final s = n.toString();
  if (s.length <= 3) return s;
  final last3 = s.substring(s.length - 3);
  var rest = s.substring(0, s.length - 3);
  final size = indian ? 2 : 3;
  final parts = <String>[];
  while (rest.length > size) {
    parts.insert(0, rest.substring(rest.length - size));
    rest = rest.substring(0, rest.length - size);
  }
  if (rest.isNotEmpty) parts.insert(0, rest);
  return '${parts.join(',')},$last3';
}

/// Amounts are stored in minor units (paise or cents).
/// 250050 -> "₹2,500.50". Whole amounts drop the decimals.
String formatMinor(int minor, {String symbol = '₹', bool showSign = false}) {
  final negative = minor < 0;
  final abs = minor.abs();
  final whole = abs ~/ 100;
  final frac = abs % 100;
  final grouped = groupDigits(whole, indian: symbol == '₹');
  final body =
      frac == 0 ? grouped : '$grouped.${frac.toString().padLeft(2, '0')}';
  final sign = negative ? '-' : (showSign && minor > 0 ? '+' : '');
  return '$sign$symbol$body';
}

/// "1,250.5" -> 125050. Returns null for empty, zero, negative or silly input.
int? parseAmountMinor(String input) {
  final cleaned = input.replaceAll(',', '').replaceAll(' ', '').trim();
  if (cleaned.isEmpty) return null;
  final v = double.tryParse(cleaned);
  if (v == null || v.isNaN || v.isInfinite || v <= 0) return null;
  if (v > 1e11) return null;
  final minor = (v * 100).round();
  return minor > 0 ? minor : null;
}

/// 125000 -> "1250", 125050 -> "1250.50". Used to fill the edit field.
String plainAmount(int minor) {
  if (minor % 100 == 0) return (minor ~/ 100).toString();
  return (minor / 100).toStringAsFixed(2);
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime monthStart(DateTime d) => DateTime(d.year, d.month);

DateTime addMonths(DateTime d, int n) => DateTime(d.year, d.month + n);

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

int daysInMonth(DateTime month) => DateTime(month.year, month.month + 1, 0).day;

/// Whole calendar days from [a] to [b]. Negative if [b] is earlier.
/// Uses UTC midnights so daylight saving never skews the result.
int daysBetween(DateTime a, DateTime b) {
  final from = DateTime.utc(a.year, a.month, a.day);
  final to = DateTime.utc(b.year, b.month, b.day);
  return to.difference(from).inDays;
}

String formatDay(DateTime d) => '${d.day} ${kMonthShort[d.month - 1]}';

String formatDayYear(DateTime d) =>
    '${d.day} ${kMonthShort[d.month - 1]} ${d.year}';

String friendlyDay(DateTime d, DateTime now) {
  final diff = daysBetween(d, now);
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  return d.year == now.year ? formatDay(d) : formatDayYear(d);
}
