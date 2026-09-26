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

/// The app's colour vocabulary.
///
/// Deliberately low-saturation: muted slate surfaces with a single restrained
/// teal accent, so long sessions stay comfortable instead of glowing. The
/// three domain hues (teal / sage / clay) are desaturated versions of the old
/// neon accents and are used sparingly, mostly as small icons and thin rules.
class LifeOSPalette {
  // Base background & surfaces (slate ramp, soft rather than OLED-black)
  static const canvas = Color(0xFF0F1419); // Scaffold background (dark)
  static const surfaceDark = Color(0xFF161C23);
  static const surfaceCard = Color(0xFF1B222B);
  static const surfaceCardHover = Color(0xFF232C37);
  static const borderDark = Color(0xFF2A3441);
  static const borderBright = Color(0xFF3C4859);

  // Muted domain accents
  static const teal = Color(0xFF5FA8A0); // Tasks & time
  static const sage = Color(0xFF7FA86F); // Habits & streaks
  static const clay = Color(0xFFB08968); // Finance
  static const sand = Color(0xFFC9A227); // Pending & warnings
  static const rust = Color(0xFFB5646A); // Overdue & expenses
  static const slate = Color(0xFF7C8DA6); // Neutral / secondary
}

class AppTheme {
  static final lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF4E8A83),
      brightness: Brightness.light,
      surface: const Color(0xFFF6F7F8),
      surfaceContainerLowest: const Color(0xFFFFFFFF),
      surfaceContainerLow: const Color(0xFFF0F2F3),
      surfaceContainer: const Color(0xFFE4E7EA),
      surfaceContainerHigh: const Color(0xFFD5D9DE),
    ),
    scaffoldBackgroundColor: const Color(0xFFF6F7F8),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFE2E6EA), width: 1),
      ),
    ),
    appBarTheme: const AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Color(0xFFF6F7F8),
      centerTitle: false,
    ),
  );

  static final darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme(
      brightness: Brightness.dark,
      primary: LifeOSPalette.teal,
      onPrimary: Color(0xFF0F1419),
      primaryContainer: Color(0xFF22322F),
      onPrimaryContainer: Color(0xFFB9DAD4),
      secondary: LifeOSPalette.sage,
      onSecondary: Color(0xFF0F1419),
      secondaryContainer: Color(0xFF26301F),
      onSecondaryContainer: Color(0xFFC7DCBA),
      tertiary: LifeOSPalette.clay,
      onTertiary: Color(0xFF0F1419),
      tertiaryContainer: Color(0xFF33291F),
      onTertiaryContainer: Color(0xFFDEC3AC),
      error: LifeOSPalette.rust,
      onError: Color(0xFF0F1419),
      errorContainer: Color(0xFF3A2022),
      onErrorContainer: Color(0xFFE8BFC1),
      surface: LifeOSPalette.surfaceDark,
      onSurface: Color(0xFFE6E9ED),
      surfaceContainerLowest: LifeOSPalette.canvas,
      surfaceContainerLow: LifeOSPalette.surfaceDark,
      surfaceContainer: LifeOSPalette.surfaceCard,
      surfaceContainerHigh: LifeOSPalette.surfaceCardHover,
      surfaceContainerHighest: Color(0xFF2A3441),
      onSurfaceVariant: Color(0xFFA2ADBB),
      outline: Color(0xFF4A5666),
      outlineVariant: LifeOSPalette.borderDark,
    ),
    scaffoldBackgroundColor: LifeOSPalette.canvas,
    cardTheme: CardThemeData(
      elevation: 0,
      color: LifeOSPalette.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: LifeOSPalette.borderDark, width: 1),
      ),
    ),
    appBarTheme: const AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: LifeOSPalette.canvas,
      centerTitle: false,
      foregroundColor: Colors.white,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: LifeOSPalette.surfaceDark,
      modalBackgroundColor: LifeOSPalette.surfaceDark,
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: LifeOSPalette.surfaceDark,
    ),
  );
}
