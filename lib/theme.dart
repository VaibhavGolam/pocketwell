import 'package:flutter/material.dart';

/// Every colour the app uses, for light and dark. Screens read these through
/// [AppColors.of] so nothing is hard-coded in a widget.
class AppColors {
  const AppColors({
    required this.bg,
    required this.card,
    required this.text,
    required this.subtext,
    required this.border,
    required this.accent,
    required this.onAccent,
    required this.moneyIn,
    required this.moneyOut,
    required this.shadow,
  });

  final Color bg;
  final Color card;
  final Color text;
  final Color subtext;
  final Color border;
  final Color accent;
  final Color onAccent;
  final Color moneyIn;
  final Color moneyOut;
  final List<BoxShadow> shadow;

  /// ST Media periwinkle.
  static const Color seed = Color(0xFF6B77D6);

  static const AppColors light = AppColors(
    bg: Color(0xFFF7F8FA),
    card: Color(0xFFFFFFFF),
    text: Color(0xFF14171F),
    subtext: Color(0xFF6B7280),
    border: Color(0xFFE6E8EE),
    accent: Color(0xFF6B77D6),
    onAccent: Color(0xFFFFFFFF),
    moneyIn: Color(0xFF2E9E6B),
    moneyOut: Color(0xFFD14B4B),
    shadow: [
      BoxShadow(
        color: Color(0x14101828),
        blurRadius: 14,
        offset: Offset(0, 4),
      ),
    ],
  );

  static const AppColors dark = AppColors(
    bg: Color(0xFF0F1115),
    card: Color(0xFF181B21),
    text: Color(0xFFE8EAF0),
    subtext: Color(0xFF9AA1AF),
    border: Color(0xFF262A33),
    accent: Color(0xFF8E98E8),
    onAccent: Color(0xFF0F1115),
    moneyIn: Color(0xFF5CC595),
    moneyOut: Color(0xFFEF7B77),
    shadow: <BoxShadow>[],
  );

  static AppColors of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

/// Colours for the spending donut. Muted enough to sit on both themes.
const List<Color> kChartColors = [
  Color(0xFF6B77D6),
  Color(0xFF4FB3A9),
  Color(0xFFF0A35E),
  Color(0xFFE5737F),
  Color(0xFF8DB35C),
  Color(0xFFB589D6),
  Color(0xFF5BA4D9),
  Color(0xFFD9B44A),
  Color(0xFF9AA3B2),
];

ThemeData buildTheme(Brightness brightness) {
  final c = brightness == Brightness.dark ? AppColors.dark : AppColors.light;
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.seed,
    brightness: brightness,
  ).copyWith(
    primary: c.accent,
    onPrimary: c.onAccent,
    surface: c.card,
    onSurface: c.text,
    outline: c.border,
    error: c.moneyOut,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.bg,
    appBarTheme: AppBarTheme(
      backgroundColor: c.bg,
      foregroundColor: c.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: c.text,
        fontSize: 22,
        fontWeight: FontWeight.w700,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: c.card,
      indicatorColor: c.accent.withValues(alpha: 0.18),
    ),
    dividerColor: c.border,
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 44),
        foregroundColor: c.text,
        side: BorderSide(color: c.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );
}

final ThemeData lightTheme = buildTheme(Brightness.light);
final ThemeData darkTheme = buildTheme(Brightness.dark);
