import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system) {
    _loadTheme();
  }

  static const String _prefKey = 'lifeos_theme_mode';

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final val = prefs.getString(_prefKey);
    if (val != null) {
      state = switch (val) {
        'dark' => ThemeMode.dark,
        'light' => ThemeMode.light,
        _ => ThemeMode.system,
      };
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, mode.name);
  }

  Future<void> toggleTheme() async {
    final next = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    await setThemeMode(next);
  }
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

class NeonPalette {
  // Base background & surfaces
  static const obsidian = Color(0xFF030712); // True deep OLED black/slate
  static const surfaceDark = Color(0xFF0B0F19);
  static const surfaceCard = Color(0xFF111827);
  static const surfaceCardHover = Color(0xFF1F2937);
  static const borderDark = Color(0xFF1F2937);
  static const borderBright = Color(0xFF374151);

  // Vibrant Neon Accents
  static const cyan = Color(0xFF00E5FF); // Electric Cyan (Tasks & Focus)
  static const mint = Color(0xFF00FF9D); // Neon Mint (Habits & Streaks)
  static const violet = Color(0xFFA855F7); // Neon Violet (Finances & Wealth)
  static const amber = Color(0xFFFFB703); // Neon Amber (Pending & Warnings)
  static const rose = Color(0xFFFF0055); // Neon Rose/Crimson (Overdue & Expenses)
  static const blue = Color(0xFF38BDF8); // Electric Sky Blue
}

class AppTheme {
  static final lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF4F46E5),
      brightness: Brightness.light,
      surface: const Color(0xFFF8FAFC),
      surfaceContainerLowest: const Color(0xFFFFFFFF),
      surfaceContainerLow: const Color(0xFFF1F5F9),
      surfaceContainer: const Color(0xFFE2E8F0),
      surfaceContainerHigh: const Color(0xFFCBD5E1),
    ),
    scaffoldBackgroundColor: const Color(0xFFF8FAFC),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
      ),
    ),
    appBarTheme: const AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Color(0xFFF8FAFC),
      centerTitle: false,
    ),
  );

  static final darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme(
      brightness: Brightness.dark,
      primary: NeonPalette.cyan,
      onPrimary: Color(0xFF030712),
      primaryContainer: Color(0xFF083344),
      onPrimaryContainer: Color(0xFF67E8F9),
      secondary: NeonPalette.mint,
      onSecondary: Color(0xFF030712),
      secondaryContainer: Color(0xFF064E3B),
      onSecondaryContainer: Color(0xFF6EE7B7),
      tertiary: NeonPalette.violet,
      onTertiary: Color(0xFF030712),
      tertiaryContainer: Color(0xFF3B0764),
      onTertiaryContainer: Color(0xFFD8B4FE),
      error: NeonPalette.rose,
      onError: Color(0xFF030712),
      errorContainer: Color(0xFF4C0519),
      onErrorContainer: Color(0xFFFDA4AF),
      surface: NeonPalette.surfaceDark,
      onSurface: Color(0xFFF9FAFB),
      surfaceContainerLowest: NeonPalette.obsidian,
      surfaceContainerLow: NeonPalette.surfaceDark,
      surfaceContainer: NeonPalette.surfaceCard,
      surfaceContainerHigh: NeonPalette.surfaceCardHover,
      surfaceContainerHighest: Color(0xFF374151),
      onSurfaceVariant: Color(0xFF9CA3AF),
      outline: Color(0xFF4B5563),
      outlineVariant: Color(0xFF1F2937),
    ),
    scaffoldBackgroundColor: NeonPalette.obsidian,
    cardTheme: CardThemeData(
      elevation: 0,
      color: NeonPalette.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: NeonPalette.borderDark, width: 1.2),
      ),
    ),
    appBarTheme: const AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: NeonPalette.obsidian,
      centerTitle: false,
      foregroundColor: Colors.white,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: NeonPalette.surfaceDark,
      modalBackgroundColor: NeonPalette.surfaceDark,
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: NeonPalette.surfaceDark,
    ),
  );
}
